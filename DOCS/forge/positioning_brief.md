# The Forge — Positioning Brief

**SwarmSpace | Enterprise Tier**
Orbital AI · May 2026 · Confidential

-----

> **The Forge is the project manager your AI agents don't have.**

It defines what gets built, locks it, and keeps every agent building against the same spec — from first goal to shipped product, across as many phases as the build takes.

-----

## The Problem

Enterprise teams now have genuinely powerful AI coding agents. Claude Code, Codex, Cursor. The infrastructure to build with AI is no longer the constraint.

There are two constraints nobody has solved.

The first is what happens before the agent touches a codebase. A vague goal fed into a coding agent produces unpredictable output. The agent fills ambiguity with assumptions. Those assumptions compound across a multi-agent run. Per-engineer Claude Code spend runs $150–250/month on average, with heavy users hitting $500–2,000/month. Uber exhausted its entire 2026 AI budget by April, much of it attributed to agents running loops against underdefined tasks. Token costs are not the real problem. Unclear input is.

The second is what happens over time. A multi-week build involves dozens of agent runs, hundreds of decisions, and multiple handoffs between agents. Without a persistent source of truth, each new session re-derives context, re-interprets the goal, and drifts from the original intent. By week three the build no longer reflects what was agreed in week one. There is no audit trail. No record of why decisions were made. No way to resume coherently after a break.

What both problems have in common: there is no project manager.

Coding agents are excellent at execution. They are not designed to manage scope, surface conflicts, lock decisions, or maintain coherence across a long build. That is a product management function and it has been missing from the AI development stack entirely.

The Forge is the PM layer.

-----

## What The Forge Does as Your PM

A good project manager does not just take requirements. They push back on scope, surface conflicts before the team starts building, force prioritization decisions, and produce a written record that everyone works from. The Forge does exactly this, and does it at the start of every build.

**Pushes back on scope.** When a user asks for too much in v1, the interview flags the cost and recommends a tighter scope. It does not silently accept the request.

**Surfaces conflicts.** When two requirements are architecturally incompatible, the interview stops and names the conflict before continuing. Silent resolution is not permitted.

**Forces prioritization.** Every build has a v1 and a v2. The Forge draws that line explicitly, with the user's confirmation, before any code is written.

**Documents decisions with reasoning.** Every choice is recorded: what was chosen, what was rejected, and why.

**Keeps agents on track.** Executor agents run against the locked spec at a low temperature. No creative deviation permitted. Ambiguity is resolved conservatively and flagged.

-----

## Long-Term Coherent Development

**Phase 1:** Interview to 100% confidence. Produce a locked spec. Executor agents build v1 against it.

**Phase 2:** When v1 is near complete, run a new interview. The v2 interview is handed the v1 locked spec, the full audit trail, and every decision made during the v1 build. It does not start from scratch.

**Phase 3 and beyond:** Each phase produces its own locked spec. The source of truth never mutates — it version-bumps through structured interviews.

> A normal AI chat session forgets everything between conversations. The Forge does not. Every phase hands the next one a complete brief.

-----

## The Three Outputs

Every Forge run produces three artifacts. No executor agent starts until all three exist.

| Output | What it is | Who it's for |
|---|---|---|
| **Locked Spec** | Immutable architecture document | Executor agents |
| **Setup Worksheet** | Step-by-step human-action checklist for every external service | The user |
| **Handoff Package** | Structured JSON summary of the run | Next agent or session |

-----

## How It Works

### 1. Interview Phase

Structured goal-setting session. Targeted questions until 100% confidence is reached. A visible confidence meter tracks progress in real time. This is not a form. It is a conversation with a PM who will not let the build start until the brief is tight.

### 2. Monte Carlo Architecture Generation

Three architectural variants generated in parallel at different temperatures:

- **Conservative (t=0.2)** — lowest-risk path, proven patterns
- **Balanced (t=0.6)** — pragmatic tradeoffs
- **Experimental (t=1.0)** — highest-ceiling option

All three complete before any are revealed. The team evaluates them simultaneously.

### 3. Locked Spec

The approved variant generates a machine-readable locked spec. Immutable. Amendments produce a new versioned spec. Nothing is overwritten.

### 4. Executor Phase

Executor agents build against the locked spec at t=0.1. No creative deviation permitted. Ambiguity is resolved conservatively and flagged.

-----

## Competitive Position

| | Claude Code | OpenAI Codex | The Forge |
|---|---|---|---|
| **Layer** | Execution | Execution | Project management |
| **Scope management** | None | None | Core function |
| **Multi-phase coherence** | None | None | Structured resumption |
| **Audit trail** | Limited | Limited | Full run history, versioned |
| **Relationship** | Downstream executor | Downstream executor | Upstream PM layer |

> Teams using Claude Code or Codex get more from those tools when the input is a locked Forge spec.

-----

## Who It Is For

**Tier 1 — AI Dev Shops and Software Studios**
$250k–$500k+ engagements. The Forge runs the discovery and architecture definition phase in a fraction of the time and produces a premium versioned deliverable.

**Tier 2 — Technical Founders (Series A–B)**
Building without a dedicated PM. The interview is the PM pass. The locked spec is what comes out of it.

**Tier 3 — Fractional CTOs and Solution Architects**
Operating across multiple client engagements. The locked spec and full decision trail become a client deliverable.

**Tier 4 — Regulated Verticals (Future)**
Defense, aerospace, legal, pharma. The audit trail and immutable versioning map onto compliance requirements.

-----

## Pricing

| Tier | Price | Includes |
|---|---|---|
| Free | $0/month | Full SwarmSpace tool suite, 20 calls/day |
| Pro | $20/month per user | 500+ calls/day, full SwarmSpace suite |
| **Forge** | **$150/workspace/month + credits** | Everything in Pro, The Forge, up to 10 seats, shared credit pool, full audit trail |

### Credit Reference

| Action | Estimated Credits |
|---|---|
| Full Forge run (interview through locked spec) | 20–35 |
| Single variant generation | 4–6 |
| Executor agent run (per agent) | 8–15 |
| Standard SwarmSpace research call | 1–2 |

Credit top-ups: 500 credits / $25 · 1,500 credits / $60 · 5,000 credits / $150

-----

*The Forge · swarmspace.app · Orbital AI*
*Contact: marcyap@orbitalai.net*
