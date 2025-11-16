defmodule PostMeetingAppWeb.MeetingLive do
  use PostMeetingAppWeb, :live_view

  alias PostMeetingApp.{Meetings, Social}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Meeting Details")}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    meeting = Meetings.get_meeting!(id)
    user = socket.assigns.current_user

    if meeting.user_id == user.id do
      {:noreply,
       socket
       |> assign(:meeting, meeting)
       |> assign(:page_title, meeting.title)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Meeting not found")
       |> push_navigate(to: "/dashboard")}
    end
  end

  @impl true
  def handle_event("copy", %{"content" => _content}, socket) do
    {:noreply, put_flash(socket, :info, "Copied to clipboard")}
  end

  @impl true
  def handle_event("post", %{"post_id" => post_id}, socket) do
    user = socket.assigns.current_user
    meeting = socket.assigns.meeting
    post = PostMeetingApp.Automations.get_social_post!(post_id)

    result =
      case post.social_network do
        "linkedin" -> Social.post_to_linkedin(user.id, post_id)
        "facebook" -> Social.post_to_facebook(user.id, post_id)
        _ -> {:error, :unknown_network}
      end

    case result do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Posted to #{String.capitalize(post.social_network)}")
         |> push_navigate(to: "/meetings/#{meeting.id}")}

      {:error, :no_token} ->
        {:noreply,
         put_flash(socket, :error, "Please connect your #{String.capitalize(post.social_network)} account in settings")}

      {:error, :token_expired} ->
        {:noreply,
         put_flash(socket, :error, "Your #{String.capitalize(post.social_network)} connection has expired. Please reconnect in settings")}

      {:error, {:http_error, 403, message}} ->
        error_msg = 
          if String.contains?(message, "partnerApiPostsExternal.CREATE") do
            "LinkedIn Posts API permission not approved. Please request 'Marketing Developer Platform' and 'Posts API' access in your LinkedIn Developer Portal, then reconnect your account."
          else
            "LinkedIn permission denied: #{message}. Please check your app permissions and reconnect your account."
          end
        {:noreply, put_flash(socket, :error, error_msg)}

      {:error, {:http_error, status, message}} ->
        {:noreply, put_flash(socket, :error, "Failed to post: #{message}")}

      {:error, {:timeout, _message}} ->
        {:noreply, put_flash(socket, :error, "Request timed out. Please try again.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to post. Check logs for details.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-6">
        <a href="/dashboard" class="text-blue-600 hover:underline">← Back to Dashboard</a>
      </div>

      <div class="mb-6">
        <h1 class="text-3xl font-bold mb-2"><%= @meeting.title %></h1>
        <p class="text-gray-600">
          <%= Calendar.strftime(@meeting.start_time, "%B %d, %Y at %I:%M %p") %>
        </p>
        <%= if @meeting.platform do %>
          <span class="text-sm bg-blue-100 text-blue-800 px-2 py-1 rounded">
            <%= String.capitalize(@meeting.platform) %>
          </span>
        <% end %>
        <%= if @meeting.attendees && length(@meeting.attendees) > 0 do %>
          <p class="text-sm text-gray-600 mt-2">
            Attendees: <%= Enum.join(@meeting.attendees, ", ") %>
          </p>
        <% end %>
      </div>

      <%= if @meeting.transcript do %>
        <div class="mb-6">
          <h2 class="text-2xl font-semibold mb-4">Transcript</h2>
          <div class="border rounded p-4 bg-gray-50">
            <pre class="whitespace-pre-wrap text-sm"><%= @meeting.transcript.content %></pre>
          </div>
        </div>
      <% end %>

      <%= if @meeting.follow_up_email do %>
        <div class="mb-6">
          <h2 class="text-2xl font-semibold mb-4">Follow-up Email</h2>
          <div class="border rounded p-4 bg-gray-50">
            <p class="font-semibold mb-2">Subject: <%= @meeting.follow_up_email.subject %></p>
            <pre class="whitespace-pre-wrap text-sm"><%= @meeting.follow_up_email.content %></pre>
            <button
              phx-click="copy"
              phx-value-content={@meeting.follow_up_email.content}
              class="mt-2 bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700"
            >
              Copy
            </button>
          </div>
        </div>
      <% end %>

      <%= if @meeting.social_posts && length(@meeting.social_posts) > 0 do %>
        <div class="mb-6">
          <h2 class="text-2xl font-semibold mb-4">Social Media Posts</h2>
          <div class="space-y-4">
            <%= for post <- @meeting.social_posts do %>
              <div class="border rounded p-4">
                <div class="flex justify-between items-start mb-2">
                  <span class="text-sm font-semibold text-gray-600">
                    <%= String.capitalize(post.social_network) %>
                  </span>
                  <%= if post.posted do %>
                    <span class="text-xs bg-green-100 text-green-800 px-2 py-1 rounded">
                      Posted
                    </span>
                  <% end %>
                </div>
                <pre class="whitespace-pre-wrap text-sm mb-2"><%= post.content %></pre>
                <div class="flex gap-2">
                  <button
                    phx-click="copy"
                    phx-value-content={post.content}
                    class="bg-gray-600 text-white px-4 py-2 rounded hover:bg-gray-700"
                  >
                    Copy
                  </button>
                  <%= unless post.posted do %>
                    <button
                      phx-click="post"
                      phx-value-post_id={post.id}
                      class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                    >
                      Post to <%= String.capitalize(post.social_network) %>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end

