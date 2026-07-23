# Grok Build 4.5 — QuaX-fix incremental rewrite plan

Durable plan for rewriting QuaX-fix's **UI/feature layer** with Grok Build
(grok-4.5). This is **not** a big-bang rewrite.

## Context (July 2026)

On **2026-07-20**, X shipped a from-scratch Android app rewrite (Kotlin + Jetpack
Compose). That client rewrite does **not** directly break QuaX-fix: this app is a
separate Flutter client talking to X's reverse-engineered backend API. The real
compatibility risk is server-side (GraphQL `doc_id` rotation, transaction-ID
schemes, rate limits) — not the new Android UI.

## Non-goals

- Do **not** rebuild `lib/client/` or `lib/database/` as part of a UI rewrite.
- Do **not** chase visual parity with X's new Android app unless explicitly scoped.
- Do **not** plan around Musk open-sourcing X — no timeline.

## Phase 0 — Tooling port (done in this change set)

1. Confirm Grok discovers instructions: `CLAUDE.md`, `AGENTS.md`, `.claude/skills/`,
   `.grok/skills/` via `grok inspect`.
2. Native Grok skills mirrored under `.grok/skills/` (`parse-api`,
   `port-from-squawker`, `translate`) so they appear as slash commands.
3. Worktree hygiene documented in `AGENTS.md` (manual `git worktree`, one module
   per session).
4. Reproducible debug APK gate: full `fvm` build chain before any rewrite.

## Phase 1 — Characterization tests (lock behavior first)

**Status: core gate met** (see `docs/specs/phase1-characterization.md`).

Coverage now includes:

| File | Covers |
|---|---|
| `test/clean_url_test.dart` | URL tracking-param stripping |
| `test/list_url_test.dart` | List deep links |
| `test/feed_read_position_test.dart` | Feed dedup / caught-up |
| `test/account_selector_test.dart` | Healthy vs 404 cooldown / 429 injection |
| `test/rate_limit_tracker_test.dart` | Per-(account, endpoint) windows |
| `test/migration_test.dart` | `buildMigrationPlan()` v22 → current |
| `test/client_parser_test.dart` | Live UserByScreenName / tweet fixtures |

Live fixtures live under `test/fixtures/`. Optional authenticated timeline
fixtures can land later without blocking Phase 2.

## Phase 2 — Incremental UI/feature rewrite

One feature folder per worktree / Grok session. Order:

1. `tweet/` (most reused) — **PR-1 in progress** (`docs/specs/tweet.md`): chrome
   tokens + conversation alignment + quote L10n
2. `home/`
3. `profile/`
4. `search/`
5. `group/`
6. `saved/`
7. `settings/`

Workflow per module:

1. Plan mode → write a module spec under `docs/specs/<module>.md` → commit.
2. Implement against the spec; keep `flutter_triple` Stores and ARB discipline.
3. `/compact` between modules; `/memory` + `/flush` for durable decisions.

## Phase 3 — Compatibility verification

After any change near `client/`:

1. `fvm flutter analyze` + `fvm flutter test` + `fvm flutter build apk --debug`.
2. Install on a real device, log in with a real X account (no pure-guest product
   mode), exercise timeline / profile / search / media / 429–404 retry paths.
3. Prefer upstream fixes via `/port-from-squawker` (`Teskann/QuaX`,
   `j-fbriere/squawker`) when X breaks auth or GraphQL docs.

## Plan-changing benchmarks

| Trigger | Response |
|---|---|
| X open-sources official clients / endpoints | Re-evaluate a real client-layer rewrite |
| Client-side request-signing change breaks QuaX | Drop UI work; API-parity spike in `lib/client/` first |
| Dependency-override stack collapses on Flutter bump | Dedicated dependency modernization phase |

## ToS note

Automating account access with a third-party X client may violate X's ToS and risk
account action. Treat live verification carefully.
