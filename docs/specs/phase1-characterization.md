# Phase 1 — Characterization test plan

Status: **core gate met**. Selector, rate-limit, migration smoke, and live
parser fixtures are green. Optional follow-ups listed below.

## Inventory

| Test | Area |
|---|---|
| `test/clean_url_test.dart` | `utils/urls.dart` tracking params |
| `test/list_url_test.dart` | list deep links |
| `test/feed_read_position_test.dart` | feed dedup / caught-up |
| `test/account_selector_test.dart` | account health selection |
| `test/rate_limit_tracker_test.dart` | per-endpoint 429 memory |
| `test/migration_test.dart` | schema upgrade 22 → current |
| `test/client_parser_test.dart` | live GraphQL fixture parsers |

## Spec

### 1. Account selection — DONE (`test/account_selector_test.dart`)

- Prefer healthy over not-found-flagged / rate-limited.
- Fall back to flagged when nothing healthy remains.
- Respect `notFoundCooldown` boundary; honor `exclude`.

### 2. Rate limit tracker — DONE (`test/rate_limit_tracker_test.dart`)

- Keyed by `(accountId, endpoint)`; clear is pair-scoped.

### 3. Database migrations — DONE (`test/migration_test.dart`)

- `buildMigrationPlan()` + `databaseVersion` extracted from `repository.dart`.
- Fresh `onCreate` → current version has accounts/subscription tables + health columns.
- Seed at **v22**, upgrade to current: `auth_header` and subscription fields survive.

### 4. Client JSON parsers — DONE (first fixtures)

Live guest captures (2026-07-23), redacted of tokens:

| Fixture | Parser entry |
|---|---|
| `test/fixtures/UserByScreenName/ok.json` | `UserWithExtra.fromNonLegacyJson` |
| `test/fixtures/TweetDetail/tweet_result.json` | `TweetWithCard.fromGraphqlJson` |
| `test/fixtures/UserTweets/add_entries.json` | `Twitter.createTweetChains` |

`TweetDetail` GraphQL returned 404 for guests; tweet nodes were taken from
`UserTweets` instead. That is still live X JSON.

## Optional follow-ups (not blocking Phase 2)

- Authenticated `TweetDetail` / `SearchTimeline` / `HomeTimeline` fixtures.
- Older migration path (e.g. v6 → current) for pre-accounts installs.
- Unavailable / tombstone user+tweet shapes.

## Gate

Phase 2 UI rewrites may start when this file's DONE items stay green on CI /
`fvm flutter test`. Keep `lib/client/` + `lib/database/` ask-mode only.
