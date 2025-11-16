defmodule PostMeetingAppWeb.DashboardLive do
  use PostMeetingAppWeb, :live_view

  alias PostMeetingApp.{Meetings, Calendars, Accounts}

  on_mount {PostMeetingAppWeb.Plugs.RequireAuth, :ensure_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    require Logger
    
    # Ensure current_user is assigned (should be from on_mount)
    user = socket.assigns[:current_user]
    
    if is_nil(user) do
      Logger.error("Dashboard mount: current_user is nil")
      {:ok,
       socket
       |> assign(:meetings, [])
       |> assign(:upcoming_events, [])
       |> assign(:past_events, [])
       |> assign(:syncing, false)
       |> assign(:page_title, "Dashboard")
       |> put_flash(:error, "Please log in to access the dashboard")}
    else
      if connected?(socket) do
        try do
          meetings = Meetings.list_meetings(user.id, past: true)
          # Get all events (past and future) - limit to last 30 days and next 365 days
          now = DateTime.utc_now()
          past_date = DateTime.add(now, -30, :day)
          future_date = DateTime.add(now, 365, :day)
          all_events = Calendars.list_events(user.id, start_time: past_date, end_time: future_date)
          
          # Split events into upcoming (future) and past
          {upcoming_events, past_events} = 
            Enum.split_with(all_events || [], fn event ->
              if event.start_time do
                DateTime.compare(event.start_time, now) == :gt
              else
                false
              end
            end)

          {:ok,
           socket
           |> assign(:meetings, meetings || [])
           |> assign(:upcoming_events, upcoming_events)
           |> assign(:past_events, past_events)
           |> assign(:syncing, false)
           |> assign(:page_title, "Dashboard")}
        rescue
          e ->
            Logger.error("Error loading dashboard data: #{inspect(e)}")
            Logger.error(Exception.format(:error, e, __STACKTRACE__))
            {:ok,
             socket
             |> assign(:meetings, [])
             |> assign(:upcoming_events, [])
             |> assign(:past_events, [])
             |> assign(:syncing, false)
             |> assign(:page_title, "Dashboard")
             |> put_flash(:error, "Error loading dashboard data. Please try refreshing the page.")}
        end
      else
        {:ok,
         socket
         |> assign(:meetings, [])
         |> assign(:upcoming_events, [])
         |> assign(:past_events, [])
         |> assign(:syncing, false)
         |> assign(:page_title, "Dashboard")}
      end
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("test_click", _params, socket) do
    require Logger
    Logger.info("TEST CLICK RECEIVED - Socket is working!")
    {:noreply, put_flash(socket, :info, "Socket is working! Test click received.")}
  end

  @impl true
  def handle_event("sync_calendars", _params, socket) do
    require Logger
    
    Logger.info("=" <> String.duplicate("=", 50))
    Logger.info("=== SYNC CALENDARS EVENT RECEIVED ===")
    Logger.info("Socket assigns keys: #{inspect(Map.keys(socket.assigns))}")
    Logger.info("=" <> String.duplicate("=", 50))
    
    user = socket.assigns[:current_user]
    
    if is_nil(user) do
      Logger.error("❌ Sync calendars: current_user is nil")
      Logger.error("Available assigns: #{inspect(Map.keys(socket.assigns))}")
      {:noreply,
       socket
       |> put_flash(:error, "Please log in to sync calendars")}
    else
      pid = self()
      
      Logger.info("✅ Sync calendars button clicked for user #{user.id} (PID: #{inspect(pid)})")
      
      # Immediately update UI to show syncing state
      socket = socket
        |> assign(:syncing, true)
        |> put_flash(:info, "Starting calendar sync...")
      
      # Check if user has Google OAuth token
      try do
        Logger.info("🔍 Checking OAuth tokens for user #{user.id}...")
        tokens = Accounts.list_oauth_tokens(user.id)
        google_tokens = Enum.filter(tokens, &(&1.provider == :google))
        
        Logger.info("📊 Found #{length(tokens)} total tokens, #{length(google_tokens)} Google tokens")
        
        if Enum.empty?(google_tokens) do
          Logger.warning("⚠️ No Google OAuth token found for user #{user.id}")
          Logger.warning("All tokens: #{inspect(Enum.map(tokens, &%{provider: &1.provider, id: &1.id}))}")
          {:noreply,
           socket
           |> assign(:syncing, false)
           |> put_flash(:error, "No Google account connected. Please log in with Google first. Go to Settings to connect your Google account.")}
        else
          token = List.first(google_tokens)
          # Check if token has calendar scope
          has_calendar_scope = token.scope && String.contains?(token.scope, "calendar")
          
          if !has_calendar_scope do
            Logger.warning("⚠️ Google token missing calendar scope. Current scope: #{token.scope}")
            {:noreply,
             socket
             |> assign(:syncing, false)
             |> put_flash(:error, "⚠️ Your Google account needs Calendar permissions! Click the green 'Reconnect Google' button above, then grant Calendar access when Google asks. This will allow the app to read your calendar events.")}
          else
            Logger.info("✅ Found Google token: ID=#{token.id}, Has access_token=#{!is_nil(token.access_token)}, Expires_at=#{inspect(token.expires_at)}, Scope=#{token.scope}")
            Logger.info("🚀 Starting calendar sync for user #{user.id}...")
            
            # Sync calendars in the background
            Task.start(fn ->
              try do
                Logger.info("📅 Background task started, calling Calendars.sync_calendars(#{user.id})")
                result = Calendars.sync_calendars(user.id)
                Logger.info("📊 Sync result: #{inspect(result)}")
                
                case result do
                  :ok ->
                    Logger.info("✅ Calendar sync completed successfully for user #{user.id}")
                    send(pid, {:sync_complete, user.id})
                  
                  {:error, :no_google_token} ->
                    Logger.error("❌ No Google token found during sync for user #{user.id}")
                    send(pid, {:sync_error, "No Google OAuth token found. Please reconnect your Google account."})
                  
                  {:error, :token_expired} ->
                    Logger.error("⏰ Google token expired for user #{user.id}")
                    send(pid, {:sync_error, "Google token expired. Please reconnect your Google account."})
                  
                  {:error, :sync_failed} ->
                    Logger.error("❌ All calendars failed to sync for user #{user.id}")
                    send(pid, {:sync_error, "All calendars failed to sync. Please check your Google account permissions and try again."})
                  
                  {:error, reason} ->
                    Logger.error("❌ Calendar sync failed for user #{user.id}: #{inspect(reason)}")
                    send(pid, {:sync_error, "Sync failed: #{inspect(reason)}"})
                end
              rescue
                e ->
                  Logger.error("💥 Calendar sync error for user #{user.id}: #{inspect(e)}")
                  Logger.error(Exception.format(:error, e, __STACKTRACE__))
                  send(pid, {:sync_error, "Unexpected error: #{Exception.message(e)}"})
              catch
                :exit, reason ->
                  Logger.error("💥 Calendar sync exit for user #{user.id}: #{inspect(reason)}")
                  send(pid, {:sync_error, "Sync process exited unexpectedly"})
                :throw, reason ->
                  Logger.error("💥 Calendar sync throw for user #{user.id}: #{inspect(reason)}")
                  send(pid, {:sync_error, "Unexpected error during sync"})
              end
            end)

            {:noreply, socket}
          end
        end
      rescue
        e ->
          Logger.error("💥 Error checking OAuth tokens: #{inspect(e)}")
          Logger.error(Exception.format(:error, e, __STACKTRACE__))
          {:noreply,
           socket
           |> assign(:syncing, false)
           |> put_flash(:error, "Error starting sync: #{Exception.message(e)}")}
      end
    end
  end

  @impl true
  def handle_info({:sync_complete, user_id}, socket) do
    require Logger
    user = socket.assigns[:current_user]
    
    if is_nil(user) || user.id != user_id do
      {:noreply, socket}
    else
      try do
        # Reload events after sync - include past events (last 30 days) and future events (next 365 days)
        now = DateTime.utc_now()
        past_date = DateTime.add(now, -30, :day)
        future_date = DateTime.add(now, 365, :day)
        all_events = Calendars.list_events(user_id, start_time: past_date, end_time: future_date)
        meetings = Meetings.list_meetings(user_id, past: true)
        
        # Split events into upcoming (future) and past
        {upcoming_events, past_events} = 
          Enum.split_with(all_events || [], fn event ->
            if event.start_time do
              DateTime.compare(event.start_time, now) == :gt
            else
              false
            end
          end)

        {:noreply,
         socket
         |> assign(:upcoming_events, upcoming_events)
         |> assign(:past_events, past_events)
         |> assign(:meetings, meetings || [])
         |> assign(:syncing, false)
         |> put_flash(:info, "Calendar sync completed!")}
      rescue
        e ->
          Logger.error("Error reloading data after sync: #{inspect(e)}")
          {:noreply,
           socket
           |> assign(:syncing, false)
           |> put_flash(:info, "Calendar sync completed, but there was an error reloading data.")}
      end
    end
  end

  @impl true
  def handle_info({:sync_error, error}, socket) do
    {:noreply,
     socket
     |> assign(:syncing, false)
     |> put_flash(:error, "Calendar sync failed: #{error}")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_notetaker", %{"event_id" => event_id, "enabled" => enabled_str}, socket) do
    require Logger
    
    event = Calendars.get_event!(event_id)
    
    # Convert string "true"/"false" to boolean
    enabled_bool = enabled_str == "true"
    
    Logger.info("Toggling notetaker for event #{event_id}: #{event.send_notetaker} -> #{enabled_bool}")
    
    case Calendars.toggle_notetaker(event, enabled_bool) do
      {:ok, updated_event} ->
        # Reload events to get updated state
        user = socket.assigns[:current_user]
        now = DateTime.utc_now()
        past_date = DateTime.add(now, -30, :day)
        future_date = DateTime.add(now, 365, :day)
        all_events = Calendars.list_events(user.id, start_time: past_date, end_time: future_date)
        
        # Split events into upcoming (future) and past
        {upcoming_events, past_events} = 
          Enum.split_with(all_events || [], fn event ->
            if event.start_time do
              DateTime.compare(event.start_time, now) == :gt
            else
              false
            end
          end)
        
        {:noreply,
         socket
         |> assign(:upcoming_events, upcoming_events)
         |> assign(:past_events, past_events)
         |> put_flash(:info, if(enabled_bool, do: "Notetaker enabled for this meeting", else: "Notetaker disabled for this meeting"))}

      {:error, changeset} ->
        Logger.error("Failed to toggle notetaker: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to update setting")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold">Dashboard</h1>
        <div class="flex gap-2">
          <a
            href="/auth/google?scope=email%20profile%20https://www.googleapis.com/auth/calendar.readonly&prompt=consent"
            class="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700 text-sm no-underline inline-flex items-center"
            title="Reconnect Google to grant Calendar permissions"
          >
            🔄 Reconnect Google
          </a>
          <button
            type="button"
            phx-click="sync_calendars"
            phx-disable-with="Syncing..."
            disabled={@syncing}
            class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <%= if @syncing do %>
              <span class="flex items-center">
                <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Syncing...
              </span>
            <% else %>
              Sync Calendars
            <% end %>
          </button>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 class="text-2xl font-semibold mb-4">Upcoming Events</h2>
          <div class="space-y-4">
            <%= if Enum.empty?(@upcoming_events) do %>
              <p class="text-gray-500 text-sm">No upcoming events. Click "Sync Calendars" to load your calendar events.</p>
            <% else %>
              <%= for event <- @upcoming_events do %>
                <div class="border rounded p-4">
                  <div class="flex justify-between items-start">
                    <div>
                      <h3 class="font-semibold"><%= event.title %></h3>
                      <p class="text-sm text-gray-600">
                        <%= if event.start_time do %>
                          <%= Calendar.strftime(event.start_time, "%B %d, %Y at %I:%M %p") %>
                        <% else %>
                          Date TBD
                        <% end %>
                      </p>
                      <%= if event.meeting_platform do %>
                        <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                          <%= String.capitalize(event.meeting_platform) %>
                        </span>
                      <% end %>
                    </div>
                    <%= if event.meeting_url do %>
                      <%= if event.start_time && DateTime.compare(event.start_time, DateTime.utc_now()) == :gt do %>
                        <label class="flex items-center cursor-pointer">
                          <input
                            type="checkbox"
                            checked={event.send_notetaker}
                            phx-click="toggle_notetaker"
                            phx-value-event_id={event.id}
                            phx-value-enabled={to_string(!event.send_notetaker)}
                            class="mr-2 cursor-pointer"
                          />
                          <span class="text-sm">Send notetaker</span>
                        </label>
                      <% end %>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>

        <div>
          <h2 class="text-2xl font-semibold mb-4">Past Events</h2>
          <div class="space-y-4">
            <%= if Enum.empty?(@past_events) do %>
              <p class="text-gray-500 text-sm">No past events.</p>
            <% else %>
              <%= for event <- @past_events do %>
                <div class="border rounded p-4">
                  <%= if event.meeting && event.meeting.transcript do %>
                    <a href={"/meetings/#{event.meeting.id}"} class="block">
                      <h3 class="font-semibold hover:text-blue-600"><%= event.title %></h3>
                      <p class="text-sm text-gray-600">
                        <%= if event.start_time do %>
                          <%= Calendar.strftime(event.start_time, "%B %d, %Y at %I:%M %p") %>
                        <% else %>
                          Date TBD
                        <% end %>
                      </p>
                      <div class="flex gap-2 mt-2">
                        <%= if event.meeting_platform do %>
                          <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                            <%= String.capitalize(event.meeting_platform) %>
                          </span>
                        <% end %>
                        <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded">
                          Transcript Available
                        </span>
                      </div>
                    </a>
                  <% else %>
                    <div>
                      <h3 class="font-semibold"><%= event.title %></h3>
                      <p class="text-sm text-gray-600">
                        <%= if event.start_time do %>
                          <%= Calendar.strftime(event.start_time, "%B %d, %Y at %I:%M %p") %>
                        <% else %>
                          Date TBD
                        <% end %>
                      </p>
                      <div class="flex gap-2 mt-2">
                        <%= if event.meeting_platform do %>
                          <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                            <%= String.capitalize(event.meeting_platform) %>
                          </span>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

