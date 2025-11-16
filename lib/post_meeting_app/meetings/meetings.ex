defmodule PostMeetingApp.Meetings do
  import Ecto.Query, warn: false
  alias PostMeetingApp.Repo
  alias PostMeetingApp.Meetings.{Meeting, Transcript, FollowUpEmail}
  alias PostMeetingApp.Automations

  def list_meetings(user_id, opts \\ []) do
    query = from(m in Meeting, where: m.user_id == ^user_id, order_by: [desc: m.start_time])

    query =
      if opts[:past] do
        from(m in query, where: m.start_time < ^DateTime.utc_now())
      else
        query
      end

    Repo.all(query) |> Repo.preload([:transcript, :follow_up_email, :social_posts])
  end

  def get_meeting!(id) do
    Repo.get!(Meeting, id)
    |> Repo.preload([:transcript, :follow_up_email, :social_posts, :event])
  end

  def create_meeting(attrs \\ %{}) do
    %Meeting{}
    |> Meeting.changeset(attrs)
    |> Repo.insert()
  end

  def update_meeting(%Meeting{} = meeting, attrs) do
    meeting
    |> Meeting.changeset(attrs)
    |> Repo.update()
  end

  def create_transcript(meeting_id, attrs) do
    %Transcript{}
    |> Transcript.changeset(Map.put(attrs, :meeting_id, meeting_id))
    |> Repo.insert()
    |> case do
      {:ok, transcript} ->
        update_meeting(Repo.get!(Meeting, meeting_id), %{transcript_available: true})
        {:ok, transcript}

      error ->
        error
    end
  end

  def create_follow_up_email(meeting_id, attrs) do
    %FollowUpEmail{}
    |> FollowUpEmail.changeset(Map.put(attrs, :meeting_id, meeting_id))
    |> Repo.insert()
  end

  def generate_content_for_meeting(meeting_id) do
    require Logger
    
    Logger.info("[Meetings] Starting content generation for meeting #{meeting_id}")
    meeting = get_meeting!(meeting_id)
    Logger.info("[Meetings] Meeting loaded: #{meeting.title}")

    with {:ok, transcript} <- get_transcript(meeting_id),
         {:ok, follow_up_email} <- generate_follow_up_email(meeting, transcript),
         {:ok, _} <- generate_social_posts(meeting, transcript) do
      Logger.info("[Meetings] Content generation completed successfully for meeting #{meeting_id}")
      {:ok, meeting}
    else
      error ->
        Logger.error("[Meetings] Content generation failed for meeting #{meeting_id}: #{inspect(error)}")
        error
    end
  end

  defp get_transcript(meeting_id) do
    case Repo.get_by(Transcript, meeting_id: meeting_id) do
      nil -> {:error, :transcript_not_found}
      transcript -> {:ok, transcript}
    end
  end

  defp generate_follow_up_email(meeting, transcript) do
    require Logger
    
    Logger.info("[Meetings] Generating follow-up email for meeting #{meeting.id}")
    
    case Repo.get_by(FollowUpEmail, meeting_id: meeting.id) do
      nil ->
        Logger.info("[Meetings] No existing follow-up email found, generating new one")
        
        case PostMeetingApp.Automations.PostGenerator.generate_follow_up_email(transcript.content, meeting) do
          {:ok, content} ->
            Logger.info("[Meetings] Follow-up email content generated successfully, saving to database")
            Logger.info("[Meetings] Generated content length: #{String.length(content)} characters")
            subject = "Follow-up: #{meeting.title}"
            Logger.info("[Meetings] Email subject: #{subject}")
            
            case create_follow_up_email(meeting.id, %{content: content, subject: subject}) do
              {:ok, email} ->
                Logger.info("[Meetings] Follow-up email saved successfully (ID: #{email.id}) for meeting #{meeting.id}")
                {:ok, email}
              
              {:error, changeset} ->
                Logger.error("[Meetings] Failed to save follow-up email for meeting #{meeting.id}: #{inspect(changeset.errors)}")
                {:error, changeset}
            end
          
          {:error, reason} ->
            Logger.error("[Meetings] Failed to generate follow-up email content for meeting #{meeting.id}: #{inspect(reason)}")
            {:error, {:generation_failed, reason}}
        end

      email ->
        Logger.info("[Meetings] Follow-up email already exists (ID: #{email.id}) for meeting #{meeting.id}, skipping generation")
        {:ok, email}
    end
  end

  defp generate_social_posts(meeting, transcript) do
    user_id = meeting.user_id
    automations = Automations.list_automations(user_id)

    results =
      Enum.map(automations, fn automation ->
        case Repo.get_by(PostMeetingApp.Automations.SocialPost,
               meeting_id: meeting.id,
               automation_id: automation.id
             ) do
          nil ->
            content =
              PostMeetingApp.Automations.PostGenerator.generate_post(
                transcript.content,
                automation.instructions,
                meeting
              )

            Automations.create_social_post(%{
              meeting_id: meeting.id,
              automation_id: automation.id,
              content: content,
              social_network: automation.social_network
            })

          post ->
            {:ok, post}
        end
      end)

    if Enum.all?(results, &match?({:ok, _}, &1)), do: {:ok, results}, else: {:error, :generation_failed}
  end
end

