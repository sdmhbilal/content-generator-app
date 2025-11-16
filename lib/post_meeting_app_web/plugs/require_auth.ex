defmodule PostMeetingAppWeb.Plugs.RequireAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias PostMeetingApp.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      user = Accounts.get_user!(user_id)
      assign(conn, :current_user, user)
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: "/")
      |> halt()
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    user_id = Map.get(session, "user_id")

    if user_id do
      user = Accounts.get_user!(user_id)
      {:cont, Phoenix.Component.assign(socket, :current_user, user)}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end
end

