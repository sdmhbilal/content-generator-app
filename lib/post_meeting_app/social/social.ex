defmodule PostMeetingApp.Social do
  require Logger
  alias PostMeetingApp.Social.{LinkedInClient, FacebookClient}
  alias PostMeetingApp.Automations
  alias PostMeetingApp.Accounts

  def post_to_linkedin(user_id, post_id) do
    require Logger
    
    Logger.info("[Social] Starting LinkedIn post for user #{user_id}, post_id #{post_id}")
    
    post = Automations.get_social_post!(post_id)
    Logger.info("[Social] Post loaded - ID: #{post.id}, Network: #{post.social_network}, Content length: #{String.length(post.content)} characters")
    
    token = Accounts.get_oauth_token(user_id, :linkedin)

    if token do
      Logger.info("[Social] LinkedIn OAuth token found - Token ID: #{token.id}")
      
      # Check if token is expired
      if PostMeetingApp.Accounts.OAuthToken.expired?(token) do
        Logger.error("[Social] LinkedIn access token is expired")
        {:error, :token_expired}
      else
        Logger.info("[Social] Token is valid, proceeding with post")
        
        case LinkedInClient.post_update(token.access_token, post.content) do
          {:ok, response} ->
            Logger.info("[Social] LinkedIn post successful!")
            Logger.info("[Social] LinkedIn API response: #{inspect(response)}")
            
            # Try to extract post ID from various possible locations
            external_id = 
              Map.get(response, "id") || 
              get_in(response, ["id"]) ||
              Map.get(response, "location") ||
              get_in(response, ["location"])
            
            if external_id do
              Logger.info("[Social] External post ID: #{external_id}")
              Automations.mark_posted(post, external_id)
              Logger.info("[Social] Post marked as posted in database")
              {:ok, post}
            else
              Logger.warning("[Social] LinkedIn API response did not contain 'id' or 'location' field")
              Logger.warning("[Social] Full response: #{inspect(response)}")
              # Still mark as posted if we got a 201 response (post was created)
              fallback_id = "linkedin_#{post.id}_#{DateTime.utc_now() |> DateTime.to_unix()}"
              Logger.info("[Social] Using fallback ID: #{fallback_id}")
              Automations.mark_posted(post, fallback_id)
              {:ok, post}
            end

          {:error, {:http_error, status, message}} ->
            Logger.error("[Social] LinkedIn API error - Status: #{status}")
            Logger.error("[Social] Error message: #{message}")
            {:error, {:http_error, status, message}}

          {:error, {:timeout, message}} ->
            Logger.error("[Social] LinkedIn API request timed out: #{message}")
            {:error, {:timeout, message}}

          {:error, {:transport_error, message}} ->
            Logger.error("[Social] Network error posting to LinkedIn: #{message}")
            {:error, {:transport_error, message}}

          error ->
            Logger.error("[Social] Unexpected error posting to LinkedIn: #{inspect(error)}")
            {:error, error}
        end
      end
    else
      Logger.error("[Social] No LinkedIn OAuth token found for user #{user_id}")
      {:error, :no_token}
    end
  end

  def post_to_facebook(user_id, post_id) do
    post = Automations.get_social_post!(post_id)
    token = Accounts.get_oauth_token(user_id, :facebook)

    if token do
      case FacebookClient.post_to_feed(token.access_token, post.content) do
        {:ok, %{"id" => external_id}} ->
          Automations.mark_posted(post, external_id)
          {:ok, post}

        error ->
          error
      end
    else
      {:error, :no_token}
    end
  end
end

