defmodule PostMeetingApp.Repo.Migrations.CreateAutomations do
  use Ecto.Migration

  def change do
    create table(:automations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :social_network, :string, null: false
      add :instructions, :text, null: false
      add :example, :text

      timestamps(type: :utc_datetime)
    end

    create index(:automations, [:user_id])
    create index(:automations, [:social_network])
  end
end

