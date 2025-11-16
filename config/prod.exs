import Config

config :post_meeting_app, PostMeetingApp.Repo,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  hostname: System.get_env("DATABASE_HOST"),
  database: System.get_env("DATABASE_NAME"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :post_meeting_app, PostMeetingAppWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  url: [host: System.get_env("HOST"), scheme: "https", port: 443]

config :post_meeting_app, Oban,
  queues: [default: 10, recall: 5, calendar: 5]

