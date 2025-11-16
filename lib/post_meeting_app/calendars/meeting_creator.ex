defmodule PostMeetingApp.Calendars.MeetingCreator do
  @moduledoc """
  Creates meetings from calendar events when notetaker is enabled
  """

  import Ecto.Query
  alias PostMeetingApp.{Meetings, Calendars, Accounts, Recall}
  alias PostMeetingApp.Repo

  def create_meeting_from_event(event_id) do
    require Logger
    
    event = Calendars.get_event!(event_id)
    Logger.info("here to check #{event.send_notetaker}, #{event.meeting_url}")
    if event.send_notetaker && event.meeting_url do
      # Check if meeting already exists for this event
      # Handle case where multiple meetings might exist (get the most recent one)
      existing_meeting = 
        from(m in PostMeetingApp.Meetings.Meeting,
          where: m.event_id == ^event.id,
          order_by: [desc: m.inserted_at],
          limit: 1
        )
        |> Repo.one()
      
      Logger.info("existing_meeting: #{inspect(existing_meeting)}")
      if existing_meeting do
        Logger.info("[MeetingCreator] Meeting #{existing_meeting.id} already exists for event #{event.id}")
        {:ok, existing_meeting}
      else
        # Verify meeting is in the future before creating
        now = DateTime.utc_now()
        Logger.info("[MeetingCreator] Comparing times - event.start_time: #{inspect(event.start_time)}, now: #{inspect(now)}")
        
        # Use DateTime.compare/2 for reliable DateTime comparison
        start_time_after_now = 
          if event.start_time do
            comparison = DateTime.compare(event.start_time, now)
            Logger.info("[MeetingCreator] DateTime.compare result: #{inspect(comparison)}")
            comparison == :gt
          else
            false
          end
        
        Logger.info("[MeetingCreator] event.start_time > DateTime.utc_now()? #{start_time_after_now}")
        
        if start_time_after_now do
          user = Accounts.get_user!(event.user_id)
          settings = Accounts.get_settings(user.id)
          minutes_before = settings.minutes_before_meeting || 5

          attrs = %{
            user_id: event.user_id,
            event_id: event.id,
            title: event.title,
            start_time: event.start_time,
            end_time: event.end_time,
            attendees: event.attendees,
            platform: event.meeting_platform,
            recall_status: "pending"
          }

          case Meetings.create_meeting(attrs) do
            {:ok, meeting} ->
              Logger.info("[MeetingCreator] Created meeting #{meeting.id} for event #{event.id}")
              
              # Schedule Recall bot only if meeting is in the future
              # Calculate schedule time: event start time minus minutes_before
              Logger.info("[MeetingCreator] Calculating schedule time - event.start_time: #{inspect(event.start_time)}, minutes_before: #{minutes_before}")
              
              # Use negative minutes directly (DateTime.add handles negative values correctly)
              schedule_time = DateTime.add(event.start_time, -minutes_before, :minute)
              schedule_now = DateTime.utc_now()
              
              Logger.info("[MeetingCreator] Calculated schedule_time: #{inspect(schedule_time)}")
              
              # Use DateTime.compare/2 for reliable DateTime comparison
              schedule_time_after_now = DateTime.compare(schedule_time, schedule_now) == :gt
              
              Logger.info("[MeetingCreator] Schedule time comparison - schedule_time: #{inspect(schedule_time)}, now: #{inspect(schedule_now)}, is_future: #{schedule_time_after_now}")
              
              if schedule_time_after_now do
                case Recall.schedule_bot_for_meeting(
                  meeting.id,
                  event.meeting_url,
                  event.start_time,
                  minutes_before
                ) do
                  {:ok, job} ->
                    Logger.info("""
                    [MeetingCreator] Scheduled Recall bot job #{job.id} for meeting #{meeting.id}.
                    Job will run at #{DateTime.to_iso8601(schedule_time)}.
                    You can view scheduled jobs in the Oban dashboard at /oban, or check the 'oban_jobs' table in your database.
                    """)
                    {:ok, meeting}

                  {:error, reason} ->
                    Logger.error("[MeetingCreator] Failed to schedule Recall bot job: #{inspect(reason)}")
                    # Still return success for meeting creation, but log the error
                    {:ok, meeting}
                end
              else
                Logger.warning("[MeetingCreator] Cannot schedule job - schedule time #{DateTime.to_iso8601(schedule_time)} is in the past (now: #{DateTime.to_iso8601(schedule_now)})")
                {:ok, meeting}
              end

            {:error, changeset} ->
              Logger.error("[MeetingCreator] Failed to create meeting: #{inspect(changeset.errors)}")
              {:error, changeset}
          end
        else
          Logger.warning("[MeetingCreator] Cannot create meeting - event start time #{DateTime.to_iso8601(event.start_time)} is in the past")
          {:error, :meeting_already_started}
        end
      end
    else
      Logger.info("[MeetingCreator] Notetaker not enabled or no meeting URL for event #{event.id}")
      {:error, :notetaker_not_enabled}
    end
  end
end

