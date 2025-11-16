defmodule PostMeetingAppWeb.ErrorHTML do
  use PostMeetingAppWeb, :html

  def render("404.html", assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50">
      <div class="text-center">
        <h1 class="text-4xl font-bold text-gray-900">404</h1>
        <p class="mt-2 text-gray-600">Page not found</p>
      </div>
    </div>
    """
  end

  def render("500.html", assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50">
      <div class="text-center">
        <h1 class="text-4xl font-bold text-gray-900">500</h1>
        <p class="mt-2 text-gray-600">Internal server error</p>
      </div>
    </div>
    """
  end
end

