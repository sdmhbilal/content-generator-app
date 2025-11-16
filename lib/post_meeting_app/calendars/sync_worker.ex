defmodule PostMeetingApp.Calendars.SyncWorker do
  @moduledoc """
  Oban worker to sync Google calendars
  """

  use Oban.Worker, queue: :calendar, max_attempts: 3

  alias PostMeetingApp.Calendars

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    Calendars.sync_calendars(user_id)
    :ok
  end
end

