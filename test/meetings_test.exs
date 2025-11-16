defmodule PostMeetingApp.MeetingsTest do
  use PostMeetingApp.DataCase

  alias PostMeetingApp.Meetings

  describe "meetings" do
    test "create_meeting/1 creates meeting" do
      user = insert(:user)

      attrs = %{
        user_id: user.id,
        title: "Test Meeting",
        start_time: DateTime.utc_now()
      }

      assert {:ok, meeting} = Meetings.create_meeting(attrs)
      assert meeting.title == "Test Meeting"
    end

    test "create_transcript/2 creates transcript" do
      meeting = insert(:meeting)

      attrs = %{
        content: "Test transcript content",
        recall_media_id: "media_123"
      }

      assert {:ok, transcript} = Meetings.create_transcript(meeting.id, attrs)
      assert transcript.content == "Test transcript content"

      updated_meeting = Meetings.get_meeting!(meeting.id)
      assert updated_meeting.transcript_available == true
    end
  end
end

