# Bluesky plugin

Answer to browsing Bluesky the way Skylib does — local follows, no Bluesky
account — without taking on Skylib's licence.

## Licence stance (same as Reddit vs Stealth)

| | Skylib | XTA |
|---|---|---|
| Licence | **AGPL** | **MIT** |

Skylib was consulted only for the *approach*: keep follows on the device and
read public content without logging into Bluesky. None of its code is copied or
translated. This plugin talks to Bluesky's documented public AppView at
`https://public.api.bsky.app` and is written fresh in Dart.

## What is implemented (MVP)

- Profile lookup and author feeds via public xrpc
  (`app.bsky.actor.getProfile`, `app.bsky.feed.getAuthorFeed`,
  `app.bsky.actor.searchActors`).
- Local follows in SQLite (`bluesky_subscription`), merged into one newest-first
  timeline with per-account isolation.
- Profile screen with Follow / Unfollow; post cards that open `bsky.app` URLs.
- Home tab when the plugin is enabled; no settings screen (no instance, no
  credentials).

## Not implemented

- Compose, like, repost, follow-on-Bluesky, DMs, or any write to Bluesky.
- Custom AppView / PDS instance selection.
- Notifications, lists, starter packs, or video embeds beyond what a card can
  ignore safely.
