defmodule PostMeetingApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PostMeetingApp.Repo,
      {Phoenix.PubSub, name: PostMeetingApp.PubSub},

      # FIX: Proper Finch child spec
      {Finch, name: PostMeetingApp.Finch},

      PostMeetingAppWeb.Endpoint,

      # Oban
      {Oban, Application.fetch_env!(:post_meeting_app, Oban)}
    ]

    opts = [strategy: :one_for_one, name: PostMeetingApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PostMeetingAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

