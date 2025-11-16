defmodule PostMeetingApp.Automations.Automation do
  use Ecto.Schema
  import Ecto.Changeset

  @networks ["linkedin", "facebook"]

  schema "automations" do
    field :name, :string
    field :social_network, :string
    field :instructions, :string
    field :example, :string

    belongs_to :user, PostMeetingApp.Accounts.User
    has_many :social_posts, PostMeetingApp.Automations.SocialPost

    timestamps(type: :utc_datetime)
  end

  def changeset(automation, attrs) do
    automation
    |> cast(attrs, [:name, :social_network, :instructions, :example, :user_id])
    |> validate_required([:name, :social_network, :instructions, :user_id])
    |> validate_inclusion(:social_network, @networks)
    |> unique_constraint([:user_id, :name])
  end
end

