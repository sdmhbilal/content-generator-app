import Config

# Load .env file in dev/test environments before reading config
if config_env() in [:dev, :test] do
  Dotenv.load!()
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") == "true", do: [:inet6], else: []

  config :post_meeting_app, PostMeetingApp.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :post_meeting_app, PostMeetingAppWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
else
  # For dev/test, update OAuth config from .env file
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
end

