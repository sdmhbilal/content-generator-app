defmodule PostMeetingApp.Accounts do
  import Ecto.Query, warn: false
  alias PostMeetingApp.Repo
  alias PostMeetingApp.Accounts.{User, OAuthToken, UserSettings}

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_google_account_id(google_account_id) do
    Repo.get_by(User, google_account_id: google_account_id)
  end

  def create_or_update_user(attrs) do
    case get_user_by_email(attrs[:email]) do
      nil -> create_user(attrs)
      user -> update_user(user, attrs)
    end
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    |> maybe_create_settings()
  end

  defp maybe_create_settings({:ok, user}) do
    case get_settings(user.id) do
      nil -> create_default_settings(user.id)
      _ -> {:ok, user}
    end
  end

  defp maybe_create_settings(error), do: error

  defp create_default_settings(user_id) do
    %UserSettings{}
    |> UserSettings.changeset(%{user_id: user_id, minutes_before_meeting: 5})
    |> Repo.insert()
    |> case do
      {:ok, _} -> {:ok, Repo.get!(User, user_id)}
      error -> error
    end
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def get_settings(user_id) do
    Repo.get_by(UserSettings, user_id: user_id)
  end

  def update_settings(user_id, attrs) do
    case get_settings(user_id) do
      nil ->
        %UserSettings{}
        |> UserSettings.changeset(Map.put(attrs, :user_id, user_id))
        |> Repo.insert()

      settings ->
        settings
        |> UserSettings.changeset(attrs)
        |> Repo.update()
    end
  end

  def get_oauth_token(user_id, provider, account_id \\ nil) do
    query =
      from t in OAuthToken,
        where: t.user_id == ^user_id and t.provider == ^provider

    query =
      if account_id do
        where(query, [t], t.account_id == ^account_id)
      else
        query
      end

    Repo.one(query)
  end

  def create_or_update_oauth_token(user_id, provider, attrs) do
    require Logger
    
    Logger.info("create_or_update_oauth_token called - User ID: #{inspect(user_id)}, Provider: #{inspect(provider)}")
    Logger.info("Token attrs (excluding access_token): #{inspect(Map.drop(attrs, [:access_token]))}")
    
    # Validate user_id
    if is_nil(user_id) do
      Logger.error("create_or_update_oauth_token: user_id is nil!")
      {:error, :invalid_user_id}
    else
      # Check if user exists
      case Repo.get(User, user_id) do
        nil ->
          Logger.error("create_or_update_oauth_token: User #{user_id} does not exist!")
          {:error, :user_not_found}
        
        _user ->
          Logger.info("User #{user_id} exists, proceeding with token save")
          
          account_id = attrs[:account_id] || attrs["account_id"]
          Logger.info("Looking for existing token with account_id: #{inspect(account_id)}")
          
          case get_oauth_token(user_id, provider, account_id) do
            nil ->
              Logger.info("No existing token found, creating new token")
              changeset = 
                %OAuthToken{}
                |> OAuthToken.changeset(Map.merge(attrs, %{user_id: user_id, provider: provider}))
              
              Logger.info("Changeset valid?: #{changeset.valid?}")
              if not changeset.valid? do
                Logger.error("Changeset invalid before insert: #{inspect(changeset.errors)}")
              end
              
              result = Repo.insert(changeset)
              
              case result do
                {:ok, token} ->
                  Logger.info("Token created successfully - ID: #{token.id}")
                {:error, changeset} ->
                  Logger.error("Token insert failed: #{inspect(changeset.errors)}")
              end
              
              result

            token ->
              Logger.info("Existing token found - ID: #{token.id}, updating...")
              changeset = 
                token
                |> OAuthToken.changeset(attrs)
              
              Logger.info("Changeset valid?: #{changeset.valid?}")
              if not changeset.valid? do
                Logger.error("Changeset invalid before update: #{inspect(changeset.errors)}")
              end
              
              result = Repo.update(changeset)
              
              case result do
                {:ok, token} ->
                  Logger.info("Token updated successfully - ID: #{token.id}")
                {:error, changeset} ->
                  Logger.error("Token update failed: #{inspect(changeset.errors)}")
              end
              
              result
          end
      end
    end
  end

  def list_oauth_tokens(user_id) do
    from(t in OAuthToken, where: t.user_id == ^user_id)
    |> Repo.all()
  end

  def refresh_oauth_token(%OAuthToken{} = token) do
    require Logger
    
    case token.provider do
      :google ->
        refresh_google_token(token)
      
      _ ->
        Logger.warning("Token refresh not implemented for provider: #{token.provider}")
        {:error, :refresh_not_supported}
    end
  end

  defp refresh_google_token(%OAuthToken{refresh_token: nil}) do
    require Logger
    Logger.error("Cannot refresh Google token - no refresh_token available")
    {:error, :no_refresh_token}
  end

  defp refresh_google_token(%OAuthToken{} = token) do
    require Logger
    
    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]
    client_secret = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]
    
    if is_nil(client_id) || is_nil(client_secret) do
      Logger.error("Google OAuth credentials not configured")
      {:error, :credentials_not_configured}
    else
      url = "https://oauth2.googleapis.com/token"
      
      body =
        URI.encode_query(%{
          client_id: client_id,
          client_secret: client_secret,
          refresh_token: token.refresh_token,
          grant_type: "refresh_token"
        })
      
      headers = [{"Content-Type", "application/x-www-form-urlencoded"}]
      
      Logger.info("Refreshing Google OAuth token for user #{token.user_id}")
      
      case Finch.build(:post, url, headers, body) |> Finch.request(PostMeetingApp.Finch) do
        {:ok, %{status: 200, body: response_body}} ->
          data = Jason.decode!(response_body)
          
          new_access_token = data["access_token"]
          expires_in = data["expires_in"] || 3600
          
          # Calculate new expiry time
          new_expires_at = 
            DateTime.utc_now()
            |> DateTime.add(expires_in, :second)
          
          # Update token in database
          attrs = %{
            access_token: new_access_token,
            expires_at: new_expires_at
          }
          
          # If a new refresh_token is provided, update it too
          attrs = 
            if data["refresh_token"] do
              Map.put(attrs, :refresh_token, data["refresh_token"])
            else
              attrs
            end
          
          changeset = OAuthToken.changeset(token, attrs)
          
          case Repo.update(changeset) do
            {:ok, updated_token} ->
              Logger.info("Google token refreshed successfully for user #{token.user_id}. New expiry: #{DateTime.to_iso8601(new_expires_at)}")
              {:ok, updated_token}
            
            {:error, changeset} ->
              Logger.error("Failed to save refreshed token: #{inspect(changeset.errors)}")
              {:error, :save_failed}
          end
        
        {:ok, %{status: status, body: body}} ->
          Logger.error("Failed to refresh Google token: HTTP #{status} - #{body}")
          {:error, {:http_error, status, body}}
        
        error ->
          Logger.error("Failed to refresh Google token: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end

