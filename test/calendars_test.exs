defmodule PostMeetingApp.CalendarsTest do
  use PostMeetingApp.DataCase

  alias PostMeetingApp.Calendars

  describe "events" do
    test "create_event/1 creates event" do
      user = insert(:user)

      attrs = %{
        user_id: user.id,
        google_event_id: "event_123",
        google_calendar_id: "cal_123",
        title: "Test Event",
        start_time: DateTime.utc_now(),
        end_time: DateTime.add(DateTime.utc_now(), 3600, :second)
      }

      assert {:ok, event} = Calendars.create_event(attrs)
      assert event.title == "Test Event"
    end

    test "toggle_notetaker/2 updates send_notetaker" do
      event = insert(:event)

      assert {:ok, updated} = Calendars.toggle_notetaker(event, true)
      assert updated.send_notetaker == true
    end
  end
end

