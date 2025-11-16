defmodule PostMeetingApp.Repo.Migrations.CreateUserSettings do
  use Ecto.Migration

  def change do
    create table(:user_settings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :minutes_before_meeting, :integer, default: 5

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_settings, [:user_id])
  end
end

