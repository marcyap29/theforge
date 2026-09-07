#!/bin/bash
# Build the iOS release and install it IN PLACE on a connected iPhone/iPad.
#
# Why not `flutter install`: it uninstalls first, wiping the app container
# (settings, local drift index, project data). `devicectl device install app`
# upgrades like Xcode does — the container survives.
#
# Usage:  tool/deploy_ios.sh [--no-build] [device-udid]
#   --no-build    install the existing build/ios/iphoneos/Runner.app
#   device-udid   defaults to the first connected physical iOS device

set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/ios/iphoneos/Runner.app"
BUNDLE_ID="ai.orbitalai.theForge"
NO_BUILD=0
DEVICE=""
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    *) DEVICE="$arg" ;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  # First usable iPhone/iPad. State reads "connected" for a cabled device,
  # "available" for a paired wireless one; the spaces around " available "
  # keep "unavailable" rows from matching.
  DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '
    (/ connected / || / available /) && (/iPhone/ || /iPad/) {
      for (i = 1; i <= NF; i++)
        if ($i ~ /^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$/) {
          print $i; exit
        }
    }')
  [[ -n "$DEVICE" ]] || { echo "error: no connected iOS device found"; exit 1; }
  echo "==> Using device $DEVICE"
fi

if [[ "$NO_BUILD" -eq 0 ]]; then
  echo "==> flutter build ios --release"
  flutter build ios --release
fi
[[ -d "$APP" ]] || { echo "error: $APP not found — build first"; exit 1; }

echo "==> Installing in place on $DEVICE (app data survives)"
xcrun devicectl device install app --device "$DEVICE" "$APP"

echo "==> Launching"
xcrun devicectl device process launch --device "$DEVICE" \
  "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "Done."
