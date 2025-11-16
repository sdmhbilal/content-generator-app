defmodule PostMeetingAppWeb.SettingsLive do
  use PostMeetingAppWeb, :live_view

  alias PostMeetingApp.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_settings(socket)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, load_settings(socket)}
  end

  defp load_settings(socket) do
    user = socket.assigns.current_user
    settings = Accounts.get_settings(user.id) || %{minutes_before_meeting: 5}
    tokens = Accounts.list_oauth_tokens(user.id)

    linkedin_connected = Enum.any?(tokens, &(&1.provider == :linkedin))
    facebook_connected = Enum.any?(tokens, &(&1.provider == :facebook))

    socket
    |> assign(:settings, settings)
    |> assign(:linkedin_connected, linkedin_connected)
    |> assign(:facebook_connected, facebook_connected)
    |> assign(:page_title, "Settings")
  end

  @impl true
  def handle_event("update_settings", %{"settings" => settings_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_settings(user.id, settings_params) do
      {:ok, settings} ->
        {:noreply,
         socket
         |> assign(:settings, settings)
         |> put_flash(:info, "Settings updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update settings")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <a href="/dashboard" class="text-blue-600 hover:underline">← Back to Dashboard</a>
      </div>

      <h1 class="text-3xl font-bold mb-6">Settings</h1>

      <div class="max-w-2xl space-y-6">
        <div class="border rounded p-6">
          <h2 class="text-xl font-semibold mb-4">Meeting Settings</h2>
          <form phx-submit="update_settings">
            <div class="mb-4">
              <label class="block text-sm font-medium mb-2">
                Minutes before meeting to send notetaker
              </label>
              <input
                type="number"
                name="settings[minutes_before_meeting]"
                value={@settings.minutes_before_meeting}
                min="1"
                max="60"
                class="border rounded px-3 py-2 w-full"
                required
              />
            </div>
            <button
              type="submit"
              class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
              Save Settings
            </button>
          </form>
        </div>

        <div class="border rounded p-6">
          <h2 class="text-xl font-semibold mb-4">Social Media Connections</h2>
          <div class="space-y-4">
            <div class="flex justify-between items-center">
              <div>
                <h3 class="font-semibold">LinkedIn</h3>
                <p class="text-sm text-gray-600">Connect your LinkedIn account to post directly</p>
              </div>
              <%= if @linkedin_connected do %>
                <span class="text-sm text-green-600">Connected</span>
              <% else %>
                <a
                  href="/auth/linkedin"
                  class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                >
                  Connect LinkedIn
                </a>
              <% end %>
            </div>

            <div class="flex justify-between items-center">
              <div>
                <h3 class="font-semibold">Facebook</h3>
                <p class="text-sm text-gray-600">Connect your Facebook account to post directly</p>
              </div>
              <%= if @facebook_connected do %>
                <span class="text-sm text-green-600">Connected</span>
              <% else %>
                <a
                  href="/auth/facebook"
                  class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                >
                  Connect Facebook
                </a>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

