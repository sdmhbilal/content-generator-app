defmodule PostMeetingAppWeb.ErrorJSON do
  def error(%{status: status}) do
    %{error: status}
  end
end

