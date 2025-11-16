defmodule PostMeetingApp.Repo.Migrations.CreateFollowUpEmails do
  use Ecto.Migration

  def change do
    create table(:follow_up_emails) do
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :subject, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:follow_up_emails, [:meeting_id])
  end
end

