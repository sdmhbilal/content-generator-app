# Post Meeting Social Media Content Generator

A production-ready Elixir Phoenix + LiveView application that automatically generates social media content from meeting transcripts using Recall.ai and AI.

## Features

- **Google OAuth Login**: Secure authentication with Google accounts
- **Calendar Sync**: Automatically sync Google Calendar events
- **Recall.ai Integration**: Schedule notetakers to join meetings and retrieve transcripts
- **AI Content Generation**: Generate follow-up emails and social media posts using OpenAI
- **Social Media Posting**: Direct posting to LinkedIn and Facebook
- **Automations**: Configure custom post generation rules per social network

## Tech Stack

- Elixir 1.17
- Phoenix 1.7 with LiveView
- PostgreSQL
- Oban for background jobs
- Finch for HTTP requests
- Tailwind CSS for styling

## Prerequisites

- Elixir 1.17+ and Erlang/OTP 25+
- PostgreSQL 12+
- Node.js 18+ (for assets)

## Setup

1. **Clone and install dependencies:**

```bash
mix deps.get
cd assets && npm install && cd ..
```

2. **Set up the database:**

```bash
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
```

3. **Configure environment variables:**

Create a `.env` file or set the following environment variables:

```bash
# Database
export DATABASE_USER=postgres
export DATABASE_PASS=postgres
export DATABASE_HOST=localhost
export DATABASE_NAME=post_meeting_app_dev

# Phoenix
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# Google OAuth
export GOOGLE_CLIENT_ID=your_google_client_id
export GOOGLE_CLIENT_SECRET=your_google_client_secret

# OpenAI
export OPENAI_API_KEY=your_openai_api_key

# Recall.ai
export RECALL_API_KEY=your_recall_api_key

# LinkedIn OAuth
export LINKEDIN_CLIENT_ID=your_linkedin_client_id
export LINKEDIN_CLIENT_SECRET=your_linkedin_client_secret
export LINKEDIN_REDIRECT_URI=http://localhost:4000/auth/linkedin/callback

# Facebook OAuth
export FACEBOOK_CLIENT_ID=your_facebook_client_id
export FACEBOOK_CLIENT_SECRET=your_facebook_client_secret
export FACEBOOK_REDIRECT_URI=http://localhost:4000/auth/facebook/callback
```

4. **Start the server:**

```bash
mix phx.server
```

Visit `http://localhost:4000` to see the application.

## OAuth Setup

### Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google Calendar API
4. Go to **APIs & Services** → **OAuth consent screen**
5. Configure the OAuth consent screen:
   - Choose **External** (unless you have a Google Workspace account)
   - Fill in the required app information (App name, User support email, Developer contact)
   - Add scopes: `email`, `profile`, `https://www.googleapis.com/auth/calendar.readonly`
6. **Important for Testing**: In the OAuth consent screen, scroll to **Test users** section:
   - Click **+ ADD USERS**
   - Add your email address (e.g., `your-email@gmail.com`)
   - Save
   - **Note**: Only test users can sign in while the app is in "Testing" mode
7. Go to **APIs & Services** → **Credentials**
8. Create OAuth 2.0 credentials (OAuth client ID)
9. Add authorized redirect URI: `http://localhost:4000/auth/google/callback`
10. Copy Client ID and Client Secret

**Troubleshooting**: If you see "Access blocked" error:
- Make sure your email is added as a test user in the OAuth consent screen
- The app must be in "Testing" mode (default) or you need to publish it for production use

### LinkedIn OAuth

