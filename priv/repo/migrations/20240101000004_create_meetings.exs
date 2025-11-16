defmodule PostMeetingApp.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :event_id, references(:events, on_delete: :nilify_all)
      add :title, :string, null: false
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime
      add :attendees, {:array, :string}, default: []
      add :platform, :string
      add :recall_bot_id, :string
      add :recall_status, :string, default: "pending"
      add :transcript_available, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:meetings, [:user_id])
    create index(:meetings, [:start_time])
    create index(:meetings, [:recall_bot_id])
    create index(:meetings, [:recall_status])
  end
end

