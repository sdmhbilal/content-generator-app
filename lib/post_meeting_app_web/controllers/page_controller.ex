defmodule PostMeetingAppWeb.PageController do
  use PostMeetingAppWeb, :controller

  def home(conn, _params) do
    user_id = get_session(conn, :user_id)

    if user_id do
      redirect(conn, to: "/dashboard")
    else
      conn
      |> put_layout(false)
      |> put_view(html: PostMeetingAppWeb.PageHTML)
      |> render(:home)
    end
  end
end