1. Go to [LinkedIn Developers](https://www.linkedin.com/developers/)
2. Create a new app
3. Add redirect URL: `http://localhost:4000/auth/linkedin/callback`
4. Request permissions: `openid`, `profile`, `email`, `w_member_social`
5. Copy Client ID and Client Secret

**Important Notes for LinkedIn Posting:**

- **Required Permissions**: The app requests `w_member_social` permission which is required for posting to LinkedIn. This permission requires approval from LinkedIn.

- **Posts API Access**: To post to LinkedIn, you also need:
  1. Request **Marketing Developer Platform** access in LinkedIn Developer Portal
  2. Request **Posts API** access
  3. Wait for approval
  4. Ensure your app has the `partnerApiPostsExternal.CREATE` permission

- **Current Implementation**: The app uses the LinkedIn Posts API (`/rest/posts` endpoint) with version `202501` and requires proper OAuth scopes and API access.

### Facebook OAuth

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create a new app
3. Add Facebook Login product
4. Add redirect URI: `http://localhost:4000/auth/facebook/callback`
5. Copy App ID and App Secret

**Important Notes for Facebook Page Posting:**

- **Basic Connection**: The app currently requests only `public_profile` permission, which allows basic connection without App Review.

- **Page Posting Requires App Review**: To post to Facebook Pages, you must:
  1. Go to Facebook Developer Portal → Your App → **App Review**
  2. Request these permissions for review:
     - `pages_manage_posts` - to create posts on pages
     - `pages_read_engagement` - to read page engagement data
     - `pages_show_list` - to list user's pages (required for `/me/accounts` endpoint)
  3. Complete **Business Verification** if required by Facebook
  4. Wait for approval (can take days/weeks)
  5. Once approved, update the OAuth scope in `lib/post_meeting_app_web/controllers/auth_controller.ex` (line ~240) to:
     ```elixir
     scope = "public_profile,pages_manage_posts,pages_read_engagement,pages_show_list"
     ```
  6. Users must reconnect their Facebook account after App Review approval

- **Why App Review is Required**: Facebook requires App Review for page permissions before they can be requested in OAuth. If you try to request these permissions without App Review, Facebook will return an "Invalid Scopes" error.

- **Current Limitations**: With only `public_profile` permission, users can connect Facebook but cannot post to Pages. The app will show a clear error message when attempting to post, explaining that App Review is required.

**References:**
- [Facebook Pages API Documentation](https://developers.facebook.com/docs/pages-api/posts/)
- [Facebook Login Permissions](https://developers.facebook.com/docs/facebook-login/permissions)
- [Stack Overflow: How to add posts to Facebook page](https://stackoverflow.com/questions/76418640/how-do-i-add-posts-to-my-page-through-the-facebook-api)

## Project Structure

```
lib/
  post_meeting_app/
    accounts/          # User management and OAuth tokens
    calendars/         # Google Calendar sync
    meetings/           # Meeting and transcript management
    recall/             # Recall.ai integration
    automations/        # Post generation automations
    social/             # LinkedIn/Facebook posting
    web/                # Phoenix web layer
      live/             # LiveViews
      controllers/      # Controllers
      components/       # Reusable components
```

## Testing

Run the test suite:

```bash
mix test
```

## Troubleshooting

### Facebook Posting Issues

If you encounter issues posting to Facebook:

1. **Check Token Permissions**: The app includes extensive logging that shows what permissions your token has. Check the logs for messages like:
   - `[FacebookClient] Token has scopes: ["public_profile"]`
   - `[FacebookClient] Token missing required permissions`

2. **App Review Required**: If you see "Invalid Scopes" error or token only has `public_profile`, you need to complete App Review for page permissions.

3. **No Pages Found**: If `/me/accounts` returns 0 pages, ensure:
   - You have created a Facebook Page
   - You are an admin of the page
   - Your token has `pages_show_list` permission (requires App Review)

### LinkedIn Posting Issues

If you encounter issues posting to LinkedIn:

1. **Check API Permissions**: The app logs detailed information about API calls. Look for:
   - `[LinkedInClient] LinkedIn Version: 202501`
   - `[LinkedInClient] API URL: https://api.linkedin.com/rest/posts`
   - Error messages indicating missing permissions

2. **403 Forbidden Errors**: If you see `partnerApiPostsExternal.CREATE` permission errors:
   - Request Marketing Developer Platform access
   - Request Posts API access
   - Wait for LinkedIn approval

3. **Timeout Errors**: The app has 30-second timeouts configured. If requests timeout, check network connectivity and LinkedIn API status.

### Debugging

The application includes comprehensive logging for:
- OAuth token exchanges and permission checks
- API requests and responses (with masked tokens)
- Equivalent curl commands for manual testing
- Detailed error messages with troubleshooting guidance

Check your application logs for detailed debugging information.

## Background Jobs

The application uses Oban for background job processing:

- **Recall Worker**: Schedules Recall.ai bots for meetings
- **Recall Poller**: Polls bot status and retrieves transcripts
- **Calendar Sync Worker**: Syncs Google Calendar events

## Deployment

### Kubernetes

The application is designed to run on Kubernetes. Key considerations:

- Set all environment variables as secrets/config maps
- Use PostgreSQL as a managed service or StatefulSet
- Run Oban migrations: `mix ecto.migrate`
- Ensure Redis is available if using Oban Pro

### Environment Variables for Production

All the same environment variables are required in production. Additionally:

- `SECRET_KEY_BASE`: Generate with `mix phx.gen.secret`
- `DATABASE_URL`: Full PostgreSQL connection string
- `PORT`: Server port (default: 4000)
- `HOST`: Your domain name

## License

MIT

