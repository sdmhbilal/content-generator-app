defmodule PostMeetingApp.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias PostMeetingApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import PostMeetingApp.DataCase
      import PostMeetingApp.Factory
    end
  end

  setup tags do
    PostMeetingApp.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(PostMeetingApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
end

