# Mastodon (Fediverse) plugin

Read-only browsing of public Fediverse accounts through any Mastodon-compatible
instance’s public REST API. No Mastodon login, no posting, boosting, favouriting,
or follow-on-instance.

## Approach

Mastodon (and many forks) expose public account and status endpoints without a
token. Account IDs are **per-instance**, so the reader picks a **home instance**
URL (settings). Lookups and status fetches go through that instance; remote
`user@other.instance` addresses are resolved via its federation
(`GET /api/v1/accounts/lookup`).

Follows stay on the device in SQLite (`mastodon_subscription`). The home tab is
a merged newest-first timeline of every locally followed acct’s public statuses.

## Endpoints used

| Call | Path |
|---|---|
| Instance check | `GET /api/v2/instance` (fallback `/api/v1/instance`) |
| Account lookup | `GET /api/v1/accounts/lookup?acct=` |
| Account statuses | `GET /api/v1/accounts/:id/statuses` |
| Account by id | `GET /api/v1/accounts/:id` |
| Resolve status URL | `GET /api/v2/search?q=&resolve=true&type=statuses` |
| Status | `GET /api/v1/statuses/:id` |
| Status context | `GET /api/v1/statuses/:id/context` |

No OAuth app registration. No write methods.

## Card UI

Public statuses render with a tweet-sized layout: avatar, body text, media,
PreviewCard link/article preview (`card`), and a read-only engagement row
(`replies_count` / `reblogs_count` / `favourites_count`). Tapping a post opens
an in-app thread (status + public replies via `context`). The open-in-browser
control and article link previews still leave the app — no write APIs.

## Not implemented

- Home / notifications timelines (need a user token)
- Compose, boost, favourite, follow/unfollow on the instance
- Polls, CW expand UI beyond plain text, video playback beyond a still card
- Picking a different AppView / ActivityPub client library
