defmodule PostMeetingApp.AutomationsTest do
  use PostMeetingApp.DataCase

  alias PostMeetingApp.Automations

  describe "automations" do
    test "create_automation/1 creates automation" do
      user = insert(:user)

      attrs = %{
        user_id: user.id,
        name: "Test Automation",
        social_network: "linkedin",
        instructions: "Generate professional posts"
      }

      assert {:ok, automation} = Automations.create_automation(attrs)
      assert automation.name == "Test Automation"
      assert automation.social_network == "linkedin"
    end

    test "list_automations/1 returns user automations" do
      user = insert(:user)
      automation = insert(:automation, user: user)

      automations = Automations.list_automations(user.id)
      assert length(automations) == 1
      assert hd(automations).id == automation.id
    end
  end
end

