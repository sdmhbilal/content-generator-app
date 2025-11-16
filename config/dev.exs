import Config

config :post_meeting_app, PostMeetingApp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "post_meeting_app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :post_meeting_app, PostMeetingAppWeb.Endpoint,
  code_reloader: true,
  check_origin: false,
  debug_errors: true,
   http: [port: 4000], 
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

config :post_meeting_app, PostMeetingAppWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/post_meeting_app_web/(controllers|live|components|templates)/.*(ex|heex)$"
    ]
  ]
