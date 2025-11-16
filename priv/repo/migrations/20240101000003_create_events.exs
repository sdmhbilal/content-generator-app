defmodule PostMeetingApp.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :google_event_id, :string, null: false
      add :google_calendar_id, :string
      add :title, :string, null: false
      add :description, :text
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :meeting_url, :string
      add :meeting_platform, :string
      add :attendees, {:array, :string}, default: []
      add :send_notetaker, :boolean, default: false
      add :synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:events, [:user_id, :google_event_id, :google_calendar_id])
    create index(:events, [:user_id])
    create index(:events, [:start_time])
  end
end

