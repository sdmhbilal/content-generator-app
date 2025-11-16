defmodule PostMeetingApp.Recall do
  alias PostMeetingApp.Recall.{Client, Worker}
  alias PostMeetingApp.Meetings
  alias PostMeetingApp.Accounts
  alias PostMeetingApp.Repo

  def schedule_bot_for_meeting(meeting_id, meeting_url, start_time, minutes_before) do
    schedule_time = DateTime.add(start_time, -minutes_before * 60, :minute)

    %{
      meeting_id: meeting_id,
      meeting_url: meeting_url,
      start_time: start_time
    }
    |> Worker.new(scheduled_at: schedule_time)
    |> Oban.insert()
  end

  def create_bot(meeting_url) do
    Client.create_bot(meeting_url)
  end

  def get_bot_status(bot_id) do
    Client.get_bot_status(bot_id)
  end

  def poll_bot_status(bot_id) do
    require Logger
    
    Logger.info("[Recall] Starting poll_bot_status for bot_id: #{bot_id}")
    
    case get_bot_status(bot_id) do
      {:ok, bot_data} ->
        Logger.info("[Recall] Successfully retrieved bot data for bot_id: #{bot_id}")
        
        # Check if recordings exist and transcript is ready
        recordings = Map.get(bot_data, "recordings", [])
        Logger.info("[Recall] Found #{length(recordings)} recording(s) for bot #{bot_id}")
        
        if length(recordings) > 0 do
          # Get the first (most recent) recording
          recording = List.first(recordings)
          recording_id = Map.get(recording, "id", "unknown")
          Logger.info("[Recall] Processing recording #{recording_id} for bot #{bot_id}")
          
          transcript_data = get_in(recording, ["media_shortcuts", "transcript"])
          
          if transcript_data do
            transcript_status = get_in(transcript_data, ["status", "code"])
            transcript_id = Map.get(transcript_data, "id", "unknown")
            Logger.info("[Recall] Found transcript data (id: #{transcript_id}, status: #{transcript_status || "nil"}) for bot #{bot_id}")
            
            case transcript_status do
              "done" ->
                # Transcript is ready, download and save it
                handle_transcript_ready(bot_id, recording, transcript_data)
              
              "processing" ->
                # Still processing, reschedule polling
                Logger.info("[Recall] Transcript still processing for bot #{bot_id}")
                {:ok, "processing"}
              
              nil ->
                # Status not set yet
                Logger.info("[Recall] Transcript status not set yet for bot #{bot_id}")
                {:ok, "processing"}
              
              status ->
                Logger.warning("[Recall] Unexpected transcript status: #{status} for bot #{bot_id}, treating as processing")
                {:ok, "processing"}
            end
          else
            # No transcript data yet, check if recording is still in progress
            Logger.info("[Recall] No transcript data yet for bot #{bot_id}, continuing to poll")
            {:ok, "recording"}
          end
        else
          # No recordings yet, check bot status from status_changes
          status_changes = Map.get(bot_data, "status_changes", [])
          Logger.info("[Recall] No recordings yet for bot #{bot_id}, checking status_changes (#{length(status_changes)} status change(s))")
          
          latest_status = 
            if length(status_changes) > 0 do
              List.last(status_changes) |> Map.get("code")
            else
              nil
            end
          
          Logger.info("[Recall] Latest status from status_changes: #{latest_status || "nil"} for bot #{bot_id}")
          
          # Map bot status codes to our internal status
          case latest_status do
            "left_call" ->
              Logger.info("[Recall] Bot left call for bot #{bot_id}")
              {:ok, "completed"}
            
            "joining_call" ->
              Logger.info("[Recall] Bot joining call for bot #{bot_id}")
              {:ok, "recording"}
            
            "in_waiting_room" ->
              Logger.info("[Recall] Bot in waiting room for bot #{bot_id}")
              {:ok, "recording"}
            
            "in_call" ->
              Logger.info("[Recall] Bot in call for bot #{bot_id}")
              {:ok, "recording"}
            
            nil ->
              # No status changes yet, assume recording
              Logger.info("[Recall] No status changes for bot #{bot_id}, assuming recording")
              {:ok, "recording"}
            
            status ->
              Logger.info("[Recall] Bot status: #{status} for bot #{bot_id}, treating as recording")
              {:ok, "recording"}
          end
        end

      error ->
        Logger.error("[Recall] Error getting bot status: #{inspect(error)}")
        error
    end
  end

  defp handle_transcript_ready(bot_id, recording, transcript_data) do
    require Logger
    
    # Find meeting by bot_id
    meeting =
      PostMeetingApp.Repo.get_by(PostMeetingApp.Meetings.Meeting, recall_bot_id: bot_id)

    if meeting do
      # Check if transcript already exists
      existing_transcript = PostMeetingApp.Repo.get_by(
        PostMeetingApp.Meetings.Transcript, 
        meeting_id: meeting.id
      )
      
      if existing_transcript do
        Logger.info("[Recall] Transcript already exists for meeting #{meeting.id}")
        {:ok, "completed"}
      else
        # Download transcript from S3 URL
        download_url = get_in(transcript_data, ["data", "download_url"])
        transcript_id = Map.get(transcript_data, "id")
        
        if download_url do
          Logger.info("[Recall] Downloading transcript from: #{String.slice(download_url, 0..100)}...")
          
          case download_and_parse_transcript(download_url) do
            {:ok, transcript_content} ->
              # Save transcript
              case Meetings.create_transcript(meeting.id, %{
                content: transcript_content,
                recall_media_id: transcript_id,
                recall_status: "completed"
              }) do
                {:ok, _transcript} ->
                  Logger.info("[Recall] Transcript saved successfully for meeting #{meeting.id}")
                  
                  # Generate content
                  Meetings.generate_content_for_meeting(meeting.id)

                  Meetings.update_meeting(meeting, %{
                    recall_status: "completed",
                    transcript_available: true
                  })
                  
                  {:ok, "completed"}
                
                {:error, changeset} ->
                  Logger.error("[Recall] Failed to save transcript: #{inspect(changeset.errors)}")
                  {:error, :save_failed}
              end
            
            {:error, reason} ->
              Logger.error("[Recall] Failed to download transcript: #{inspect(reason)}")
              {:error, reason}
          end
        else
          Logger.warning("[Recall] No download URL available for transcript")
          {:ok, "processing"}
        end
      end
    else
      Logger.warning("[Recall] No meeting found for bot_id: #{bot_id}")
      {:ok, "completed"}
    end
  end

  defp download_and_parse_transcript(download_url) do
    require Logger
    
    case Finch.build(:get, download_url) |> Finch.request(PostMeetingApp.Finch) do
        {:ok, %{status: 200, body: body}} ->
          # Parse JSON transcript
          data = Jason.decode!(body)
          
          Logger.info("[Recall] Downloaded transcript JSON, structure: #{if is_list(data), do: "array (#{length(data)} items)", else: "object"}")
          
          # Extract transcript text from the JSON structure
          # Structure: [{"participant": {...}, "words": [...]}, ...]
          transcript_text = extract_transcript_from_json(data)
          
          Logger.info("[Recall] Extracted transcript text length: #{String.length(transcript_text)} characters")
          
          {:ok, transcript_text}
      
      {:ok, %{status: status, body: body}} ->
        Logger.error("[Recall] HTTP error #{status} downloading transcript: #{String.slice(body, 0..200)}")
        {:error, {:http_error, status, body}}
      
      error ->
        Logger.error("[Recall] Failed to download transcript: #{inspect(error)}")
        {:error, error}
    end
  end

  defp extract_transcript_from_json(data) when is_list(data) do
    require Logger
    
    # Handle array of participant objects with words
    # Structure: [{"participant": {...}, "words": [...]}, ...]
    # Each entry represents a speaking turn - same participant can appear multiple times
    Logger.info("[Recall] Parsing transcript as array with #{length(data)} speaking turn(s)")
    
    result = data
    |> Enum.with_index()
    |> Enum.map(fn {participant_data, index} ->
      participant = Map.get(participant_data, "participant", %{})
      words = Map.get(participant_data, "words", [])
      
      participant_name = 
        participant
        |> Map.get("name", "Unknown Speaker")
        |> String.trim()
      
      participant_id = Map.get(participant, "id", "unknown")
      is_host = Map.get(participant, "is_host", false)
      
      # Extract text from words array - filter empty strings and join with spaces
      transcript_text = 
        words
        |> Enum.map(fn word_obj ->
          text = Map.get(word_obj, "text", "")
          String.trim(text)
        end)
        |> Enum.filter(&(&1 != ""))
        |> Enum.join(" ")
      
      # Get timestamp info for logging
      first_word_timestamp = 
        if length(words) > 0 do
          first_word = List.first(words)
          get_in(first_word, ["start_timestamp", "absolute"])
        else
          nil
        end
      
      Logger.info("[Recall] Turn #{index + 1}: Participant: #{participant_name} (ID: #{participant_id}, Host: #{is_host}), Words: #{length(words)}, Text: \"#{String.slice(transcript_text, 0..50)}#{if String.length(transcript_text) > 50, do: "...", else: ""}\"")
      
      if transcript_text != "" do
        "#{participant_name}: #{transcript_text}"
      else
        nil
      end
    end)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.join("\n\n")
    
    # Count unique participants
    unique_participants = 
      data
      |> Enum.map(fn participant_data ->
        participant = Map.get(participant_data, "participant", %{})
        Map.get(participant, "id", "unknown")
      end)
      |> Enum.uniq()
      |> length()
    
    Logger.info("[Recall] Final transcript: #{unique_participants} unique participant(s), #{length(String.split(result, "\n\n"))} speaking turn(s), #{String.length(result)} total characters")
    
    result
  end

  defp extract_transcript_from_json(data) when is_map(data) do
    # Handle different possible JSON structures
    cond do
      # Structure: {"segments": [{"speaker": "...", "text": "..."}, ...]}
      Map.has_key?(data, "segments") ->
        data["segments"]
        |> Enum.map(fn segment ->
          speaker = Map.get(segment, "speaker", "Speaker")
          text = Map.get(segment, "text", "")
          "#{speaker}: #{text}"
        end)
        |> Enum.join("\n")
      
      # Structure: {"words": [...]} - single participant words
      Map.has_key?(data, "words") ->
        # Try to extract text from words
        data["words"]
        |> Enum.map(&Map.get(&1, "text", ""))
        |> Enum.filter(&(&1 != ""))
        |> Enum.join(" ")
      
      # Structure: {"participant": {...}, "words": [...]} - single participant object
      Map.has_key?(data, "participant") and Map.has_key?(data, "words") ->
        participant = Map.get(data, "participant", %{})
        words = Map.get(data, "words", [])
        
        participant_name = 
          participant
          |> Map.get("name", "Unknown Speaker")
          |> String.trim()
        
        transcript_text = 
          words
          |> Enum.map(&Map.get(&1, "text", ""))
          |> Enum.filter(&(&1 != ""))
          |> Enum.join(" ")
        
        "#{participant_name}: #{transcript_text}"
      
      # Structure: {"transcript": "..."} or {"text": "..."}
      Map.has_key?(data, "transcript") ->
        data["transcript"]
      
      Map.has_key?(data, "text") ->
        data["text"]
      
      # Fallback: try to find any text-like fields
      true ->
        # Look for common transcript fields
        case Enum.find(data, fn {_k, v} -> is_binary(v) and String.length(v) > 10 end) do
          {_key, text} -> text
          nil -> Jason.encode!(data)
        end
    end
  end

  defp extract_transcript_from_json(data) do
    # Fallback: encode as JSON string
    Jason.encode!(data)
  end
end

