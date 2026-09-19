# The Forge — marketing / download site

A single self-contained `index.html` (inline CSS + JS, Google Fonts only). Design
language adapted from the Sabihin marketing site — same token system and fonts.
No build step; host it as static files anywhere (Vercel, Netlify, S3, GitHub Pages…).

## Publish
1. Cut a fresh **notarized DMG** from the app repo root:
   ```bash
   FORGE_DEVID_IDENTITY="Developer ID Application: Orbital AI, LLC (87W73WQSPF)" \
   FORGE_NOTARY_PROFILE=forge-notary tool/release_macos.sh
   ```
   → `build/dist/TheForge-<version>.dmg`
2. Put the DMG where the download button points. The button links to
   `downloads/TheForge-latest.dmg` (relative) — either:
   - copy the DMG to `website/downloads/TheForge-latest.dmg`, or
   - change the `href` in `index.html` (search `TheForge-latest.dmg`) to your CDN URL.
3. Deploy the `website/` folder.

> Ship the **latest** version (currently ≥ v0.4.48, which stores API keys in the
> Keychain). The DMG built before v0.4.48 predates that security fix.

## Update
- **Copy / features:** edit the `<section>` blocks in `index.html`.
- **Look & feel:** edit the `:root` token block at the top of the `<style>`.
- `og:url` / `canonical` currently point at `theforge.orbitalai.net` — change to
  the real domain.

## Notes
- `downloads/` (the DMG binaries) is gitignored — don't commit large binaries.
- Requirements shown on the page: macOS 12+, Apple Silicon, BYOK key
  (Ollama Cloud / Claude / OpenAI). Update if that changes.
