defmodule PostMeetingApp.Repo do
  use Ecto.Repo,
    otp_app: :post_meeting_app,
    adapter: Ecto.Adapters.Postgres
end

