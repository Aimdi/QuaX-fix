# Design craft (Threads / Phanpy / Bluesky / Misskey)

Read-only visual hierarchy work. No social writes. Prefer subtraction over new chrome.

## Priority (build first)

1. **Thread connector on status replies** — vertical line avatar→avatar on the status screen (feed threads already have `_buildThreadBody`). Cap indent depth at 2, then flatten with “Continue thread”.
2. **Provenance accent** — 2px leading strip on interleaved (non-X) cards using each plugin’s `brandColor`.
3. **Demoted engagement row** — footer icons/labels one quiet gray step down; body text stays loudest. Companion prefs: calm mode (hide counts) + always-quiet footer chrome.

## Next

4. **Sensitive interstitial that remembers** — “Show once” vs “Always show sensitive media” persisting to prefs (today `TweetContextState.setHideSensitive(false)` is session-only).
5. **Boost carousel** — consecutive retweet chains by different authors collapse into one horizontal row of boost cards.
6. **Group identity header** — group feed shell shows icon/emoji, color, member count under the title.
7. **Sacred scroll** — treat read-position restore as guaranteed; quiet unread pill already exists — audit refresh/rotation gaps.

## Non-goals

- No purple glow, pill clusters, or card restyle of the hero tweet.
- Keep X-Look tokens; demotion uses `onSurfaceVariant` / outline, not new brand colors on X posts.
