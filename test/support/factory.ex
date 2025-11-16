defmodule PostMeetingApp.Factory do
  @moduledoc """
  Factory for creating test data
  """
  use ExMachina.Ecto, repo: PostMeetingApp.Repo

  def user_factory do
    %PostMeetingApp.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      name: "Test User",
      google_account_id: sequence(:google_id, &"google_#{&1}")
    }
  end

  def oauth_token_factory do
    %PostMeetingApp.Accounts.OAuthToken{
      provider: :google,
      account_id: sequence(:account_id, &"account_#{&1}"),
      access_token: "test_access_token",
      refresh_token: "test_refresh_token",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      user: build(:user)
    }
  end

  def event_factory do
    %PostMeetingApp.Calendars.Event{
      google_event_id: sequence(:event_id, &"event_#{&1}"),
      google_calendar_id: "calendar_1",
      title: "Test Meeting",
      start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
      end_time: DateTime.add(DateTime.utc_now(), 7200, :second),
      meeting_url: "https://zoom.us/j/123456",
      meeting_platform: "zoom",
      send_notetaker: false,
      user: build(:user)
    }
  end

  def meeting_factory do
    %PostMeetingApp.Meetings.Meeting{
      title: "Test Meeting",
      start_time: DateTime.add(DateTime.utc_now(), -3600, :second),
      end_time: DateTime.add(DateTime.utc_now(), -1800, :second),
      platform: "zoom",
      recall_status: "pending",
      transcript_available: false,
      user: build(:user)
    }
  end

  def transcript_factory do
    %PostMeetingApp.Meetings.Transcript{
      content: "This is a test transcript",
      recall_media_id: "media_123",
      recall_status: "completed",
      meeting: build(:meeting)
    }
  end

  def automation_factory do
    %PostMeetingApp.Automations.Automation{
      name: "Test Automation",
      social_network: "linkedin",
      instructions: "Generate a professional post",
      user: build(:user)
    }
  end

  def social_post_factory do
    %PostMeetingApp.Automations.SocialPost{
      content: "Test post content",
      social_network: "linkedin",
      posted: false,
      meeting: build(:meeting),
      automation: build(:automation)
    }
  end
end

