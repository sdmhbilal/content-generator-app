defmodule PostMeetingApp.Recall.Poller do
  @moduledoc """
  Oban worker to poll Recall.ai bot status
  """

  use Oban.Worker, queue: :recall, max_attempts: 10

  alias PostMeetingApp.Recall
  alias PostMeetingApp.Meetings

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"bot_id" => bot_id, "meeting_id" => meeting_id}}) do
    require Logger
    
    Logger.info("[Recall.Poller] Polling bot status for bot_id: #{bot_id}, meeting_id: #{meeting_id}")
    
    case Recall.poll_bot_status(bot_id) do
      {:ok, "completed"} ->
        Logger.info("[Recall.Poller] Bot #{bot_id} completed successfully")
        :ok

      {:ok, status} when status in ["recording", "processing"] ->
        # Reschedule polling
        Logger.info("[Recall.Poller] Bot #{bot_id} status: #{status}, rescheduling poll in 180 seconds")
        schedule_next_poll(bot_id, meeting_id)
        :ok

      {:ok, "failed"} ->
        Logger.error("[Recall.Poller] Bot #{bot_id} failed")
        meeting = Meetings.get_meeting!(meeting_id)
        Meetings.update_meeting(meeting, %{recall_status: "failed"})
        :ok

      {:ok, unexpected_status} ->
        # Handle any other status by rescheduling
        Logger.warning("[Recall.Poller] Unexpected status '#{unexpected_status}' for bot #{bot_id}, rescheduling")
        schedule_next_poll(bot_id, meeting_id)
        :ok

      {:error, reason} ->
        # Retry on error
        Logger.error("[Recall.Poller] Error polling bot #{bot_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp schedule_next_poll(bot_id, meeting_id) do
    %{
      bot_id: bot_id,
      meeting_id: meeting_id
    }
    |> new(schedule_in: 180)
    |> Oban.insert()
  end
end

