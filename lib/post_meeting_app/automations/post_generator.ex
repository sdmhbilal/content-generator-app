defmodule PostMeetingApp.Automations.PostGenerator do
  @moduledoc """
  Generates social media posts and follow-up emails using OpenAI
  """

  defp api_key, do: Application.get_env(:post_meeting_app, :openai)[:api_key]
  defp api_url, do: Application.get_env(:post_meeting_app, :openai)[:api_url]

  def generate_post(transcript, instructions, meeting) do
    require Logger
    
    Logger.info("[PostGenerator] Starting social media post generation for meeting #{meeting.id}")
    Logger.info("[PostGenerator] Instructions length: #{String.length(instructions)} characters")
    
    prompt = build_post_prompt(transcript, instructions, meeting)

    case call_openai(prompt, :post) do
      {:ok, content} -> content
      {:error, _} -> "Error generating post. Please try again."
    end
  end

  def generate_follow_up_email(transcript, meeting) do
    require Logger
    
    Logger.info("[PostGenerator] Starting follow-up email generation for meeting #{meeting.id}")
    Logger.info("[PostGenerator] Meeting title: #{meeting.title}")
    Logger.info("[PostGenerator] Transcript length: #{String.length(transcript)} characters")
    
    # Validate API key before proceeding
    api_key_value = api_key()
    env_key = System.get_env("OPENAI_API_KEY")
    
    Logger.info("[PostGenerator] API Key Check:")
    Logger.info("  - From Application config: #{if api_key_value, do: "#{String.slice(api_key_value, 0..10)}...#{String.slice(api_key_value, -4..-1)} (length: #{String.length(api_key_value)})", else: "nil"}")
    Logger.info("  - From System.get_env: #{if env_key, do: "#{String.slice(env_key, 0..10)}...#{String.slice(env_key, -4..-1)} (length: #{String.length(env_key)})", else: "nil"}")
    Logger.info("  - Keys match: #{api_key_value == env_key}")
    
    if is_nil(api_key_value) || api_key_value == "" do
      Logger.error("[PostGenerator] OpenAI API key is not configured")
      Logger.error("[PostGenerator] Please set OPENAI_API_KEY environment variable or update .env file")
      {:error, :api_key_not_configured}
    else
      prompt = build_email_prompt(transcript, meeting)
      Logger.info("[PostGenerator] Email prompt built, length: #{String.length(prompt)} characters")
      Logger.debug("[PostGenerator] Email prompt preview: #{String.slice(prompt, 0..200)}...")

      case call_openai(prompt, :email) do
        {:ok, content} ->
          Logger.info("[PostGenerator] Follow-up email generated successfully for meeting #{meeting.id}")
          Logger.info("[PostGenerator] Generated email length: #{String.length(content)} characters")
          Logger.debug("[PostGenerator] Generated email preview: #{String.slice(content, 0..200)}...")
          {:ok, content}
        
        {:error, reason} ->
          Logger.error("[PostGenerator] Failed to generate follow-up email for meeting #{meeting.id}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp build_post_prompt(transcript, instructions, meeting) do
    """
    You are a social media content generator. Based on the following meeting transcript and instructions, generate a professional social media post.

    Meeting Title: #{meeting.title}
    Attendees: #{Enum.join(meeting.attendees || [], ", ")}
    Date: #{format_datetime(meeting.start_time)}

    Instructions for this automation:
    #{instructions}

    Meeting Transcript:
    #{transcript}

    Generate a social media post that:
    1. Is engaging and professional
    2. Highlights key takeaways from the meeting
    3. Follows the provided instructions
    4. Is appropriate for the target social network

    Return only the post content, no additional formatting or explanations.
    """
  end

  defp build_email_prompt(transcript, meeting) do
    """
    You are an email assistant. Based on the following meeting transcript, generate a professional follow-up email.

    Meeting Title: #{meeting.title}
    Attendees: #{Enum.join(meeting.attendees || [], ", ")}
    Date: #{format_datetime(meeting.start_time)}

    Meeting Transcript:
    #{transcript}

    Generate a follow-up email that:
    1. Thanks attendees for their time
    2. Summarizes key discussion points
    3. Outlines next steps or action items
    4. Is professional and concise

    Return only the email body content, no subject line or additional formatting.
    """
  end

  defp call_openai(prompt, type \\ :post) do
    require Logger
    
    url = "#{api_url()}/chat/completions"
    api_key_value = api_key()
    
    if is_nil(api_key_value) || api_key_value == "" do
      Logger.error("[PostGenerator] Cannot call OpenAI API - API key is not configured")
      {:error, :api_key_not_configured}
    else
      headers = [
        {"Authorization", "Bearer #{api_key_value}"},
        {"Content-Type", "application/json"}
      ]

      body =
        case Jason.encode(%{
          model: "gpt-4o-mini",
          messages: [
            %{
              role: "system",
              content: "You are a professional content writer specializing in business communications and social media."
            },
            %{role: "user", content: prompt}
          ],
          temperature: 0.7,
          max_tokens: 1000
        }) do
          {:ok, encoded_body} -> encoded_body
          {:error, reason} ->
            Logger.error("[PostGenerator] Failed to encode request body: #{inspect(reason)}")
            {:error, :json_encode_error}
        end
      
      case body do
        {:error, _} = error ->
          error
        
        encoded_body ->
          Logger.info("[PostGenerator] Calling OpenAI API for #{type}")
          Logger.info("[PostGenerator] API URL: #{url}")
          Logger.info("[PostGenerator] API Key: #{String.slice(api_key_value, 0..10)}...#{String.slice(api_key_value, -4..-1)} (full length: #{String.length(api_key_value)})")
          Logger.info("[PostGenerator] Request body size: #{String.length(encoded_body)} bytes")
          Logger.debug("[PostGenerator] Request body: #{String.slice(encoded_body, 0..500)}...")

          case Finch.build(:post, url, headers, encoded_body) |> Finch.request(PostMeetingApp.Finch) do
            {:ok, %{status: 200, body: response_body}} ->
              Logger.info("[PostGenerator] OpenAI API call successful (200)")
              
              case Jason.decode(response_body) do
                {:ok, data} ->
                  content = get_in(data, ["choices", Access.at(0), "message", "content"])
                  
                  if content do
                    Logger.info("[PostGenerator] Content extracted successfully, length: #{String.length(content)} characters")
                    {:ok, content}
                  else
                    Logger.error("[PostGenerator] No content in OpenAI response: #{inspect(data)}")
                    {:error, :no_content_in_response}
                  end
                
                {:error, reason} ->
                  Logger.error("[PostGenerator] Failed to decode OpenAI response: #{inspect(reason)}")
                  Logger.error("[PostGenerator] Response body: #{String.slice(response_body, 0..500)}")
                  {:error, {:json_decode_error, reason}}
              end

            {:ok, %{status: status, body: body}} ->
              Logger.error("[PostGenerator] OpenAI API error #{status}")
              Logger.error("[PostGenerator] Error response body: #{String.slice(body, 0..1000)}")
              
              # Try to parse error message from response
              error_message = 
                case Jason.decode(body) do
                  {:ok, error_data} -> 
                    get_in(error_data, ["error", "message"]) || get_in(error_data, ["error", "type"]) || "Unknown error"
                  _ -> 
                    String.slice(body, 0..200)
                end
              
              Logger.error("[PostGenerator] OpenAI API error message: #{error_message}")
              {:error, {:http_error, status, error_message}}

            error ->
              Logger.error("[PostGenerator] OpenAI API request failed: #{inspect(error)}")
              {:error, error}
          end
      end
    end
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %I:%M %p")
  end

  defp format_datetime(_), do: "Unknown date"
end

