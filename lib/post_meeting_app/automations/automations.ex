defmodule PostMeetingApp.Automations do
  import Ecto.Query, warn: false
  alias PostMeetingApp.Repo
  alias PostMeetingApp.Automations.{Automation, SocialPost}

  def list_automations(user_id) do
    from(a in Automation, where: a.user_id == ^user_id)
    |> Repo.all()
  end

  def get_automation!(id), do: Repo.get!(Automation, id)

  def create_automation(attrs \\ %{}) do
    %Automation{}
    |> Automation.changeset(attrs)
    |> Repo.insert()
  end

  def update_automation(%Automation{} = automation, attrs) do
    automation
    |> Automation.changeset(attrs)
    |> Repo.update()
  end

  def delete_automation(%Automation{} = automation) do
    Repo.delete(automation)
  end

  def create_social_post(attrs \\ %{}) do
    %SocialPost{}
    |> SocialPost.changeset(attrs)
    |> Repo.insert()
  end

  def get_social_post!(id), do: Repo.get!(SocialPost, id)

  def update_social_post(%SocialPost{} = post, attrs) do
    post
    |> SocialPost.changeset(attrs)
    |> Repo.update()
  end

  def mark_posted(%SocialPost{} = post, external_post_id) do
    update_social_post(post, %{
      posted: true,
      posted_at: DateTime.utc_now(),
      external_post_id: external_post_id
    })
  end
end

