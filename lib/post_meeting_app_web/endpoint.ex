defmodule PostMeetingAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :post_meeting_app

  @session_options [
    store: :cookie,
    key: "_post_meeting_app_key",
    signing_salt: "post_meeting_app_session"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  
  # Serve static files from priv/static
  plug Plug.Static,
    at: "/",
    from: :post_meeting_app,
    gzip: false
  
  plug PostMeetingAppWeb.Router
end

