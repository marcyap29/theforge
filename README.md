# The Forge

An AI app builder for macOS that handles the hard parts of vibe coding: writing the spec, tracking the features, and building the code with AI, all in one window. Bring your own AI key.

## Why it exists

AI coding tools are good at writing code and bad at remembering what you asked for. Features get stubbed and called done, plans drift between attempts, and you lose track of what actually works. The Forge sits upstream of the coding agent and keeps the project honest.

## What it does

- **Architect chat.** Talk through your idea, refine features, and get a build order that respects dependencies.
- **Feature board.** Every feature tracked from idea to shipped, with epics broken into buildable steps.
- **Build with AI.** An implementation agent that scouts your repo, proposes a plan, waits for your approval, applies the edits, and runs `dart analyze` before calling anything done.
- **Completion guard.** Flags builds that only touched docs, left stubs, or silently swapped a format, so a fake "done" doesn't slip through.
- **Security check.** Scans for hardcoded secrets and runs an LLM audit of your repo.
- **Repo onboarding.** Point it at an existing project and it works out what the app can actually do today.

## Bring your own key

The Forge runs on your own AI account. Supported providers: Claude, OpenAI, Gemini, and Ollama (local or cloud). Keys are stored encrypted in the macOS Keychain and never leave your machine except to call the provider you chose. There is no Forge account and no Forge server in the loop.

## Install

Download the latest notarized build for macOS:

https://github.com/marcyap29/theforge-releases/releases/latest/download/TheForge.dmg

## Build from source

Requires Flutter (Dart SDK ^3.10.7) on macOS.

```bash
git clone https://github.com/marcyap29/theforge.git
cd theforge
flutter pub get
flutter run -d macos
```

Generated database code is committed, so you don't need to run `build_runner` unless you change the schema.

## Status

Early and moving fast. macOS is the supported platform. Expect rough edges, and open an issue when you hit one.

## License

The Forge is source-available under the [PolyForm Noncommercial License 1.0.0](LICENSE). You can use it, study it, and modify it for any noncommercial purpose. Personal projects, hobby work, research, and education are all fine.

If you want to use it commercially, for example inside a company or for client work, open an issue on this repo and we'll talk.

Copyright 2026 Orbital AI, LLC.
