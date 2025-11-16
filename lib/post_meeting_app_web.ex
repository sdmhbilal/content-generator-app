defmodule PostMeetingAppWeb do
  def controller do
    quote do
      use Phoenix.Controller,
        namespace: PostMeetingAppWeb,
        formats: [:html, :json]

      import Plug.Conn
      import PostMeetingAppWeb.Gettext
      alias PostMeetingAppWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import PostMeetingAppWeb.Gettext
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {PostMeetingAppWeb.Layouts, :app}

      on_mount {PostMeetingAppWeb.Plugs.RequireAuth, :ensure_authenticated}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import PostMeetingAppWeb.CoreComponents
      import PostMeetingAppWeb.Gettext

      alias PostMeetingAppWeb.Router.Helpers, as: Routes
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

