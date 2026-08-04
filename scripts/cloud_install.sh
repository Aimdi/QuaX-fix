#!/usr/bin/env bash
# Idempotent toolchain bootstrap for Cursor Cloud agents working on QuaX.
set -euo pipefail

export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$HOME/fvm/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

echo "==> Git merge drivers"
"$(dirname "$0")/setup_git_merge_drivers.sh"

echo "==> Flutter (FVM)"
command -v fvm >/dev/null
fvm install
fvm use
fvm flutter pub get
fvm dart run intl_utils:generate || true
fvm dart run flutter_iconpicker:generate_packs --packs material || true

# compileSdk 37 platform hash quirk (AGENTS.md)
if [[ -d "$ANDROID_HOME/platforms/android-37.0" && ! -d "$ANDROID_HOME/platforms/android-37" ]]; then
  cp -r "$ANDROID_HOME/platforms/android-37.0" "$ANDROID_HOME/platforms/android-37"
  sed -i 's/AndroidVersion.ApiLevel=37.0/AndroidVersion.ApiLevel=37/' \
    "$ANDROID_HOME/platforms/android-37/source.properties" || true
fi

echo "==> cloud_install complete"
echo "Note: interactive Android UI needs /dev/kvm (not available on Cursor Cloud VMs)."
echo "      Use scripts/cloud_verify.sh, or adb connect <device> for a real phone."
