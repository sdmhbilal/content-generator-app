defmodule PostMeetingAppWeb.PageHTML do
  use PostMeetingAppWeb, :html

  embed_templates "controllers/page_html/*"
  
  def home(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={get_csrf_token()} />
        <title>Post Meeting App</title>
        <link phx-track-static rel="stylesheet" href="/assets/app.css" />
        <script defer phx-track-static type="text/javascript" src="/assets/app.js"></script>
      </head>
      <body>
        <div class="min-h-screen flex items-center justify-center bg-gray-50">
          <div class="max-w-md w-full space-y-8 p-8">
            <div>
              <h1 class="text-3xl font-bold text-center">Post Meeting App</h1>
              <p class="mt-2 text-center text-gray-600">
                Generate social media content from your meeting transcripts
              </p>
            </div>
            <div>
              <a
                href="/auth/google"
                class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Sign in with Google
              </a>
            </div>
          </div>
        </div>
      </body>
    </html>
    """
  end
end

