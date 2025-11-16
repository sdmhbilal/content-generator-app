defmodule PostMeetingApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :avatar_url, :string
    field :google_account_id, :string

    has_many :oauth_tokens, PostMeetingApp.Accounts.OAuthToken
    has_one :settings, PostMeetingApp.Accounts.UserSettings
    has_many :events, PostMeetingApp.Calendars.Event
    has_many :meetings, PostMeetingApp.Meetings.Meeting
    has_many :automations, PostMeetingApp.Automations.Automation

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url, :google_account_id])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> unique_constraint(:email)
  end
end

