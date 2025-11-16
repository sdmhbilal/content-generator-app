defmodule PostMeetingApp.Meetings.FollowUpEmail do
  use Ecto.Schema
  import Ecto.Changeset

  schema "follow_up_emails" do
    field :content, :string
    field :subject, :string

    belongs_to :meeting, PostMeetingApp.Meetings.Meeting

    timestamps(type: :utc_datetime)
  end

  def changeset(follow_up_email, attrs) do
    follow_up_email
    |> cast(attrs, [:content, :subject, :meeting_id])
    |> validate_required([:content, :meeting_id])
    |> unique_constraint(:meeting_id)
  end
end

