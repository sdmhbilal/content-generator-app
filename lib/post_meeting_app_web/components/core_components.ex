defmodule PostMeetingAppWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component

  @doc """
  Renders a flash message.
  """
  attr :kind, :string, required: true
  attr :message, :string, required: true
  attr :rest, :global

  def flash(assigns) do
    ~H"""
    <div
      class={[
        "rounded-lg p-4 mb-4",
        @kind == "info" && "bg-blue-100 text-blue-800",
        @kind == "error" && "bg-red-100 text-red-800"
      ]}
      {@rest}
    >
      <%= @message %>
    </div>
    """
  end

  @doc """
  Renders a button.
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={["px-4 py-2 rounded font-medium", @class]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end
end

