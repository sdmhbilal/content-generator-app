defmodule PostMeetingApp.Accounts.UserSettings do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_settings" do
    field :minutes_before_meeting, :integer, default: 5

    belongs_to :user, PostMeetingApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:minutes_before_meeting, :user_id])
    |> validate_required([:user_id])
    |> validate_number(:minutes_before_meeting, greater_than: 0, less_than: 60)
    |> unique_constraint(:user_id)
  end
end

