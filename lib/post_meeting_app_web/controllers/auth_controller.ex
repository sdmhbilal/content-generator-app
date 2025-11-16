defmodule PostMeetingAppWeb.AuthController do
  use PostMeetingAppWeb, :controller

  alias PostMeetingApp.Accounts
  alias Ueberauth.Strategy.Helpers

  plug Ueberauth

  def request(conn, _params) do
    # Ueberauth plug handles the redirect automatically
    # The scope is configured in config.exs
    # But we can also pass it via query param: /auth/google?scope=...
    render(conn, "request.html", callback_url: Helpers.callback_url(conn))
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    require Logger
    
    user_params = %{
      email: auth.info.email,
      name: auth.info.name,
      avatar_url: auth.info.image,
      google_account_id: auth.uid
    }

    case Accounts.create_or_update_user(user_params) do
      {:ok, user} ->
        # Store OAuth token - this will update if it already exists
        scopes = auth.credentials.scopes && Enum.join(auth.credentials.scopes, " ")
        Logger.info("Google OAuth callback - Scopes received: #{inspect(scopes)}")
        
        token_params = %{
          provider: :google,
          account_id: auth.uid,
          access_token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          expires_at: auth.credentials.expires_at && DateTime.from_unix!(auth.credentials.expires_at),
          scope: scopes
        }

        case Accounts.create_or_update_oauth_token(user.id, :google, token_params) do
          {:ok, token} ->
            Logger.info("OAuth token updated - Scope: #{token.scope}")
            
            # Check if calendar scope is present
            has_calendar_scope = token.scope && String.contains?(token.scope, "calendar")
            
            if has_calendar_scope do
              # Sync calendars in background
              Task.start(fn ->
                PostMeetingApp.Calendars.sync_calendars(user.id)
              end)
              
              conn
              |> put_session(:user_id, user.id)
              |> put_flash(:info, "Google account connected! Calendar sync started.")
              |> redirect(to: "/dashboard")
            else
              conn
              |> put_session(:user_id, user.id)
              |> put_flash(:warning, "Google account connected, but calendar permissions were not granted. Please try again and make sure to grant calendar access.")
              |> redirect(to: "/dashboard")
            end
          
          {:error, changeset} ->
            Logger.error("Failed to save OAuth token: #{inspect(changeset.errors)}")
            conn
            |> put_session(:user_id, user.id)
            |> put_flash(:error, "Failed to save authentication token")
            |> redirect(to: "/dashboard")
        end

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to authenticate")
        |> redirect(to: "/")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate")
    |> redirect(to: "/")
  end

  def linkedin_request(conn, _params) do
    require Logger
    
    client_id = Application.get_env(:post_meeting_app, :linkedin)[:client_id]
    redirect_uri = Application.get_env(:post_meeting_app, :linkedin)[:redirect_uri]
    user_id = get_session(conn, :user_id)
    
    # Generate state and include user_id for validation
    random_state = :crypto.strong_rand_bytes(16) |> Base.encode16()
    state = "#{user_id}:#{random_state}"
    
    # Store in session as backup
    conn = put_session(conn, :oauth_state, state)
    
    Logger.info("LinkedIn OAuth request - User ID: #{user_id}, State: #{String.slice(state, 0..20)}...")

    # Note: w_member_social scope is required for posting but requires LinkedIn approval.
    # Once approved in your LinkedIn Developer Portal, add "w_member_social" to the scope string.
    url =
      "https://www.linkedin.com/oauth/v2/authorization?" <>
        URI.encode_query(%{
          response_type: "code",
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
          scope: "openid profile email w_member_social"
        })

    redirect(conn, external: url)
  end

  def linkedin_callback(conn, %{"code" => code, "state" => state}) do
    require Logger
    
    Logger.info("LinkedIn callback received - code: #{String.slice(code, 0..10)}..., state: #{state}")
    
    session_state = get_session(conn, :oauth_state)
    user_id = get_session(conn, :user_id)
    
    Logger.info("Session state: #{inspect(session_state)}, User ID: #{inspect(user_id)}")
    
    # Validate state: either from session or extract user_id from state parameter
    state_valid = 
      cond do
        session_state == state -> 
          true
        String.contains?(state, ":") -> 
          # State format: "user_id:random_state"
          [state_user_id | _] = String.split(state, ":", parts: 2)
          state_user_id == to_string(user_id)
        true -> 
          false
      end
    
    if state_valid do
      if user_id do
        Logger.info("Exchanging LinkedIn code for access token...")
        
        case exchange_linkedin_code(code) do
          {:ok, %{access_token: access_token}} ->
            Logger.info("LinkedIn access token received (length: #{String.length(access_token)})")
            
            token_params = %{
              provider: :linkedin,
              access_token: access_token
            }
            
            Logger.info("Attempting to save LinkedIn OAuth token for user #{user_id} with params: #{inspect(Map.drop(token_params, [:access_token]))}")

            case Accounts.create_or_update_oauth_token(user_id, :linkedin, token_params) do
              {:ok, token} ->
                Logger.info("LinkedIn OAuth token saved successfully - ID: #{token.id}, User ID: #{token.user_id}, Provider: #{token.provider}")
                conn
                |> put_flash(:info, "LinkedIn connected successfully")
                |> redirect(to: "/settings")

              {:error, changeset} ->
                Logger.error("Failed to save LinkedIn OAuth token - Errors: #{inspect(changeset.errors)}")
                Logger.error("Changeset changes: #{inspect(changeset.changes)}")
                Logger.error("Changeset data: #{inspect(changeset.data)}")
                conn
                |> put_flash(:error, "Failed to save LinkedIn connection: #{format_changeset_errors(changeset)}")
                |> redirect(to: "/settings")
            end

          {:error, reason} ->
            Logger.error("Failed to exchange LinkedIn code: #{inspect(reason)}")
            conn
            |> put_flash(:error, "Failed to connect LinkedIn")
            |> redirect(to: "/settings")
        end
      else
        Logger.error("LinkedIn callback: No user_id in session. User must be logged in.")
        conn
        |> put_flash(:error, "You must be logged in to connect LinkedIn")
        |> redirect(to: "/")
      end
    else
      Logger.error("LinkedIn callback: State validation failed - Session: #{inspect(session_state)}, Received: #{state}, User ID: #{inspect(user_id)}")
      conn
      |> put_flash(:error, "Invalid state parameter. Please try connecting again.")
      |> redirect(to: "/settings")
    end
  end

  def linkedin_callback(conn, %{"error" => error, "error_description" => error_description}) do
    require Logger
    Logger.error("LinkedIn OAuth error: #{error} - #{error_description}")
    
    conn
    |> put_flash(:error, "LinkedIn authorization failed: #{error_description}")
    |> redirect(to: "/settings")
  end

  def linkedin_callback(conn, _params) do
    conn
    |> put_flash(:error, "Invalid LinkedIn callback parameters")
    |> redirect(to: "/settings")
  end

  def facebook_request(conn, _params) do
    require Logger
    
    client_id = Application.get_env(:post_meeting_app, :facebook)[:client_id]
    redirect_uri = Application.get_env(:post_meeting_app, :facebook)[:redirect_uri]
    user_id = get_session(conn, :user_id)
    
    # Generate state and include user_id for validation
    random_state = :crypto.strong_rand_bytes(16) |> Base.encode16()
    state = "#{user_id}:#{random_state}"
    
    # Store in session as backup
    conn = put_session(conn, :oauth_state, state)
    
    Logger.info("Facebook OAuth request - User ID: #{user_id}, State: #{String.slice(state, 0..20)}...")

    # Note: Facebook permissions have changed. For posting to personal feed (/me/feed),
    # we use basic permissions. For posting to Pages, you'll need to:
    # 1. Request App Review for pages_manage_posts and pages_read_engagement
    # 2. Complete Business Verification
    # 3. Use Page Access Tokens instead of User Access Tokens
    # For now, using public_profile which is always available
    url =
      "https://www.facebook.com/v18.0/dialog/oauth?" <>
        URI.encode_query(%{
          client_id: client_id,
          redirect_uri: redirect_uri,
          state: state,
          scope: "public_profile"
        })

    redirect(conn, external: url)
  end

  def facebook_callback(conn, %{"code" => code, "state" => state}) do
    require Logger
    
    session_state = get_session(conn, :oauth_state)
    user_id = get_session(conn, :user_id)
    
    Logger.info("Facebook callback received - code: #{String.slice(code, 0..10)}..., state: #{state}")
    Logger.info("Session state: #{inspect(session_state)}, User ID: #{inspect(user_id)}")
    
    # Validate state: either from session or extract user_id from state parameter
    state_valid = 
      cond do
        session_state == state -> 
          true
        String.contains?(state, ":") -> 
          # State format: "user_id:random_state"
          [state_user_id | _] = String.split(state, ":", parts: 2)
          state_user_id == to_string(user_id)
        true -> 
          false
      end
    
    if state_valid do
      if user_id do
        case exchange_facebook_code(code) do
        {:ok, %{access_token: access_token}} ->
          token_params = %{
            provider: :facebook,
            access_token: access_token
          }

          case Accounts.create_or_update_oauth_token(user_id, :facebook, token_params) do
            {:ok, _token} ->
              Logger.info("Facebook OAuth token saved successfully for user #{user_id}")
              conn
              |> put_flash(:info, "Facebook connected successfully")
              |> redirect(to: "/settings")

            {:error, changeset} ->
              Logger.error("Failed to save Facebook OAuth token: #{inspect(changeset.errors)}")
              conn
              |> put_flash(:error, "Failed to save Facebook connection")
              |> redirect(to: "/settings")
          end

        {:error, _} ->
          conn
          |> put_flash(:error, "Failed to connect Facebook")
          |> redirect(to: "/settings")
        end
      else
        Logger.error("Facebook callback: No user_id in session. User must be logged in.")
        conn
        |> put_flash(:error, "You must be logged in to connect Facebook")
        |> redirect(to: "/")
      end
    else
      Logger.error("Facebook callback: State validation failed - Session: #{inspect(session_state)}, Received: #{state}, User ID: #{inspect(user_id)}")
      conn
      |> put_flash(:error, "Invalid state parameter. Please try connecting again.")
      |> redirect(to: "/settings")
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end

  defp exchange_linkedin_code(code) do
    require Logger
    
    client_id = Application.get_env(:post_meeting_app, :linkedin)[:client_id]
    client_secret = Application.get_env(:post_meeting_app, :linkedin)[:client_secret]
    redirect_uri = Application.get_env(:post_meeting_app, :linkedin)[:redirect_uri]

    Logger.info("Exchanging LinkedIn code - Client ID: #{String.slice(client_id || "", 0..10)}..., Redirect URI: #{redirect_uri}")

    url = "https://www.linkedin.com/oauth/v2/accessToken"

    body =
      URI.encode_query(%{
        grant_type: "authorization_code",
        code: code,
        redirect_uri: redirect_uri,
        client_id: client_id,
        client_secret: client_secret
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    Logger.info("Making request to LinkedIn token endpoint...")

    case Finch.build(:post, url, headers, body) |> Finch.request(PostMeetingApp.Finch) do
      {:ok, %{status: 200, body: body}} ->
        Logger.info("LinkedIn token exchange successful")
        data = Jason.decode!(body)
        access_token = data["access_token"]
        
        if access_token do
          Logger.info("Access token received (length: #{String.length(access_token)})")
          {:ok, %{access_token: access_token}}
        else
          Logger.error("No access_token in LinkedIn response: #{inspect(data)}")
          {:error, :no_access_token}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error("LinkedIn token exchange failed - Status: #{status}, Body: #{body}")
        {:error, {:http_error, status, body}}

      error ->
        Logger.error("LinkedIn token exchange error: #{inspect(error)}")
        {:error, :exchange_failed}
    end
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp exchange_facebook_code(code) do
    client_id = Application.get_env(:post_meeting_app, :facebook)[:client_id]
    client_secret = Application.get_env(:post_meeting_app, :facebook)[:client_secret]
    redirect_uri = Application.get_env(:post_meeting_app, :facebook)[:redirect_uri]

    url = "https://graph.facebook.com/v18.0/oauth/access_token"

    params =
      URI.encode_query(%{
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        code: code
      })

    case Finch.build(:get, "#{url}?#{params}") |> Finch.request(PostMeetingApp.Finch) do
      {:ok, %{status: 200, body: body}} ->
        data = Jason.decode!(body)
        {:ok, %{access_token: data["access_token"]}}

      _ ->
        {:error, :exchange_failed}
    end
  end
end

