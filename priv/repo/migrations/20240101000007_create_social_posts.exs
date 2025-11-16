defmodule PostMeetingApp.Repo.Migrations.CreateSocialPosts do
  use Ecto.Migration

  def change do
    create table(:social_posts) do
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :automation_id, references(:automations, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :social_network, :string, null: false
      add :posted, :boolean, default: false
      add :posted_at, :utc_datetime
      add :external_post_id, :string

      timestamps(type: :utc_datetime)
    end

    create index(:social_posts, [:meeting_id])
    create index(:social_posts, [:automation_id])
    create index(:social_posts, [:posted])
  end
end

