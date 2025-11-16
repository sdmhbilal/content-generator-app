import Config

config :post_meeting_app, PostMeetingApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "post_meeting_app_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :post_meeting_app, PostMeetingAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "k87PJOJG00dQsu2p3/0QixIS1G1NRnEqoFyIAx+J/onZIuvF0yjt5axYngpaRolf",
  server: false

config :post_meeting_app, Oban, testing: :inline

config :phoenix, :plug_init_mode, :runtime

