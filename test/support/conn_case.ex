defmodule PostMeetingAppWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Phoenix.ConnTest
      import PostMeetingAppWeb.ConnCase
      import PostMeetingApp.Factory
      alias PostMeetingAppWeb.Router.Helpers, as: Routes
    end
  end

  setup tags do
    PostMeetingApp.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

