#!/bin/bash
# Build the macOS release and install it to /Applications, replacing any
# older copy IN PLACE. User data survives: the drift index, settings
# (SharedPreferences), and project folders live under ~/Library and
# ~/Documents, not inside the bundle.
#
# Adapted from the Sabihin Starter-Repo deploy SOP. The Forge has no
# bundled runtime (BYOK cloud LLMs) and no Accessibility/TCC needs, so
# the llama-server bundling, TCC reset, and bundle-id migration steps
# from Sabihin are intentionally omitted.
#
# Usage:  tool/deploy_macos.sh [--no-build] [--stage-only]
#   --no-build     skip `flutter build`, install the existing Release build
#   --stage-only   build + verify signature, but do NOT install or launch
#
# Optional signing: set FORGE_SIGN_IDENTITY to a codesign identity (name or
# hash) to re-sign the app with a stable identity before install; otherwise
# the Flutter-produced signature is kept as-is.

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="the_forge"
APP_SRC="build/macos/Build/Products/Release/${APP_NAME}.app"
APP_DEST="/Applications/${APP_NAME}.app"

NO_BUILD=0; STAGE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    --stage-only) STAGE_ONLY=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

if [[ "$NO_BUILD" != 1 ]]; then
  echo "==> flutter build macos --release"
  flutter build macos --release
fi

[[ -d "$APP_SRC" ]] || { echo "error: $APP_SRC not found — build first"; exit 1; }

# Optional stable re-signing (keeps signature identical across rebuilds).
if [[ -n "${FORGE_SIGN_IDENTITY:-}" ]]; then
  echo "==> Re-signing with $FORGE_SIGN_IDENTITY"
  codesign --force --deep --sign "$FORGE_SIGN_IDENTITY" \
    --preserve-metadata=entitlements,flags "$APP_SRC"
fi
codesign --verify --strict "$APP_SRC" && echo "==> Signature verified"

if [[ "$STAGE_ONLY" == 1 ]]; then
  echo "Stage-only: skipping install. Staged app: $APP_SRC"
  exit 0
fi

echo "==> Quitting any running copy"
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 1

echo "==> Installing to $APP_DEST"
rm -rf "$APP_DEST"
ditto "$APP_SRC" "$APP_DEST"

echo "==> Launching"
open "$APP_DEST"
echo "Done."
