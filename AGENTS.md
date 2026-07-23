# AGENTS.md

General build/architecture/testing guidance for this repo lives in `CLAUDE.md`,
`README.md` (see "Build locally"), and `.claude/skills/`. Read those first.

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
