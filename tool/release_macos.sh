#!/bin/bash
# Build a DISTRIBUTABLE macOS release of The Forge: Developer ID signed with the
# hardened runtime, notarized by Apple, stapled, and packaged as a DMG for the
# website. This is the direct-distribution path (NOT the Mac App Store — the app
# spawns flutter/git/xcrun/adb, which the App Store sandbox forbids).
#
# Usage:  tool/release_macos.sh [--no-build]
#   --no-build     reuse the existing Release build (skip `flutter build`)
#
# Required environment (see PREREQS printed below when missing):
#   FORGE_DEVID_IDENTITY   "Developer ID Application: Your Name (TEAMID)"
#                          — from `security find-identity -v -p codesigning`
#   FORGE_NOTARY_PROFILE   name of a notarytool keychain profile you created with
#                          `xcrun notarytool store-credentials` (recommended)
#     …OR the trio:
#   FORGE_APPLE_ID         your Apple ID email
#   FORGE_TEAM_ID          your 10-char Team ID
#   FORGE_APP_PASSWORD     an app-specific password (appleid.apple.com)
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="the_forge"
APP_SRC="build/macos/Build/Products/Release/${APP_NAME}.app"
ENTITLEMENTS="macos/Runner/Release.entitlements"
DIST_DIR="build/dist"
VERSION="$(grep -m1 "_appVersion = '" lib/main.dart | sed -E "s/.*'([0-9.]+)'.*/\1/")"
DMG_PATH="${DIST_DIR}/TheForge-${VERSION:-dev}.dmg"

NO_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

print_prereqs() {
  cat >&2 <<'EOF'

── PREREQUISITES for a notarized release ───────────────────────────────────────
1. Apple Developer Program membership ($99/yr) — https://developer.apple.com
2. A "Developer ID Application" certificate. In Xcode:
     Settings ▸ Accounts ▸ (your team) ▸ Manage Certificates ▸ + ▸
     "Developer ID Application". Then confirm it shows up:
     security find-identity -v -p codesigning
   Export its full name to FORGE_DEVID_IDENTITY, e.g.:
     export FORGE_DEVID_IDENTITY="Developer ID Application: Marc Yap (GA824QSBZ5)"
3. Notary credentials — create a reusable keychain profile ONCE:
     xcrun notarytool store-credentials forge-notary \
       --apple-id "you@example.com" --team-id "GA824QSBZ5" \
       --password "app-specific-password"   # from appleid.apple.com
   Then:
     export FORGE_NOTARY_PROFILE="forge-notary"
────────────────────────────────────────────────────────────────────────────────
EOF
}

# ---- Preflight: verify cert + notary creds before doing any work -------------
FAIL=0
if [[ -z "${FORGE_DEVID_IDENTITY:-}" ]]; then
  echo "✗ FORGE_DEVID_IDENTITY is not set." >&2; FAIL=1
elif ! security find-identity -v -p codesigning | grep -qF "$FORGE_DEVID_IDENTITY"; then
  echo "✗ Signing identity not found in keychain: $FORGE_DEVID_IDENTITY" >&2; FAIL=1
fi
if [[ -z "${FORGE_NOTARY_PROFILE:-}" ]] &&
   { [[ -z "${FORGE_APPLE_ID:-}" ]] || [[ -z "${FORGE_TEAM_ID:-}" ]] || [[ -z "${FORGE_APP_PASSWORD:-}" ]]; }; then
  echo "✗ No notary credentials (set FORGE_NOTARY_PROFILE, or the Apple ID trio)." >&2; FAIL=1
fi
if [[ "$FAIL" == 1 ]]; then print_prereqs; exit 1; fi

notary_args() {
  if [[ -n "${FORGE_NOTARY_PROFILE:-}" ]]; then
    echo "--keychain-profile ${FORGE_NOTARY_PROFILE}"
  else
    echo "--apple-id ${FORGE_APPLE_ID} --team-id ${FORGE_TEAM_ID} --password ${FORGE_APP_PASSWORD}"
  fi
}

# ---- Build -------------------------------------------------------------------
if [[ "$NO_BUILD" != 1 ]]; then
  echo "==> flutter build macos --release"
  flutter build macos --release
fi
[[ -d "$APP_SRC" ]] || { echo "error: $APP_SRC not found — build first"; exit 1; }

# ---- Sign: hardened runtime + timestamp + Developer ID (deep) ----------------
echo "==> Signing with hardened runtime ($FORGE_DEVID_IDENTITY)"
codesign --force --deep --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$FORGE_DEVID_IDENTITY" "$APP_SRC"
codesign --verify --strict --deep "$APP_SRC"
echo "==> Signature verified"

# ---- Package a DMG -----------------------------------------------------------
echo "==> Building DMG → $DMG_PATH"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
STAGE="$(mktemp -d)"
ditto "$APP_SRC" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "The Forge" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGE"

# ---- Notarize the DMG + staple ----------------------------------------------
echo "==> Submitting to Apple notary service (this can take a few minutes)…"
# shellcheck disable=SC2046
xcrun notarytool submit "$DMG_PATH" $(notary_args) --wait

echo "==> Stapling the notarization ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

# Verify Gatekeeper accepts the APP INSIDE the DMG (asserting on the .dmg
# container itself gives a misleading "rejected" — the app is what's assessed).
echo "==> Verifying Gatekeeper acceptance of the app inside the DMG"
MOUNT="$(hdiutil attach "$DMG_PATH" -nobrowse -readonly | grep -o '/Volumes/.*' | head -1)"
APP_IN_DMG="$(ls -d "$MOUNT"/*.app 2>/dev/null | head -1)"
spctl -a -vvv --type exec "$APP_IN_DMG" 2>&1 | sed 's/^/    /' || true
hdiutil detach "$MOUNT" >/dev/null 2>&1 || true

echo "Done. Distributable, notarized DMG: $DMG_PATH"
