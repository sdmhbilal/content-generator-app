defmodule PostMeetingApp.Finch do
  @moduledoc """
  Finch HTTP client for the application
  """

  @finch_name PostMeetingApp.Finch

  def child_spec(_args) do
    {Finch, name: @finch_name}
  end
end

