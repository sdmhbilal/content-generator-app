defmodule PostMeetingApp.Recall.Client do
  @moduledoc """
  Client for Recall.ai API
  """

  require Logger

  defp api_key do
    key = Application.get_env(:post_meeting_app, :recall)[:api_key]
    
    if is_nil(key) || key == "" || key == "placeholder-api-key" do
      Logger.error("[Recall.Client] RECALL_API_KEY is not set or is placeholder. Please set RECALL_API_KEY environment variable.")
      nil
    else
      key
    end
  end

  defp api_url, do: Application.get_env(:post_meeting_app, :recall)[:api_url] || "https://api.recall.ai/api/v1"

  defp build_url(path) do
    base_url = api_url() |> String.trim_trailing("/")
    path = String.trim_leading(path, "/")
    "#{base_url}/#{path}"
  end

  def create_bot(meeting_url) do
    key = api_key()
    
    if is_nil(key) do
      Logger.error("[Recall.Client] Cannot create bot - API key is not configured")
      {:error, :api_key_not_configured}
    else
      url = build_url("bot")
      headers = [
        {"Authorization", "Token #{key}"},
        {"Content-Type", "application/json"}
      ]

      body =
        Jason.encode!(%{
          meeting_url: meeting_url,
          recording_config: %{
            transcript: %{
              provider: %{
                recallai_streaming: %{
                  mode: "prioritize_low_latency",
                  language_code: "en"
                }
              }
            }
          }
        })

      Logger.info("[Recall.Client] Creating bot for meeting URL: #{meeting_url}")
      Logger.info("[Recall.Client] Base API URL: #{api_url()}")
      Logger.info("[Recall.Client] Full API URL: #{url}")
      Logger.info("[Recall.Client] API Key: #{if key, do: "#{String.slice(key, 0..10)}...#{String.slice(key, -4..-1)} (full length: #{String.length(key)})", else: "NOT SET"}")
      Logger.info("[Recall.Client] Full API Key (for debugging): #{key}")
      
      # Print equivalent curl command for debugging
      curl_command = """
      curl --location '#{url}' \\
      --header 'Authorization: Token #{key}' \\
      --header 'Content-Type: application/json' \\
      --data '#{body}'
      """
      Logger.info("[Recall.Client] Equivalent curl command:\\n#{curl_command}")

      case Finch.build(:post, url, headers, body) |> Finch.request(PostMeetingApp.Finch) do
        {:ok, %{status: 201, body: body}} ->
          data = Jason.decode!(body)
          Logger.info("[Recall.Client] Bot created successfully: #{inspect(data)}")
          {:ok, data}

        {:ok, %{status: 401, body: body}} ->
          Logger.error("[Recall.Client] Authentication failed (401). API key may be invalid or for wrong region.")
          Logger.error("[Recall.Client] Response: #{body}")
          Logger.error("[Recall.Client] Current API URL: #{api_url()}")
          Logger.error("[Recall.Client] Recall.ai supports multiple regions. Verify your API key matches the correct region URL:")
          Logger.error("[Recall.Client] - us-east-1: https://api.recall.ai/api/v1")
          Logger.error("[Recall.Client] - us-west-2: https://us-west-2.recall.ai/api/v1")
          Logger.error("[Recall.Client] - eu-central-1: https://eu-central-1.recall.ai/api/v1")
          Logger.error("[Recall.Client] - ap-northeast-1: https://ap-northeast-1.recall.ai/api/v1")
          {:error, {:http_error, 401, body}}

        {:ok, %{status: status, body: body}} ->
          Logger.error("[Recall.Client] HTTP error #{status}: #{body}")
          {:error, {:http_error, status, body}}

        error ->
          Logger.error("[Recall.Client] Request failed: #{inspect(error)}")
          error
      end
    end
  end

  def get_bot_status(bot_id) do
    require Logger
    
    key = api_key()
    
    if is_nil(key) do
      Logger.error("[Recall.Client] Cannot get bot status - API key is not configured")
      {:error, :api_key_not_configured}
    else
      url = build_url("bot/#{bot_id}")
      headers = [{"Authorization", "Token #{key}"}, {"Content-Type", "application/json"}]

      Logger.info("[Recall.Client] Getting bot status for bot_id: #{bot_id}")
      Logger.info("[Recall.Client] API URL: #{url}")
      Logger.info("[Recall.Client] API Key: #{if key, do: "#{String.slice(key, 0..10)}...#{String.slice(key, -4..-1)} (full length: #{String.length(key)})", else: "NOT SET"}")
      
      # Print equivalent curl command for debugging
      curl_command = """
      curl --location '#{url}' \\
      --header 'Authorization: Token #{key}' \\
      --header 'Content-Type: application/json'
      """
      Logger.info("[Recall.Client] Equivalent curl command:\\n#{curl_command}")

      case Finch.build(:get, url, headers) |> Finch.request(PostMeetingApp.Finch) do
        {:ok, %{status: 200, body: body}} ->
          data = Jason.decode!(body)
          Logger.info("[Recall.Client] Bot status API call successful (200)")
          Logger.info("[Recall.Client] Response structure: recordings=#{length(Map.get(data, "recordings", []))}, status_changes=#{length(Map.get(data, "status_changes", []))}")
          
          # Log key response fields
          if Map.has_key?(data, "recordings") and length(Map.get(data, "recordings", [])) > 0 do
            recording = List.first(Map.get(data, "recordings", []))
            transcript_data = get_in(recording, ["media_shortcuts", "transcript"])
            if transcript_data do
              transcript_status = get_in(transcript_data, ["status", "code"])
              download_url = get_in(transcript_data, ["data", "download_url"])
              Logger.info("[Recall.Client] Transcript status: #{transcript_status || "nil"}, has_download_url: #{!is_nil(download_url)}")
            end
          end
          
          status_changes = Map.get(data, "status_changes", [])
          if length(status_changes) > 0 do
            latest_status = List.last(status_changes) |> Map.get("code")
            Logger.info("[Recall.Client] Latest bot status: #{latest_status}")
          end
          
          {:ok, data}

        {:ok, %{status: 401, body: body}} ->
          Logger.error("[Recall.Client] Authentication failed (401) getting bot status. API key may be invalid.")
          Logger.error("[Recall.Client] Response: #{body}")
          {:error, {:http_error, 401, body}}

        {:ok, %{status: status, body: body}} ->
          Logger.error("[Recall.Client] HTTP error #{status} getting bot status: #{body}")
          {:error, {:http_error, status, body}}

        error ->
          Logger.error("[Recall.Client] Request failed getting bot status: #{inspect(error)}")
          error
      end
    end
  end

  def get_transcript(media_id) do
    key = api_key()
    
    if is_nil(key) do
      {:error, :api_key_not_configured}
    else
      url = build_url("media/#{media_id}/transcript")
      headers = [{"Authorization", "Token #{key}"}, {"Content-Type", "application/json"}]

      case Finch.build(:get, url, headers) |> Finch.request(PostMeetingApp.Finch) do
        {:ok, %{status: 200, body: body}} ->
          data = Jason.decode!(body)
          # Extract transcript text from response
          transcript_text = extract_transcript_text(data)
          {:ok, transcript_text}

        {:ok, %{status: 401, body: body}} ->
          Logger.error("[Recall.Client] Authentication failed (401) getting transcript. API key may be invalid.")
          {:error, {:http_error, 401, body}}

        {:ok, %{status: status, body: body}} ->
          Logger.error("[Recall.Client] HTTP error #{status} getting transcript: #{body}")
          {:error, {:http_error, status, body}}

        error ->
          Logger.error("[Recall.Client] Request failed getting transcript: #{inspect(error)}")
          error
      end
    end
  end

  defp extract_transcript_text(data) when is_map(data) do
    # Assuming transcript is in data["transcript"] or similar
    # Adjust based on actual Recall.ai API response structure
    case data do
      %{"transcript" => transcript} when is_binary(transcript) -> transcript
      %{"transcript" => segments} when is_list(segments) -> format_segments(segments)
      %{"text" => text} -> text
      _ -> Jason.encode!(data)
    end
  end

  defp format_segments(segments) do
    segments
    |> Enum.map(fn segment ->
      speaker = Map.get(segment, "speaker", "Speaker")
      text = Map.get(segment, "text", "")
      "#{speaker}: #{text}"
    end)
    |> Enum.join("\n")
  end
end

