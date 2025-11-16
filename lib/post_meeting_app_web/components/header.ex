defmodule PostMeetingAppWeb.Components.Header do
  use PostMeetingAppWeb, :html

  attr :current_user, :any, required: true

  def header(assigns) do
    ~H"""
    <header class="bg-white shadow">
      <div class="container mx-auto px-4 py-4">
        <div class="flex justify-between items-center">
          <a href="/dashboard" class="text-xl font-bold text-blue-600">
            Post Meeting App
          </a>
          <nav class="flex items-center gap-4">
            <a href="/dashboard" class="text-gray-700 hover:text-blue-600">Dashboard</a>
            <a href="/automations" class="text-gray-700 hover:text-blue-600">Automations</a>
            <a href="/settings" class="text-gray-700 hover:text-blue-600">Settings</a>
            <span class="text-gray-600"><%= @current_user.email %></span>
            <a
              href="/auth/logout"
              class="text-gray-700 hover:text-blue-600 cursor-pointer"
              onclick="event.preventDefault(); const form = document.createElement('form'); form.method = 'POST'; form.action = '/auth/logout'; const method = document.createElement('input'); method.type = 'hidden'; method.name = '_method'; method.value = 'delete'; form.appendChild(method); const csrf = document.createElement('input'); csrf.type = 'hidden'; csrf.name = '_csrf_token'; csrf.value = document.querySelector('meta[name=csrf-token]')?.content || ''; form.appendChild(csrf); document.body.appendChild(form); form.submit(); return false;"
            >
              Logout
            </a>
          </nav>
        </div>
      </div>
    </header>
    """
  end
end

