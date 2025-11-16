defmodule PostMeetingApp.Repo.Migrations.CreateOauthTokens do
  use Ecto.Migration

  def change do
    create table(:oauth_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :account_id, :string
      add :access_token, :text, null: false
      add :refresh_token, :text
      add :expires_at, :utc_datetime
      add :scope, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:oauth_tokens, [:user_id, :provider, :account_id])
    create index(:oauth_tokens, [:user_id])
    create index(:oauth_tokens, [:provider])
  end
end

