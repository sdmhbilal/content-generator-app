defmodule PostMeetingAppWeb.Router do
  use PostMeetingAppWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_auth do
    plug PostMeetingAppWeb.Plugs.RequireAuth
  end

  scope "/", PostMeetingAppWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/auth/google", AuthController, :request
    get "/auth/google/callback", AuthController, :callback
    get "/auth/linkedin", AuthController, :linkedin_request
    get "/auth/linkedin/callback", AuthController, :linkedin_callback
    get "/auth/facebook", AuthController, :facebook_request
    get "/auth/facebook/callback", AuthController, :facebook_callback
    delete "/auth/logout", AuthController, :logout
  end

  scope "/", PostMeetingAppWeb do
    pipe_through [:browser, :require_auth]

    live_session :default, root_layout: {PostMeetingAppWeb.Layouts, :root} do
      live "/dashboard", DashboardLive, :index
      live "/meetings/:id", MeetingLive, :show
      live "/settings", SettingsLive, :index
      live "/automations", AutomationsLive, :index
    end
  end
end

