# Base View v2 — the Flame layer (plan)

**Status:** In progress (branch `feat/base-view-v2`, shipping phase-by-phase as `v0.6.x`)
**Created:** 2026-09-25
**Owner:** Marc + Claude (Claude builds the Flame engine; Build-with-AI dogfoods thin wiring only)

---

## Goal / north star

Turn the v1 2D radial base into a **living isometric world**: cute robots (agents)
build feature-buildings, walk out from a central station as projects grow, and
**wave when they're blocked** — click one to open its build. Everything driven by
The Forge's already-live data (`implActiveRunsProvider`, `implRunProvider`,
`featureListProvider`).

**North star reference:** @jarrenrocks' 3D hex-planet agent manager (Instagram/
TikTok, 2026-09) — hexagon = project, cute robots-with-faces = agents, click a
blocked robot to open the agent, robots walk out of a space station, multiple
planets. That is Base View at full fidelity. See `§GAME` in `backlog.md`.

## Forge mapping

| jarrenrocks' game | The Forge |
|---|---|
| Hexagon = a project | hex/building = a feature/project |
| Robot with a face = an agent | robot = a Build-with-AI run |
| Robot "blocked, needs help", waves | run **awaiting approval / blocked** |
| Click robot → opens Claude Code | click → opens The Forge's own build window |
| Robots walk out of a station | bots spawn at the hub as features build |
| Multiple planets | portfolio groupings (v2.5/v3) |

The Forge's edge: it has its **own** agent, so clicking a robot opens *our* build
window directly — no shelling out to an external tool.

## Scope

**In (v2):** Flame isometric scene, camera pan/zoom, robots with faces (Rive),
the blocked→wave→click→open loop (points 5–6), walk-out-of-station spawn.

**Out (→ v3):** true 3D planet, orbit camera, terraformed-planet look. Multiple
planets / portfolio map is a v2.5 stretch (Phase D), not core v2.

## Key decisions (locked unless revisited)

1. **Engine: Flame (2D isometric)** for v2 — Dart, embeds in a Flutter widget,
   talks to Riverpod. True 3D (Godot, or Three.js in a webview) is a separate
   **v3** track, only if v2 proves it's worth it.
2. **Art: Rive for robots** (vector + a state machine keyed to `RunPhase`:
   idle / working / blocked-wave — this is what makes them feel alive); simpler
   tiles for hexes/buildings.
3. **Art sourcing:** the one non-engineering cost. Default: **stub with shapes
   now, decide real art after Phase B feels good** (commission Rive / asset pack /
   AI-gen). This is what separates "colored shapes" from "the video."
4. **Build approach:** Claude builds the Flame engine (the Ollama-cloud models
   thrash on unfamiliar Flame APIs); Build-with-AI dogfoods only thin wiring.
5. **Delivery:** branch `feat/base-view-v2`, ship phase-by-phase as `v0.6.x`.

## Architecture

- A **`FlameGame` embedded via `GameWidget`** inside `BaseViewScreen`; a dev
  toggle switches between the v1 widget view and the Flame world during build-out.
- World components: **isometric hex grid**, **building** components, **robot**
  components, a **hub/station**, and a Flame **`CameraComponent`** (pan/zoom).
- **The key engineering piece — a Riverpod↔Flame bridge.** Flame is imperative;
  Riverpod is reactive. An adapter watches the providers, **diffs**, and
  adds/removes/updates components (feature added → building; run started → robot
  spawns at the station and walks to its building; `RunPhase` change → animation
  state). Get this right early or the world drifts from reality.
- **Robots = `flame_rive` components** (added in Phase C) with a state machine
  keyed to `RunPhase` (working / done / **awaiting-approval = wave + "!" bubble**).
- **Interaction:** tap robot → open build window; tap building → feature sheet.

## Phased decomposition (each phase independently shippable)

### Phase A — Flame foundation (buildable)
- **A1** — add `flame`; embed an empty `GameWidget` in `BaseViewScreen` behind a
  view toggle. *Verify: renders alongside v1.*
- **A2** — isometric hex grid component + camera pan/zoom; port `BaseLayout` ring
  math to iso coordinates. *Verify: hexes render, pan/zoom works.*
- **A3** — **Riverpod→Flame sync adapter**: features→building components,
  runs→robot components (add/remove/update on state change). *Verify:
  buildings/robots appear and update from real data.*

### Phase B — Robots & interaction (buildable, placeholder art)
- **B1** — robot component (placeholder shape) at its building; state/color by
  `RunPhase`.
- **B2** — tap robot → open build window; tap building → feature sheet.
- **B3** — blocked/awaiting robot → "!" bubble + attention state → click jumps to
  the approval. *(points 5–6)*
- **B4** — walk-out-of-station: new run → robot spawns at hub, walks to its
  building.

### Phase C — Art & polish (manual art + buildable wiring)
- **C1** — add `flame_rive`; Rive robot **with a face** + idle/work/wave/blocked
  state machine.
- **C2** — low-poly building/hex art (per category or metaphor).
- **C3** — station/hub + ambient (trees, etc.).

### Phase D — Stretch (v2.5)
- **D1** — multiple bases = portfolio (zoom out to islands/planets).
- **D2** — drag-a-robot-onto-a-building = reassign (two-way write).

## Risks

- **Flame unfamiliar to Ollama-cloud models** → Claude builds the engine, not
  Build-with-AI.
- **Flame↔Riverpod bridge (A3)** is the hardest engineering — build it early.
- **Art is the gate** — without it, v2 is nicer shapes, not the video.
- **Scale** — the reference had ~78 agents; need culling/pooling for big
  portfolios.
- **New dependency** — `flame` (and later `flame_rive`) must build clean on this
  toolchain (watch the AOT/hook quirks noted in team memory).

## Effort (honest)

- Phase A ~1–2 sessions · Phase B ~2–3 sessions → **playable interactive Flame v2
  with placeholder art in ~4–5 sessions.**
- Phase C art-dependent (days→weeks by sourcing); wiring ~1 session once art
  exists. **Video-fidelity is gated on art, not code.**

## Sequencing

Do **A → B with placeholder shapes first** (prove the game *feels* right), then
spend on art (C). Mechanics before art.
