defmodule PostMeetingApp.Social.LinkedInClient do
  @moduledoc """
  Client for LinkedIn API
  """
  require Logger

  @base_url "https://api.linkedin.com"

  def post_update(access_token, text) do
    require Logger
    
    Logger.info("[LinkedInClient] Starting post_update")
    Logger.info("[LinkedInClient] Text length: #{String.length(text)} characters")
    Logger.debug("[LinkedInClient] Text preview: #{String.slice(text, 0..200)}...")
    
    # Get user's URN first (required for author field)
    Logger.info("[LinkedInClient] Step 1: Getting user URN for author field...")
    case get_user_urn(access_token) do
      {:ok, author_urn} ->
        Logger.info("[LinkedInClient] User URN retrieved: #{author_urn}")
        
        # Use /rest/posts endpoint as per LinkedIn Posts API documentation
        # https://learn.microsoft.com/en-us/linkedin/marketing/community-management/shares/posts-api
        # Note: The endpoint is /rest/posts (NOT /v2/rest/posts)
        url = "#{@base_url}/rest/posts"
        
        # Header name must be "Linkedin-Version" (lowercase 'i'), not "LinkedIn-Version"
        # Version format: YYYYMM (6 digits, e.g., 202501 for January 2025)
        linkedin_version = "202501"
        
        headers = [
          {"Authorization", "Bearer #{access_token}"},
          {"X-Restli-Protocol-Version", "2.0.0"},
          {"Linkedin-Version", linkedin_version},
          {"Content-Type", "application/json"}
        ]
        
        Logger.info("[LinkedInClient] Step 2: Posting to LinkedIn Posts API...")
        Logger.info("[LinkedInClient] API URL: #{url}")
        Logger.info("[LinkedInClient] LinkedIn Version: #{linkedin_version}")
        
        # Request body format per LinkedIn Posts API documentation
        body_data = %{
          author: author_urn,
          commentary: text,
          visibility: "PUBLIC",
          distribution: %{
            feedDistribution: "MAIN_FEED",
            targetEntities: [],
            thirdPartyDistributionChannels: []
          },
          lifecycleState: "PUBLISHED",
          isReshareDisabledByAuthor: false
        }
        
        body = Jason.encode!(body_data)
        Logger.info("[LinkedInClient] Request body size: #{String.length(body)} bytes")
        Logger.debug("[LinkedInClient] Request body: #{body}")
        
        # Log the equivalent curl command for debugging/Postman testing
        curl_command = """
        curl -X POST '#{url}' \\
        -H 'Authorization: Bearer #{access_token}' \\
        -H 'X-Restli-Protocol-Version: 2.0.0' \\
        -H 'Linkedin-Version: #{linkedin_version}' \\
        -H 'Content-Type: application/json' \\
        --data '#{body}'
        """
        Logger.info("[LinkedInClient] Equivalent curl command for Postman testing:\\n#{curl_command}")

        # Add timeout options (30 seconds for LinkedIn API)
        # LinkedIn API can be slow, especially for post creation
        request_opts = [
          receive_timeout: 30_000,  # 30 seconds to receive response
          pool_timeout: 10_000       # 10 seconds to get connection from pool
        ]
        Logger.info("[LinkedInClient] Request timeout: 30 seconds (receive), 10 seconds (pool)")
        Logger.info("[LinkedInClient] Starting HTTP request at #{DateTime.utc_now() |> DateTime.to_iso8601()}")

        start_time = System.monotonic_time(:millisecond)
        
        # Log headers with masked authorization token
        masked_headers = Enum.map(headers, fn {k, v} ->
          if k == "Authorization" do
            {k, String.slice(v, 0..20) <> "..."}
          else
            {k, v}
          end
        end)
        Logger.info("[LinkedInClient] Headers: #{inspect(masked_headers)}")
        Logger.info("[LinkedInClient] Sending POST request to #{url}")
        
        result = 
          try do
            request = Finch.build(:post, url, headers, body)
            Finch.request(request, PostMeetingApp.Finch, request_opts)
          catch
            kind, error ->
              Logger.error("[LinkedInClient] Exception during request: #{inspect(kind)} - #{inspect(error)}")
              Logger.error("[LinkedInClient] Exception details: #{Exception.format(kind, error, __STACKTRACE__)}")
              {:error, {:exception, kind, error}}
          end
        
        elapsed = System.monotonic_time(:millisecond) - start_time
        Logger.info("[LinkedInClient] Request completed in #{elapsed}ms")
        
        case result do
          {:ok, %{status: 201, body: response_body, headers: response_headers}} ->
            Logger.info("[LinkedInClient] LinkedIn API call successful (201 Created)")
            
            # LinkedIn Posts API returns post ID in x-restli-id header
            # Format: urn:li:share:{id} or urn:li:ugcPost:{id}
            restli_id_header = 
              Enum.find_value(response_headers, fn {key, value} ->
                if String.downcase(key) == "x-restli-id", do: value
              end)
            
            if restli_id_header do
              Logger.info("[LinkedInClient] Post ID found in x-restli-id header: #{restli_id_header}")
            end
            
            # Try to decode response body
            decoded_data = 
              case Jason.decode(response_body) do
                {:ok, data} ->
                  Logger.info("[LinkedInClient] Response decoded successfully: #{inspect(data)}")
                  # Use x-restli-id header if available, otherwise use response data
                  if restli_id_header do
                    Map.put(data, "id", restli_id_header)
                  else
                    data
                  end
            
                {:error, reason} ->
                  Logger.warning("[LinkedInClient] Failed to decode response body: #{inspect(reason)}")
                  Logger.warning("[LinkedInClient] Response body: #{String.slice(response_body, 0..500)}")
                  # If we have x-restli-id header, we can still consider it successful
                  if restli_id_header do
                    %{"id" => restli_id_header}
                  else
                    %{"response_body" => response_body}
                  end
              end
            
            Logger.info("[LinkedInClient] Post created successfully with ID: #{Map.get(decoded_data, "id", "unknown")}")
            {:ok, decoded_data}

          {:ok, %{status: status, body: body}} ->
            Logger.error("[LinkedInClient] LinkedIn API error - Status: #{status}")
            Logger.error("[LinkedInClient] Error response body: #{String.slice(body, 0..1000)}")
            Logger.error("[LinkedInClient] Request URL: #{url}")
            
            # Log headers with masked authorization token
            masked_headers_for_error = Enum.map(headers, fn {k, v} ->
              if k == "Authorization" do
                {k, String.slice(v, 0..20) <> "..."}
              else
                {k, v}
              end
            end)
            Logger.error("[LinkedInClient] Request headers: #{inspect(masked_headers_for_error)}")
            
            # Try to parse error message
            error_data = 
              case Jason.decode(body) do
                {:ok, data} -> data
                _ -> %{}
              end
            
            error_message = 
              get_in(error_data, ["message"]) || 
              get_in(error_data, ["error", "message"]) || 
              get_in(error_data, ["error"]) ||
              String.slice(body, 0..200)
            
            error_code = get_in(error_data, ["code"]) || get_in(error_data, ["error", "code"])
            
            Logger.error("[LinkedInClient] Error code: #{inspect(error_code)}")
            Logger.error("[LinkedInClient] Error message: #{error_message}")
            
            # Provide specific guidance for common errors
            case status do
              404 ->
                Logger.error("[LinkedInClient] 404 Error - Possible causes:")
                Logger.error("[LinkedInClient] 1. API version #{linkedin_version} may not be available for your app")
                Logger.error("[LinkedInClient] 2. Check your LinkedIn Developer Portal for available API versions")
                Logger.error("[LinkedInClient] 3. Ensure your app has access to Posts API")
                Logger.error("[LinkedInClient] 4. Verify the endpoint URL is correct: #{url}")
              
              403 ->
                Logger.error("[LinkedInClient] 403 Error - Permission denied:")
                Logger.error("[LinkedInClient] Error details: #{error_message}")
                
                # Check if it's specifically the Posts API permission error
                if String.contains?(error_message, "partnerApiPostsExternal.CREATE") do
                  Logger.error("[LinkedInClient] Posts API permission not approved:")
                  Logger.error("[LinkedInClient] 1. Go to https://www.linkedin.com/developers/apps")
                  Logger.error("[LinkedInClient] 2. Select your app and go to 'Products' tab")
                  Logger.error("[LinkedInClient] 3. Request access to 'Marketing Developer Platform' product")
                  Logger.error("[LinkedInClient] 4. Request 'Posts API' access (partnerApiPostsExternal.CREATE)")
                  Logger.error("[LinkedInClient] 5. Submit for LinkedIn review (may take a few days)")
                  Logger.error("[LinkedInClient] 6. After approval, ensure 'w_member_social' permission is also approved")
                  Logger.error("[LinkedInClient] 7. Reconnect your LinkedIn account after all approvals")
                else
                  Logger.error("[LinkedInClient] 1. Ensure you have 'w_member_social' permission approved")
                  Logger.error("[LinkedInClient] 2. Check your LinkedIn Developer Portal permissions")
                  Logger.error("[LinkedInClient] 3. Reconnect your LinkedIn account after permission approval")
                end
              
              _ ->
                Logger.error("[LinkedInClient] HTTP #{status} error occurred")
            end
            
            {:error, {:http_error, status, error_message}}

          {:error, %Mint.TransportError{reason: :timeout}} ->
            Logger.error("[LinkedInClient] Request timed out after 30 seconds")
            Logger.error("[LinkedInClient] This may indicate:")
            Logger.error("[LinkedInClient] - Network connectivity issues")
            Logger.error("[LinkedInClient] - LinkedIn API is slow or unresponsive")
            Logger.error("[LinkedInClient] - The request body might be too large")
            {:error, {:timeout, "LinkedIn API request timed out. Please try again."}}

          {:error, %Mint.TransportError{} = error} ->
            Logger.error("[LinkedInClient] Transport error: #{inspect(error)}")
            {:error, {:transport_error, "Network error connecting to LinkedIn API"}}

          {:error, {:exception, kind, error}} ->
            Logger.error("[LinkedInClient] Unhandled exception during request: #{inspect(kind)} - #{inspect(error)}")
            {:error, {:exception, kind, error}}

          error ->
            Logger.error("[LinkedInClient] Request failed: #{inspect(error)}")
            error
        end

      error ->
        Logger.error("[LinkedInClient] Failed to get user URN: #{inspect(error)}")
        error
    end
  end

  defp get_user_urn(access_token) do
    require Logger
    
    # Use OpenID Connect userinfo endpoint which works with openid profile email scopes
    url = "https://api.linkedin.com/v2/userinfo"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    Logger.info("[LinkedInClient] Getting user URN from OpenID Connect userinfo endpoint: #{url}")
    Logger.info("[LinkedInClient] Access token preview: #{String.slice(access_token, 0..20)}...#{String.slice(access_token, -10..-1)}")

    # Log the equivalent curl command for debugging/Postman testing
    curl_command = """
    curl --location '#{url}' \\
    --header 'Authorization: Bearer #{access_token}'
    """
    Logger.info("[LinkedInClient] Equivalent curl command for userinfo:\\n#{curl_command}")

    # Add timeout options (30 seconds for LinkedIn API)
    request_opts = [
      receive_timeout: 30_000, 
      pool_timeout: 10_000
    ]
    Logger.info("[LinkedInClient] Userinfo request timeout: 30 seconds (receive), 10 seconds (pool)")

    result = 
      try do
        request = Finch.build(:get, url, headers)
        Finch.request(request, PostMeetingApp.Finch, request_opts)
      catch
        kind, error ->
          Logger.error("[LinkedInClient] Exception during userinfo request: #{inspect(kind)} - #{inspect(error)}")
          {:error, {:exception, kind, error}}
      end

    case result do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("[LinkedInClient] User info retrieved successfully")
        
        case Jason.decode(body) do
          {:ok, data} ->
            # OpenID Connect userinfo returns 'sub' (subject) which is the user ID
            user_id = Map.get(data, "sub") || Map.get(data, "id")
            if user_id do
              urn = "urn:li:person:#{user_id}"
              Logger.info("[LinkedInClient] User ID: #{user_id}, URN: #{urn}")
              {:ok, urn}
            else
              Logger.error("[LinkedInClient] No 'sub' or 'id' field in user data: #{inspect(data)}")
              {:error, :no_user_id}
            end
          
          {:error, reason} ->
            Logger.error("[LinkedInClient] Failed to decode user info: #{inspect(reason)}")
            Logger.error("[LinkedInClient] Response body: #{String.slice(body, 0..500)}")
            {:error, {:json_decode_error, reason}}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("[LinkedInClient] Failed to get user info - Status: #{status}")
        Logger.error("[LinkedInClient] Error response: #{String.slice(body, 0..500)}")
        
        error_message = 
          case Jason.decode(body) do
            {:ok, error_data} -> 
              get_in(error_data, ["error", "message"]) || 
              get_in(error_data, ["error_description"]) ||
              get_in(error_data, ["message"]) || 
              String.slice(body, 0..200)
            _ -> 
              String.slice(body, 0..200)
          end
        
        Logger.error("[LinkedInClient] Error message: #{error_message}")
        {:error, {:http_error, status, error_message}}

      {:error, %Mint.TransportError{reason: :timeout}} ->
        Logger.error("[LinkedInClient] Userinfo request timed out after 30 seconds")
        {:error, {:timeout, "LinkedIn userinfo API request timed out. Please try again."}}

      {:error, %Mint.TransportError{} = error} ->
        Logger.error("[LinkedInClient] Transport error getting userinfo: #{inspect(error)}")
        {:error, {:transport_error, "Network error connecting to LinkedIn userinfo API"}}

      {:error, {:exception, kind, error}} ->
        Logger.error("[LinkedInClient] Unhandled exception during userinfo request: #{inspect(kind)} - #{inspect(error)}")
        {:error, {:exception, kind, error}}

      error ->
        Logger.error("[LinkedInClient] Request failed: #{inspect(error)}")
        error
    end
  end
end

