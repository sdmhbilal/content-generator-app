defmodule PostMeetingApp.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ["pending", "scheduled", "recording", "processing", "completed", "failed"]

  schema "meetings" do
    field :title, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :attendees, {:array, :string}, default: []
    field :platform, :string
    field :recall_bot_id, :string
    field :recall_status, :string, default: "pending"
    field :transcript_available, :boolean, default: false

    belongs_to :user, PostMeetingApp.Accounts.User
    belongs_to :event, PostMeetingApp.Calendars.Event
    has_one :transcript, PostMeetingApp.Meetings.Transcript
    has_one :follow_up_email, PostMeetingApp.Meetings.FollowUpEmail
    has_many :social_posts, PostMeetingApp.Automations.SocialPost

    timestamps(type: :utc_datetime)
  end

  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [
      :title,
      :start_time,
      :end_time,
      :attendees,
      :platform,
      :recall_bot_id,
      :recall_status,
      :transcript_available,
      :user_id,
      :event_id
    ])
    |> validate_required([:title, :start_time, :user_id])
    |> validate_inclusion(:recall_status, @statuses)
  end
end

