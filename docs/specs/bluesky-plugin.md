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
`https://public.api.bsky.app` by default and is written fresh in Dart.

## What is implemented

- Profile lookup, author feeds, people search, and post threads via public xrpc
  (`app.bsky.actor.getProfile`, `app.bsky.feed.getAuthorFeed`,
  `app.bsky.actor.searchActors`, `app.bsky.feed.getPostThread`).
- Local follows in SQLite (`bluesky_subscription`), merged into one newest-first
  timeline with per-account isolation.
- Profile screen with Follow / Unfollow and cursor pagination.
- Tappable follower / following counts open a paginated public graph list
  (`app.bsky.graph.getFollowers` / `getFollows`); rows open that profile.
- In-app thread screen (ancestors + replies); browser open is opt-in.
- Post cards with engagement counts, author → profile, repost chrome, quote
  embeds, and external link cards.
- People search sheet (exact handle/DID/URL opens a profile; free text uses
  `searchActors`).
- Home tab when the plugin is enabled.
- Settings with a working default AppView (`kBlueskyDefaultAppView` /
  `https://public.api.bsky.app`). Empty or invalid values fall back to that
  default; readers can point at another AppView and test it.

## Not implemented

- Compose, like, repost, follow-on-Bluesky, DMs, or any write to Bluesky.
- Notifications, lists, starter packs, or video embeds beyond what a card can
  ignore safely.
- Interleaving Bluesky posts into the X home / group feeds.
- Local likes library (Threads has this; Bluesky does not yet).
