# tweet/ module — Phase 2 rewrite spec

Incremental UI/structure rewrite of `lib/tweet/`. Keep `flutter_triple` Stores
for feature state; do **not** change `lib/client/` or `lib/database/`.

## Freeze (out of scope for early PRs)

- Video stack: `_video.dart`, `_video_controls.dart`, `video_controller_pool.dart`,
  `video_audio_focus.dart`, `video_quality.dart`
- GraphQL / `TweetWithCard` parsing in `lib/client/client.dart`
- Deep `_card.dart` binding-values parsing (later null-safety pass)

## Chrome tokens (align with twitter-ui-redesign)

| Token | Value |
|---|---|
| Media / quote / link-card radius | `16` |
| Timeline divider thickness | `0.5` |
| Card elevation / margin | `0` / `EdgeInsets.zero` |
| Card shape | square (`BorderRadius.zero`) |
| Display name weight | `FontWeight.w700` |

Source of truth: `lib/tweet/tweet_chrome.dart`.

## Composition

```
PaginatedTweetList / CachedTweetList
  → TweetConversation
    → TweetTile (± quoted / Birdwatch nested tiles)
      → header + ExpandableTweetText + TweetMedia + TweetCard + footer
```

## PR-1 — DONE: chrome consistency + quote L10n

1. Add `tweet_chrome.dart` with shared radius / divider / flat-card helpers.
2. Align `conversation.dart` thread wrapper with standalone tile chrome
   (flat card, 0.5dp divider).
3. Replace raw English quote fallbacks in `tweet.dart` with ARB keys.
4. Use chrome constants from `TweetTile` where the same numbers already exist.

## PR-2 — DONE: extract footer

1. Move engagement / save / share / translate strip to `tweet_footer.dart`
   (`TweetFooterBar`, `TranslationStatus`, `footerButtonStyle`).
2. Keep `TweetTile` as orchestrator; translation state stays on the tile.

## Later PRs (ordered)

1. Extract header / `_TweetTileLeading` into `tweet_header.dart`.
2. Move `TweetContextState` out of `lib/profile/profile.dart`.
3. Null-safe `_card.dart` access (`/parse-api`).

## Acceptance

- `fvm flutter test` green; no new analyze errors in touched files.
- Multi-tweet threads match standalone tile dividers/card chrome.
- Quote unavailable / missing-permalink paths show localized copy.
- Like / save / share / translate behavior unchanged.
