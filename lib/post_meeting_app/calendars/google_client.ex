defmodule PostMeetingApp.Calendars.GoogleClient do
  @moduledoc """
  Client for Google Calendar API
  """

  @base_url "https://www.googleapis.com/calendar/v3"

  def list_calendars(access_token) do
    url = "#{@base_url}/users/me/calendarList"
    headers = [{"Authorization", "Bearer #{access_token}"}, {"Content-Type", "application/json"}]

    case Finch.build(:get, url, headers) |> Finch.request(PostMeetingApp.Finch) do
      {:ok, %{status: 200, body: body}} ->
        data = Jason.decode!(body)
        {:ok, data["items"] || []}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      error ->
        error
    end
  end

  def list_events(access_token, calendar_id, opts \\ []) do
    params =
      [
        timeMin: opts[:time_min] || DateTime.utc_now() |> DateTime.to_iso8601(),
        timeMax: opts[:time_max],
        maxResults: opts[:max_results] || 250
      ]
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> URI.encode_query()

    url = "#{@base_url}/calendars/#{URI.encode(calendar_id)}/events?#{params}"
    headers = [{"Authorization", "Bearer #{access_token}"}, {"Content-Type", "application/json"}]

    case Finch.build(:get, url, headers) |> Finch.request(PostMeetingApp.Finch) do
      {:ok, %{status: 200, body: body}} ->
        data = Jason.decode!(body)
        {:ok, data["items"] || []}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      error ->
        error
    end
  end
end

