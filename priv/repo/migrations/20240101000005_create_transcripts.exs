defmodule PostMeetingApp.Repo.Migrations.CreateTranscripts do
  use Ecto.Migration

  def change do
    create table(:transcripts) do
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :recall_media_id, :string
      add :recall_status, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:transcripts, [:meeting_id])
    create index(:transcripts, [:recall_media_id])
  end
end

