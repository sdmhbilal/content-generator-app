defmodule PostMeetingApp.Accounts.OAuthToken do
  use Ecto.Schema
  import Ecto.Changeset

  @providers [:google, :linkedin, :facebook]

  schema "oauth_tokens" do
    field :provider, Ecto.Enum, values: @providers
    field :account_id, :string
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :scope, :string

    belongs_to :user, PostMeetingApp.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(oauth_token, attrs) do
    oauth_token
    |> cast(attrs, [:provider, :account_id, :access_token, :refresh_token, :expires_at, :scope, :user_id])
    |> validate_required([:provider, :access_token, :user_id])
    |> unique_constraint([:user_id, :provider, :account_id])
  end

  def expired?(token) do
    case token.expires_at do
      nil -> false
      expires_at -> DateTime.compare(DateTime.utc_now(), expires_at) == :gt
    end
  end
end

