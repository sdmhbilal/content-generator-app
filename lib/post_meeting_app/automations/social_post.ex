defmodule PostMeetingApp.Automations.SocialPost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "social_posts" do
    field :content, :string
    field :social_network, :string
    field :posted, :boolean, default: false
    field :posted_at, :utc_datetime
    field :external_post_id, :string

    belongs_to :meeting, PostMeetingApp.Meetings.Meeting
    belongs_to :automation, PostMeetingApp.Automations.Automation

    timestamps(type: :utc_datetime)
  end

  def changeset(social_post, attrs) do
    social_post
    |> cast(attrs, [
      :content,
      :social_network,
      :posted,
      :posted_at,
      :external_post_id,
      :meeting_id,
      :automation_id
    ])
    |> validate_required([:content, :social_network, :meeting_id, :automation_id])
  end
end

