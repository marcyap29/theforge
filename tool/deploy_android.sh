#!/bin/bash
# Build the release APK and install it IN PLACE on a connected device.
#
# `adb install -r` replaces the app while KEEPING its data (settings, local
# drift index, project data). Release build deliberately: release-only traps
# (tree-shaking, obfuscation) never show in debug builds.
#
# Usage:  tool/deploy_android.sh [--no-build] [device-serial]
#   --no-build      install the existing release APK
#   device-serial   defaults to the only/first device in `adb devices`

set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="ai.orbitalai.the_forge"
APK="build/app/outputs/flutter-apk/app-release.apk"
NO_BUILD=0
DEVICE=""
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    *) DEVICE="$arg" ;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  # First device in "device" state (skips "unauthorized"/"offline").
  DEVICE=$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')
  [[ -n "$DEVICE" ]] || { echo "error: no connected Android device found (check: adb devices — unlock and authorize the phone)"; exit 1; }
  echo "==> Using device $DEVICE"
fi

if [[ "$NO_BUILD" -eq 0 ]]; then
  echo "==> flutter build apk --release"
  flutter build apk --release
fi
[[ -f "$APK" ]] || { echo "error: $APK not found — build first"; exit 1; }

echo "==> Installing in place on $DEVICE (app data survives)"
adb -s "$DEVICE" install -r "$APK"

echo "==> Launching"
adb -s "$DEVICE" shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1 \
  >/dev/null 2>&1 || true
echo "Done."
