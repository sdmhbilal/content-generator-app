// assets/js/app.js
import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import "../css/app.css"

// Wait for DOM to be ready before connecting
function connect() {
  let csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

  if (!csrfToken) {
    console.error("CSRF token not found. LiveView may not work properly.")
  }

  let liveSocket = new LiveSocket("/live", Socket, {
    params: { _csrf_token: csrfToken }
  })

  // Connect the socket
  liveSocket.connect()

  // Log connection events for debugging
  liveSocket.onOpen(() => {
    console.log("✅ LiveView socket connected")
  })

  liveSocket.onError((error) => {
    console.error("❌ LiveView socket error:", error)
  })

  liveSocket.onClose((event) => {
    console.warn("⚠️ LiveView socket closed:", event)
  })

  // Expose liveSocket to window for debugging in browser console
  window.liveSocket = liveSocket
}

// Connect when DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", connect)
} else {
  connect()
}
