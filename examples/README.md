# env.zig Example

A small web server demonstrating [env.zig](../) with GitHub OAuth2 authentication. Unauthenticated users see a public message; authenticated users see a special message loaded from environment variables.

## Setup

**1. Copy `.env.example` to `.env` and fill in your values:**

```sh
cp .env.example .env
```

```sh
# .env
GITHUB_CLIENT_ID="your_github_client_id"
GITHUB_CLIENT_SECRET="your_github_client_secret"
GITHUB_CALLBACK_URL="http://localhost:3000/auth/github/callback"
PUBLIC_MESSAGE="Hey, sign in to see a special message"
SPECIAL_MESSAGE="Hello authenticated user, from env.zig!"
PORT=3000
```

You'll need a GitHub OAuth app — create one at [github.com/settings/developers](https://github.com/settings/developers) and set the callback URL to `http://localhost:3000/auth/github/callback`.

**2. Run the server:**

```sh
zig build run
```

## Routes

| Route | Description |
|---|---|
| `GET /public/hello` | Returns the public message, no auth required |
| `GET /auth/github` | Redirects to GitHub to begin OAuth login |
| `GET /auth/github/callback` | Handles the OAuth callback, returns user profile and special message |
