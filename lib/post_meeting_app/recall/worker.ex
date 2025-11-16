defmodule PostMeetingApp.Recall.Worker do
  @moduledoc """
  Oban worker to schedule Recall.ai bots for meetings
  """

  use Oban.Worker, queue: :recall, max_attempts: 3

  alias PostMeetingApp.Recall
  alias PostMeetingApp.Meetings
  alias PostMeetingApp.Accounts

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"meeting_id" => meeting_id, "meeting_url" => meeting_url}}) do
    require Logger
    
    Logger.info("[Recall.Worker] Processing job for meeting #{meeting_id}, URL: #{meeting_url}")
    
    meeting = Meetings.get_meeting!(meeting_id)

    case Recall.create_bot(meeting_url) do
      {:ok, %{"id" => bot_id}} ->
        Logger.info("[Recall.Worker] Bot created successfully with ID: #{bot_id}")
        
        Meetings.update_meeting(meeting, %{
          recall_bot_id: bot_id,
          recall_status: "scheduled"
        })

        # Schedule polling job
        schedule_polling(bot_id, meeting_id)
        :ok

      {:error, :api_key_not_configured} ->
        Logger.error("[Recall.Worker] Cannot create bot - RECALL_API_KEY is not configured")
        Meetings.update_meeting(meeting, %{recall_status: "failed"})
        {:error, :api_key_not_configured}

      {:error, {:http_error, 401, body}} ->
        Logger.error("[Recall.Worker] Authentication failed (401) - API key may be invalid or for wrong region")
        Logger.error("[Recall.Worker] Error details: #{body}")
        Meetings.update_meeting(meeting, %{recall_status: "failed"})
        {:error, {:authentication_failed, body}}

      {:error, reason} ->
        Logger.error("[Recall.Worker] Failed to create bot: #{inspect(reason)}")
        Meetings.update_meeting(meeting, %{recall_status: "failed"})
        {:error, reason}
    end
  end

  defp schedule_polling(bot_id, meeting_id) do
    %{
      bot_id: bot_id,
      meeting_id: meeting_id
    }
    |> PostMeetingApp.Recall.Poller.new(schedule_in: 60)
    |> Oban.insert()
  end
end

