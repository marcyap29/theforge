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
2. The DMG is hosted on **GitHub Releases** in the public
   [`theforge-releases`](https://github.com/marcyap29/theforge-releases) repo.
   The download button points at the stable "latest" URL:
   `https://github.com/marcyap29/theforge-releases/releases/latest/download/TheForge.dmg`
   To publish a new build, attach it to a release with the asset named
   **`TheForge.dmg`** (same name every release, so the URL never changes):
   ```bash
   cp build/dist/TheForge-<version>.dmg build/dist/TheForge.dmg
   gh release create v<version> build/dist/TheForge.dmg \
     --repo marcyap29/theforge-releases --title "The Forge v<version>"
   ```
3. Deploy the `website/` folder (any static host).

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
