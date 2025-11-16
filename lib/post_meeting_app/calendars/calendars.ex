defmodule PostMeetingApp.Calendars do
  import Ecto.Query, warn: false
  alias PostMeetingApp.Repo
  alias PostMeetingApp.Calendars.{Event, GoogleClient}
  alias PostMeetingApp.Accounts
  alias PostMeetingApp.Accounts.OAuthToken

  def list_events(user_id, opts \\ []) do
    query = from(e in Event, where: e.user_id == ^user_id)

    query =
      if opts[:start_time] do
        from(e in query, where: e.start_time >= ^opts[:start_time])
      else
        query
      end

    query =
      if opts[:end_time] do
        from(e in query, where: e.start_time <= ^opts[:end_time])
      else
        query
      end

    # Order by start_time descending (most recent first)
    query = from(e in query, order_by: [desc: e.start_time])

    # Preload meeting and transcript to check for transcript availability
    query
    |> Repo.all()
    |> Repo.preload(meeting: :transcript)
  end

  def get_event!(id), do: Repo.get!(Event, id)

  def get_event_by_google_id(user_id, google_event_id, google_calendar_id) do
    Repo.get_by(Event,
      user_id: user_id,
      google_event_id: google_event_id,
      google_calendar_id: google_calendar_id
    )
  end

  def create_event(attrs \\ %{}) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  def update_event(%Event{} = event, attrs) do
    event
    |> Event.changeset(attrs)
    |> Repo.update()
  end

  def toggle_notetaker(%Event{} = event, enabled) do
    require Logger
    Logger.info("Toggling notetaker for event #{event.id}: enabled=#{inspect(enabled)}")
    result = update_event(event, %{send_notetaker: enabled})
    Logger.info("toggle_notetaker result: #{inspect(result)}")

    # If enabling notetaker and meeting hasn't started, create meeting
    if enabled && match?({:ok, _}, result) do
      {:ok, updated_event} = result
      now = DateTime.utc_now()
      
      Logger.info("I am in here - DateTime.utc_now(): #{now}")
      Logger.info("I am in here - updated_event.start_time: #{inspect(updated_event.start_time)}")
      Logger.info("I am in here - updated_event.meeting_url: #{inspect(updated_event.meeting_url)}")
      
      # Use DateTime.compare/2 for reliable DateTime comparison
      start_time_after_now = 
        if updated_event.start_time do
          DateTime.compare(updated_event.start_time, now) == :gt
        else
          false
        end
      
      Logger.info("I am in here - start_time > now?: #{start_time_after_now}")
      Logger.info("I am in here - full condition: #{start_time_after_now && updated_event.meeting_url != nil}")

      if start_time_after_now && updated_event.meeting_url do
        PostMeetingApp.Calendars.MeetingCreator.create_meeting_from_event(updated_event.id)
      end

      result
    else
      result
    end
  end

  def sync_calendars(user_id) do
    tokens = Accounts.list_oauth_tokens(user_id)
    google_tokens = Enum.filter(tokens, &(&1.provider == :google))

    if Enum.empty?(google_tokens) do
      {:error, :no_google_token}
    else
      results = Enum.map(google_tokens, fn token ->
        sync_calendar(user_id, token)
      end)
      
      # Check for specific error types
      if Enum.any?(results, &match?({:error, :token_expired}, &1)) do
        {:error, :token_expired}
      else
        # Return :ok if at least one sync succeeded
        if Enum.any?(results, &match?(:ok, &1)) do
          :ok
        else
          {:error, :sync_failed}
        end
      end
    end
  end

  defp sync_calendar(user_id, token) do
    require Logger
    Logger.info("Starting calendar sync for user #{user_id}")

    # Check if token is expired and refresh if needed
    token = 
      if OAuthToken.expired?(token) do
        Logger.info("Token expired for user #{user_id}, attempting to refresh...")
        case Accounts.refresh_oauth_token(token) do
          {:ok, refreshed_token} ->
            Logger.info("Token refreshed successfully for user #{user_id}")
            refreshed_token
          
          {:error, reason} ->
            Logger.error("Failed to refresh token for user #{user_id}: #{inspect(reason)}")
            token
        end
      else
        token
      end

    case GoogleClient.list_calendars(token.access_token) do
      {:ok, calendars} ->
        Logger.info("Found #{length(calendars)} calendars for user #{user_id}")
        
        results = Enum.map(calendars, fn calendar ->
          calendar_name = calendar["summary"] || calendar["id"]
          Logger.info("Syncing calendar: #{calendar_name}")
          sync_calendar_events(user_id, token, calendar["id"], calendar_name)
        end)
        
        # Check if any calendar sync failed
        if Enum.any?(results, &match?({:error, _}, &1)) do
          failed_count = Enum.count(results, &match?({:error, _}, &1))
          Logger.warning("Some calendars failed to sync: #{failed_count} failed")
        end
        
        # Return :ok if at least one calendar synced successfully
        if Enum.any?(results, &match?(:ok, &1)) do
          :ok
        else
          {:error, :all_calendars_failed}
        end

      {:error, {:http_error, 401, _}} ->
        Logger.warning("Received 401 error for user #{user_id}, attempting to refresh token...")
        
        # Try to refresh the token
        case Accounts.refresh_oauth_token(token) do
          {:ok, refreshed_token} ->
            Logger.info("Token refreshed successfully, retrying calendar sync...")
            # Retry the request with the new token
            case GoogleClient.list_calendars(refreshed_token.access_token) do
              {:ok, calendars} ->
                Logger.info("Found #{length(calendars)} calendars for user #{user_id} after token refresh")
                
                results = Enum.map(calendars, fn calendar ->
                  calendar_name = calendar["summary"] || calendar["id"]
                  Logger.info("Syncing calendar: #{calendar_name}")
                  sync_calendar_events(user_id, refreshed_token, calendar["id"], calendar_name)
                end)
                
                if Enum.any?(results, &match?({:error, _}, &1)) do
                  failed_count = Enum.count(results, &match?({:error, _}, &1))
                  Logger.warning("Some calendars failed to sync: #{failed_count} failed")
                end
                
                if Enum.any?(results, &match?(:ok, &1)) do
                  :ok
                else
                  {:error, :all_calendars_failed}
                end
              
              error ->
                Logger.error("Failed to list calendars after token refresh: #{inspect(error)}")
                {:error, :token_refresh_failed}
            end
          
          {:error, reason} ->
            Logger.error("Google token expired and refresh failed for user #{user_id}: #{inspect(reason)}")
            {:error, :token_expired}
        end

      {:error, {:http_error, status, body}} ->
        Logger.error("Failed to list calendars: HTTP #{status} - #{inspect(body)}")
        {:error, {:http_error, status}}

      error ->
        Logger.error("Failed to list calendars: #{inspect(error)}")
        {:error, error}
    end
  end

  defp sync_calendar_events(user_id, token, calendar_id, calendar_name \\ nil) do
    require Logger
    
    # Fetch events from 30 days ago to 1 year in the future
    time_min = DateTime.utc_now() |> DateTime.add(-30, :day) |> DateTime.to_iso8601()
    time_max = DateTime.utc_now() |> DateTime.add(365, :day) |> DateTime.to_iso8601()
    
    case GoogleClient.list_events(token.access_token, calendar_id, time_min: time_min, time_max: time_max) do
      {:ok, events} ->
        Logger.info("Found #{length(events)} events in calendar #{calendar_name || calendar_id}")
        
        results = Enum.map(events, fn event_data ->
          upsert_event(user_id, calendar_id, event_data)
        end)
        
        # Count successes and failures
        success_count = Enum.count(results, &match?({:ok, _}, &1))
        error_count = Enum.count(results, &match?({:error, _}, &1))
        
        if error_count > 0 do
          Logger.warning("Calendar #{calendar_name || calendar_id}: #{success_count} events synced, #{error_count} failed")
        else
          Logger.info("Calendar #{calendar_name || calendar_id}: Successfully synced #{success_count} events")
        end
        
        :ok

      {:error, {:http_error, 401, _}} ->
        Logger.warning("Received 401 error while syncing calendar #{calendar_name || calendar_id}, attempting to refresh token...")
        
        # Try to refresh the token
        case Accounts.refresh_oauth_token(token) do
          {:ok, refreshed_token} ->
            Logger.info("Token refreshed successfully, retrying calendar events sync...")
            # Retry the request with the new token
            case GoogleClient.list_events(refreshed_token.access_token, calendar_id, time_min: time_min, time_max: time_max) do
              {:ok, events} ->
                Logger.info("Found #{length(events)} events in calendar #{calendar_name || calendar_id} after token refresh")
                
                results = Enum.map(events, fn event_data ->
                  upsert_event(user_id, calendar_id, event_data)
                end)
                
                success_count = Enum.count(results, &match?({:ok, _}, &1))
                error_count = Enum.count(results, &match?({:error, _}, &1))
                
                if error_count > 0 do
                  Logger.warning("Calendar #{calendar_name || calendar_id}: #{success_count} events synced, #{error_count} failed")
                else
                  Logger.info("Calendar #{calendar_name || calendar_id}: Successfully synced #{success_count} events")
                end
                
                :ok
              
              error ->
                Logger.error("Failed to list events after token refresh: #{inspect(error)}")
                {:error, :token_refresh_failed}
            end
          
          {:error, reason} ->
            Logger.error("Token expired and refresh failed while syncing calendar #{calendar_name || calendar_id}: #{inspect(reason)}")
            {:error, :token_expired}
        end

      {:error, {:http_error, 404, _}} ->
        # Calendar not found or not accessible - skip it gracefully
        Logger.warning("Calendar #{calendar_name || calendar_id} not accessible (404) - skipping")
        :ok

      {:error, {:http_error, status, body}} ->
        Logger.error("Failed to list events for calendar #{calendar_name || calendar_id}: HTTP #{status} - #{inspect(body)}")
        {:error, {:http_error, status}}

      error ->
        Logger.error("Failed to list events for calendar #{calendar_name || calendar_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp upsert_event(user_id, calendar_id, event_data) do
    require Logger
    
    meeting_url = extract_meeting_url(event_data)
    platform = if meeting_url, do: Event.detect_platform(meeting_url), else: nil

    attrs = %{
      user_id: user_id,
      google_event_id: event_data["id"],
      google_calendar_id: calendar_id,
      title: event_data["summary"] || "Untitled Event",
      description: event_data["description"],
      start_time: parse_datetime(event_data["start"]),
      end_time: parse_datetime(event_data["end"]),
      meeting_url: meeting_url,
      meeting_platform: platform,
      attendees: extract_attendees(event_data),
      synced_at: DateTime.utc_now()
    }

    # Validate that required fields are present
    if is_nil(attrs.start_time) || is_nil(attrs.end_time) do
      Logger.warning("Skipping event #{attrs.google_event_id}: missing start_time or end_time")
      {:error, :invalid_datetime}
    else
      case get_event_by_google_id(user_id, event_data["id"], calendar_id) do
        nil -> 
          case create_event(attrs) do
            {:ok, event} -> 
              {:ok, event}
            {:error, changeset} ->
              Logger.error("Failed to create event #{attrs.title}: #{inspect(Ecto.Changeset.traverse_errors(changeset, & &1))}")
              {:error, changeset}
          end
        event -> 
          case update_event(event, attrs) do
            {:ok, updated_event} -> 
              {:ok, updated_event}
            {:error, changeset} ->
              Logger.error("Failed to update event #{attrs.title}: #{inspect(Ecto.Changeset.traverse_errors(changeset, & &1))}")
              {:error, changeset}
          end
      end
    end
  end

  defp extract_meeting_url(event_data) do
    cond do
      url = event_data["hangoutLink"] -> url
      url = event_data["conferenceData"] && event_data["conferenceData"]["entryPoints"] && List.first(event_data["conferenceData"]["entryPoints"]) -> url["uri"]
      desc = event_data["description"] -> extract_url_from_text(desc)
      true -> nil
    end
  end

  defp extract_url_from_text(text) when is_binary(text) do
    ~r/https?:\/\/[^\s]+/
    |> Regex.run(text)
    |> case do
      [url | _] -> url
      _ -> nil
    end
  end

  defp extract_url_from_text(_), do: nil

  defp extract_attendees(event_data) do
    (event_data["attendees"] || [])
    |> Enum.map(& &1["email"])
    |> Enum.filter(& &1)
  end

  defp parse_datetime(%{"dateTime" => dt}) do
    case DateTime.from_iso8601(dt) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(%{"date" => date}) do
    case Date.from_iso8601(date) do
      {:ok, d} -> DateTime.new!(d, ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end

