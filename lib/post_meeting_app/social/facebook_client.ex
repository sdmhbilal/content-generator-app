defmodule PostMeetingApp.Social.FacebookClient do
  @moduledoc """
  Client for Facebook Graph API
  """

  @base_url "https://graph.facebook.com/v18.0"

  def post_to_feed(access_token, message) do
    # Get user's page ID or use /me
    url = "#{@base_url}/me/feed"
    params = URI.encode_query(%{message: message, access_token: access_token})
    full_url = "#{url}?#{params}"

    headers = [{"Content-Type", "application/json"}]

    case Finch.build(:post, full_url, headers) |> Finch.request(PostMeetingApp.Finch) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      error ->
        error
    end
  end
end

