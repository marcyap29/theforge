# Deploy scripts

Device/desktop deploy tooling for The Forge, adapted from the Sabihin Starter-Repo
deploy SOP. All scripts live in `tool/` and are run from the repo root.

The Forge has **no bundled runtime** (it uses BYOK cloud LLMs) and **no
Accessibility/TCC** needs, so Sabihin's llama-server bundling, TCC-reset, and
bundle-id migration steps are intentionally omitted here.

## macOS

```bash
tool/deploy_macos.sh                # build release → install to /Applications → launch
tool/deploy_macos.sh --no-build     # install the existing Release build
tool/deploy_macos.sh --stage-only   # build + verify signature, do NOT install
```

- Installs `the_forge.app` to `/Applications`, replacing any older copy **in place**.
  User data survives: the drift index and SharedPreferences live under
  `~/Library`, and project folders under `~/Documents` (or your chosen root).
- **Optional stable signing:** set `FORGE_SIGN_IDENTITY` to a codesign identity
  (name or hash) to re-sign before install; otherwise the Flutter-produced
  signature is kept.
- `tool/install_macos.sh` is a compatibility wrapper that calls `deploy_macos.sh`.

### Sandbox note
The macOS target is **unsandboxed** (see `macos/Runner/*.entitlements`) because
Watch Mode and the tracker's repo scan + check-ins shell out to `git` and read
arbitrary local repositories — impossible under the App Sandbox. This means the
app is distributed directly (Developer ID + notarization), **not** via the Mac
App Store. The path back to a sandboxed / App-Store-eligible build is documented
in `APP_STORE_SANDBOX_PLAN.md`.

## iOS

```bash
tool/deploy_ios.sh                  # build release → install in place on a connected device → launch
tool/deploy_ios.sh --no-build       # install the existing build
tool/deploy_ios.sh <device-udid>    # target a specific device
```

Uses `devicectl device install app` (upgrade-in-place) rather than
`flutter install` (which wipes the app container).

## Android

```bash
tool/deploy_android.sh                 # build release APK → adb install -r → launch
tool/deploy_android.sh --no-build      # install the existing APK
tool/deploy_android.sh <device-serial> # target a specific device
```

`adb install -r` replaces the app while keeping its data.

## Prerequisites
- **macOS:** Xcode + command line tools; a code-signing identity if you set
  `FORGE_SIGN_IDENTITY` (otherwise Flutter's default signature is used).
- **iOS:** a connected, trusted device; a valid provisioning profile / signing set up in Xcode.
- **Android:** `adb` on PATH; device with USB debugging authorized.

> If you changed `lib/data/local_db/forge_database.dart`, regenerate drift code
> before building. On Dart 3.10+ that needs a one-line workaround — see the repo
> memory note "theforge build_runner hook workaround".
