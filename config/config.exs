import Config

config :post_meeting_app,
  ecto_repos: [PostMeetingApp.Repo]


config :post_meeting_app, PostMeetingApp.Repo,
  username: System.get_env("DATABASE_USER", "postgres"),
  password: System.get_env("DATABASE_PASS", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  database: System.get_env("DATABASE_NAME", "post_meeting_app_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :post_meeting_app, PostMeetingAppWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: PostMeetingAppWeb.ErrorHTML, json: PostMeetingAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PostMeetingApp.PubSub,
  live_view: [signing_salt: "post_meeting_app"]

config :post_meeting_app, PostMeetingAppWeb.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "k87PJOJG00dQsu2p3/0QixIS1G1NRnEqoFyIAx+J/onZIuvF0yjt5axYngpaRolf"

config :post_meeting_app, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, recall: 5, calendar: 5],
  repo: PostMeetingApp.Repo

config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [
      default_scope: "email profile https://www.googleapis.com/auth/calendar.readonly",
      access_type: "offline",
      prompt: "select_account consent",
      include_granted_scopes: true
    ]}
  ]

config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
  redirect_uri: System.get_env("GOOGLE_REDIRECT_URI", "http://localhost:4000/auth/google/callback")

config :post_meeting_app, :openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  api_url: "https://api.openai.com/v1"

config :post_meeting_app, :recall,
  api_key: System.get_env("RECALL_API_KEY") || "placeholder-api-key",
  api_url: System.get_env("RECALL_API_URL") || "https://us-west-2.recall.ai/api/v1"

config :post_meeting_app, :linkedin,
  client_id: System.get_env("LINKEDIN_CLIENT_ID"),
  client_secret: System.get_env("LINKEDIN_CLIENT_SECRET"),
  redirect_uri: System.get_env("LINKEDIN_REDIRECT_URI", "http://localhost:4000/auth/linkedin/callback")

config :post_meeting_app, :facebook,
  client_id: System.get_env("FACEBOOK_CLIENT_ID"),
  client_secret: System.get_env("FACEBOOK_CLIENT_SECRET"),
  redirect_uri: System.get_env("FACEBOOK_REDIRECT_URI", "http://localhost:4000/auth/facebook/callback")

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.19.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Load .env file - this is handled in Application.start/2
# but we configure the path here for dotenv
if Mix.env() in [:dev, :test] do
  config :dotenv, :env_file, ".env"
end


config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
