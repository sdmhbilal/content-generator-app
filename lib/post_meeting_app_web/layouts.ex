defmodule PostMeetingAppWeb.Layouts do
  use PostMeetingAppWeb, :html

  embed_templates "layouts/*"
  
  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title><%= assigns[:page_title] || "Post Meeting App" %> · Post Meeting App</title>
        <link phx-track-static rel="stylesheet" href="/assets/app.css" />
        <script defer phx-track-static type="text/javascript" src="/assets/app.js"></script>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end
  
  def app(assigns) do
    ~H"""
    <PostMeetingAppWeb.Components.Header.header current_user={@current_user} />
    <main class="min-h-screen bg-gray-50">
      <%= @inner_content %>
    </main>
    """
  end
end

