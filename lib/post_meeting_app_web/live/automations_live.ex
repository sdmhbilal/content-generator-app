defmodule PostMeetingAppWeb.AutomationsLive do
  use PostMeetingAppWeb, :live_view

  alias PostMeetingApp.Automations

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    automations = Automations.list_automations(user.id)

    {:ok,
     socket
     |> assign(:automations, automations)
     |> assign(:page_title, "Automations")
     |> assign(:show_form, false)}
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, :show_form, true)}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  @impl true
  def handle_event("create", %{"automation" => params}, socket) do
    user = socket.assigns.current_user

    case Automations.create_automation(Map.put(params, "user_id", user.id)) do
      {:ok, _automation} ->
        automations = Automations.list_automations(user.id)

        {:noreply,
         socket
         |> assign(:automations, automations)
         |> assign(:show_form, false)
         |> put_flash(:info, "Automation created")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create automation")}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    automation = Automations.get_automation!(id)
    user = socket.assigns.current_user

    if automation.user_id == user.id do
      Automations.delete_automation(automation)
      automations = Automations.list_automations(user.id)

      {:noreply,
       socket
       |> assign(:automations, automations)
       |> put_flash(:info, "Automation deleted")}
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <a href="/dashboard" class="text-blue-600 hover:underline">← Back to Dashboard</a>
      </div>

      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">Automations</h1>
        <%= unless @show_form do %>
          <button
            phx-click="show_form"
            class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
          >
            New Automation
          </button>
        <% end %>
      </div>

      <%= if @show_form do %>
        <div class="border rounded p-6 mb-6">
          <h2 class="text-xl font-semibold mb-4">Create Automation</h2>
          <form phx-submit="create">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium mb-2">Name</label>
                <input
                  type="text"
                  name="automation[name]"
                  class="border rounded px-3 py-2 w-full"
                  required
                />
              </div>
              <div>
                <label class="block text-sm font-medium mb-2">Social Network</label>
                <select name="automation[social_network]" class="border rounded px-3 py-2 w-full" required>
                  <option value="linkedin">LinkedIn</option>
                  <option value="facebook">Facebook</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium mb-2">Instructions</label>
                <textarea
                  name="automation[instructions]"
                  rows="4"
                  class="border rounded px-3 py-2 w-full"
                  required
                ></textarea>
                <p class="text-xs text-gray-500 mt-1">
                  Describe how you want the AI to generate posts for this automation
                </p>
              </div>
              <div>
                <label class="block text-sm font-medium mb-2">Example (optional)</label>
                <textarea
                  name="automation[example]"
                  rows="3"
                  class="border rounded px-3 py-2 w-full"
                ></textarea>
              </div>
              <div class="flex gap-2">
                <button
                  type="submit"
                  class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                >
                  Create
                </button>
                <button
                  type="button"
                  phx-click="hide_form"
                  class="bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700"
                >
                  Cancel
                </button>
              </div>
            </div>
          </form>
        </div>
      <% end %>

      <div class="space-y-4">
        <%= for automation <- @automations do %>
          <div class="border rounded p-4">
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <h3 class="font-semibold text-lg"><%= automation.name %></h3>
                <p class="text-sm text-gray-600">
                  <%= String.capitalize(automation.social_network) %>
                </p>
                <div class="mt-2">
                  <p class="text-sm font-medium">Instructions:</p>
                  <p class="text-sm text-gray-700"><%= automation.instructions %></p>
                </div>
                <%= if automation.example do %>
                  <div class="mt-2">
                    <p class="text-sm font-medium">Example:</p>
                    <p class="text-sm text-gray-700"><%= automation.example %></p>
                  </div>
                <% end %>
              </div>
              <button
                phx-click="delete"
                phx-value-id={automation.id}
                class="bg-red-600 text-white px-3 py-1 rounded hover:bg-red-700 text-sm"
              >
                Delete
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end

