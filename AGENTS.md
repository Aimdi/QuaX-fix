# AGENTS.md

General build/architecture/testing guidance for this repo lives in `CLAUDE.md`,
`README.md` (see "Build locally"), `.claude/skills/`, and `.grok/skills/`.
Read those first.

## Grok Build (grok-4.5) — project instructions

Grok Build auto-loads Claude Code assets (`CLAUDE.md`, `.claude/skills/`) **and**
this `AGENTS.md`, plus native skills under `.grok/skills/`. After changing
instruction or skill files, run `grok inspect` in the repo root and confirm they
appear.

### Hard rules (do not violate)

- **QuaX is a read-oriented X frontend, not X itself.** It views timelines,
  profiles, search, and media via reverse-engineered APIs. It does **not**
  create posts on X. Never add compose / reply / quote / repost / like-on-X /
  DM / Spaces hosting / account settings write-back. Local-only actions
  (device likes, saved folders, subscriptions stored in SQLite) are fine and
  already exist — do not wire them to X write endpoints.
- Footer icons that look like X actions are **navigation / local** affordances
  (e.g. comment opens the conversation; repeat opens the quotes screen; heart
  is local-only). Do not "fix" them into real posting.
- **Do not big-bang rewrite.** Keep `lib/client/` and `lib/database/` intact
  unless fixing a live API break. Rewrite UI/feature folders incrementally.
- **Store pattern only.** Use `flutter_triple` `Store<T>` — never `setState` or
  `ChangeNotifier` for feature state.
- **No raw UI strings.** Every user-visible string goes through ARB / `L10n`
  (see `/translate`).
- **Null-safe API parsing.** Reverse-engineered X JSON is fragile — use `?[]`
  and `as Type?` (see `/parse-api`).
- Prefer pure functions; keep functions under ~30 lines (widget builders excepted).
- Schema changes only via `sqflite_migration_plan` migrations.

### Permission / worktree workflow

- Default permission mode: **ask**. Keep **ask** for anything touching
  `lib/client/` or `lib/database/`. Use `always-approve` only inside isolated
  UI-module worktrees.
- One module per worktree (Grok has no built-in worktree flag):

  ```bash
  git worktree add ../quax-tweet rewrite/tweet
  cd ../quax-tweet && grok
  ```

- Module order for incremental UI rewrite:
  `tweet/` → `home/` → `profile/` → `search/` → `group/` → `saved/` → `settings/`
- Per module: Plan mode (`Shift+Tab` / `/plan`) → write a spec file → commit the
  spec → implement against it. Use `/context`, `/compact` between modules,
  `/memory` + `/flush` for durable decisions, `/rewind` to undo a bad direction,
  `/btw` for side questions.

### Skills (slash commands)

| Command | Source | Purpose |
|---|---|---|
| `/parse-api` | `.grok/skills/parse-api` (+ `.claude` mirror) | Safe X API JSON parsing |
| `/port-from-squawker` | `.grok/skills/port-from-squawker` | Port upstream Squawker fixes |
| `/translate` | `.grok/skills/translate` | ARB / UI string changes |

If names collide, use the qualified form (e.g. `/local:parse-api`).

### Rewrite plan

See `docs/grok-rewrite-plan.md` for phases, characterization-test targets, and
compatibility checkpoints. Do not start Phase 2 UI rewrites until Phase 0–1
gates pass (clean debug APK + characterization coverage for selector / rate
limits / migrations / client parsers).

## Cursor Cloud specific instructions

This is an **Android-only** Flutter app (only `android/` exists — no `web/`,
`linux/`, etc.). The toolchain is pinned to Flutter **3.44.4** via FVM, so always
invoke Flutter as `fvm flutter` / `fvm dart` (see `CLAUDE.md` / `README.md`).

The Cloud VM snapshot already has: FVM + the pinned Flutter SDK (`~/fvm`), the
Android SDK (`~/android-sdk`, exported via `ANDROID_HOME`/`ANDROID_SDK_ROOT` in
`~/.bashrc`), Java 21, and a Python venv at `.venv` for icon generation. `fvm` is
symlinked into `/usr/local/bin`. The startup update script runs `fvm install`,
`fvm flutter pub get`, and the two pure-Dart codegen steps below.

### Verifying the environment (what works here)
- Lint: `fvm flutter analyze` (expect ~44 `info` lints, no errors).
- Tests: `fvm flutter test` (pure-Dart unit tests under `test/`; use in-memory
  sqflite — these exercise core deep-link parsing and feed dedup/caught-up logic).
- Build: `fvm flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`.

### Running the app is NOT possible in this VM
There is no `/dev/kvm`, so the Android emulator cannot start (x86_64 images require
hardware acceleration). No physical device is attached, and the app is Android-only
(the `linux`/`chrome` devices `flutter` lists are unusable — no platform folders and
Android-only plugins). Meaningful features also require an X account + live x.com
access. Verify changes with `analyze` + `test` + `build apk --debug` instead.

The reverse-engineered X client *can* be exercised headlessly without the UI: the
guest path in `lib/client/client_unauthenticated.dart` is pure Dart (`http`), so a
throwaway test under `test/` can call `getToken()` + `fetchUnauthenticated()` against
live x.com (e.g. replicate `getProfileByScreenName`'s `UserByScreenName` request) to
confirm the guest-auth handshake + a real fetch work end to end. x.com egress works here.

### Non-obvious gotchas
- **`compileSdk 37` platform fix.** `android/app/build.gradle` uses `compileSdkVersion 37`,
  but `sdkmanager` only ships `platforms;android-37.0` (its `AndroidVersion.ApiLevel=37.0`),
  which this project's AGP resolves as hash `android-37` and fails to find. The snapshot
  contains a fixed copy at `~/android-sdk/platforms/android-37` with `AndroidVersion.ApiLevel=37`.
  If a fresh SDK ever lacks it: `cp -r ~/android-sdk/platforms/android-37.0 ~/android-sdk/platforms/android-37`
  then edit `source.properties` to `AndroidVersion.ApiLevel=37`. Gradle prints a harmless
  "inconsistent location" warning for `android-37`; ignore it.
- **`dart run dart_pubspec_licenses:generate` fails** under Flutter 3.44.4 + FVM
  (`PathNotFoundException: .../3.44.4/version` — the SDK dropped the legacy `version`
  file). Its output `lib/oss_licenses.dart` is **not imported** (the app uses Flutter's
  built-in `showLicensePage`), so this step is safe to skip. It is intentionally left
  out of the update script.
- **Generated code is gitignored** (`lib/generated`, `lib/oss_licenses.dart`,
  `assets/icon-*.png`). `intl_utils:generate` (localization, imported everywhere) and
  `flutter_iconpicker:generate_packs --packs material` run in the update script. A full
  APK build also needs the launcher icons: `.venv/bin/python generate_icons.py` then
  `fvm dart run flutter_launcher_icons` (icon resources persist in the snapshot, so this
  is only needed when icons change).
