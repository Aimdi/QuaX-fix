# Phase 1 — Characterization test plan

Status: **partially started**. Selector + rate-limit tracker tests land with the
Grok Build setup PR. Remaining items below are next.

## Inventory (before Phase 1)

| Existing test | Area |
|---|---|
| `test/clean_url_test.dart` | `utils/urls.dart` tracking params |
| `test/list_url_test.dart` | list deep links |
| `test/feed_read_position_test.dart` | feed dedup / caught-up |

Gaps: no coverage for `AccountSelector`, `RateLimitTracker`, DB migrations, or
client JSON parsers.

## Spec — must lock before UI rewrite

### 1. Account selection — DONE (`test/account_selector_test.dart`)

Lock:

- Prefer healthy over not-found-flagged / rate-limited.
- Fall back to flagged when nothing healthy remains (never short-circuit to null
  while an untried account exists).
- Respect `notFoundCooldown` boundary.
- Honor `exclude` set; null only when all accounts tried.

### 2. Rate limit tracker — DONE (`test/rate_limit_tracker_test.dart`)

Lock:

- Keyed by `(accountId, endpoint)`.
- Limited strictly before reset; not limited at/after reset.
- `clear` removes only that pair.

### 3. Database migrations — TODO

- Boot an in-memory (or temp-file) DB at the oldest schema, migrate to current.
- Assert `accounts` auth headers / subscription rows survive.
- Target: repository migration plan entry points under `lib/database/`.

### 4. Client JSON parsers — TODO

- Capture live fixtures into `test/fixtures/<endpoint>/` (UserByScreenName,
  TweetDetail, HomeTimeline / SearchTimeline as available).
- Parser unit tests must use null-safe access expectations (`/parse-api`).
- Fixtures are the ground truth for "does the client still parse what X returns."

## Gate

Phase 2 UI rewrites must not start until items 1–2 stay green and 3–4 have at
least a first fixture + migration smoke test.
