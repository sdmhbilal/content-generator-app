defmodule PostMeetingApp.Meetings.Transcript do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transcripts" do
    field :content, :string
    field :recall_media_id, :string
    field :recall_status, :string

    belongs_to :meeting, PostMeetingApp.Meetings.Meeting

    timestamps(type: :utc_datetime)
  end

  def changeset(transcript, attrs) do
    transcript
    |> cast(attrs, [:content, :recall_media_id, :recall_status, :meeting_id])
    |> validate_required([:content, :meeting_id])
    |> unique_constraint(:meeting_id)
  end
end

