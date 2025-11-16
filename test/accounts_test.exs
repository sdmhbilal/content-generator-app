defmodule PostMeetingApp.AccountsTest do
  use PostMeetingApp.DataCase

  alias PostMeetingApp.Accounts

  describe "users" do
    alias PostMeetingApp.Accounts.User

    test "create_user/1 creates user with valid data" do
      attrs = %{email: "test@example.com", name: "Test User"}

      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert user.email == "test@example.com"
      assert user.name == "Test User"
    end

    test "create_user/1 creates default settings" do
      attrs = %{email: "test@example.com"}

      assert {:ok, user} = Accounts.create_user(attrs)
      settings = Accounts.get_settings(user.id)
      assert settings.minutes_before_meeting == 5
    end

    test "get_user_by_email/1 returns user" do
      user = insert(:user)
      assert Accounts.get_user_by_email(user.email).id == user.id
    end

    test "update_settings/2 updates settings" do
      user = insert(:user)
      assert {:ok, settings} = Accounts.update_settings(user.id, %{minutes_before_meeting: 10})
      assert settings.minutes_before_meeting == 10
    end
  end

  describe "oauth_tokens" do
    test "create_or_update_oauth_token/3 creates new token" do
      user = insert(:user)

      attrs = %{
        account_id: "account_123",
        access_token: "token_123",
        refresh_token: "refresh_123"
      }

      assert {:ok, token} = Accounts.create_or_update_oauth_token(user.id, :google, attrs)
      assert token.provider == :google
      assert token.access_token == "token_123"
    end

    test "get_oauth_token/3 returns token" do
      user = insert(:user)
      token = insert(:oauth_token, user: user, provider: :google)

      found = Accounts.get_oauth_token(user.id, :google, token.account_id)
      assert found.id == token.id
    end
  end
end

