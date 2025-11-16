defmodule PostMeetingApp.Calendars.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @platforms ["zoom", "meet", "teams"]

  schema "events" do
    field :google_event_id, :string
    field :google_calendar_id, :string
    field :title, :string
    field :description, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :meeting_url, :string
    field :meeting_platform, :string
    field :attendees, {:array, :string}, default: []
    field :send_notetaker, :boolean, default: false
    field :synced_at, :utc_datetime

    belongs_to :user, PostMeetingApp.Accounts.User
    has_one :meeting, PostMeetingApp.Meetings.Meeting

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :google_event_id,
      :google_calendar_id,
      :title,
      :description,
      :start_time,
      :end_time,
      :meeting_url,
      :meeting_platform,
      :attendees,
      :send_notetaker,
      :synced_at,
      :user_id
    ])
    |> validate_required([:google_event_id, :title, :start_time, :end_time, :user_id])
    |> validate_inclusion(:meeting_platform, @platforms ++ [nil])
    |> unique_constraint([:user_id, :google_event_id, :google_calendar_id])
  end

  def detect_platform(url) when is_binary(url) do
    cond do
      String.contains?(url, "zoom.us") -> "zoom"
      String.contains?(url, "meet.google.com") -> "meet"
      String.contains?(url, "teams.microsoft.com") -> "teams"
      true -> nil
    end
  end

  def detect_platform(_), do: nil
end

