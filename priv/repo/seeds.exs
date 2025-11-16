alias PostMeetingApp.{Accounts, Automations}

# Create a test user
{:ok, user} =
  Accounts.create_user(%{
    email: "test@example.com",
    name: "Test User",
    google_account_id: "test_google_id"
  })

# Create default settings
Accounts.update_settings(user.id, %{minutes_before_meeting: 5})

# Create sample automations
Automations.create_automation(%{
  user_id: user.id,
  name: "LinkedIn Professional",
  social_network: "linkedin",
  instructions: "Generate a professional LinkedIn post highlighting key takeaways and insights from the meeting. Keep it engaging and suitable for a professional network.",
  example: "Just wrapped up an insightful discussion on [topic]. Key takeaway: [insight]. Looking forward to implementing these ideas!"
})

Automations.create_automation(%{
  user_id: user.id,
  name: "Facebook Casual",
  social_network: "facebook",
  instructions: "Generate a casual, friendly Facebook post about the meeting. Make it conversational and relatable.",
  example: "Had a great conversation today about [topic]! Excited to share what we discussed."
})

IO.puts("Seeded database with test user and sample automations")

