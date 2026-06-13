# §FM1 — Feature Interview Mode (V2, V3, …)

## Scoped Executor Prompt for DeepSeek V4 Pro

**Feature:** Add a Feature Interview mode that lets a user run a V2, V3, … interview against an existing project. The interview uses the same 4-layer Build funnel but pre-loads the prior locked spec and V2 seeds as context, so the LLM knows what was already built and what was deferred. Each version produces its own set of artifacts with the correct version number. A "Start V2 Interview →" button appears on the project detail screen once V1 is complete.

**Definition of done:** A completed V1 project shows a "Start V2 Interview →" button. Tapping it runs a Build-funnel interview with the prior spec and seeds injected into the system prompt. Completing the interview generates `_LockedSpec_v2.md` and matching artifacts. The phase timeline and CTA update correctly through the V2 cycle. `dart analyze lib/` → zero issues. Worktree `wt/feature-mode` ready for review.

---

## Project Context

- **Stack:** Flutter 3.38.7 / Dart 3.10.7 / Riverpod / local filesystem (no Firebase)
- **Repo root (worktree):** `/Volumes/Marc Working Drive/Development/the-forge-feature-mode/`
- **Worktree branch:** `wt/feature-mode` (off `main`)
- **Linter:** `dart analyze lib/` — zero warnings required before done

### Existing patterns to match

| Pattern | Where |
|---|---|
| `InterviewArgs` (family key) | `lib/features/interview/providers/interview_providers.dart` |
| `InterviewState` + `copyWith` | `lib/features/interview/state/interview_state.dart` |
| `_buildInterviewSystemPrompt` | `lib/features/interview/state/interview_notifier.dart` |
| `InterviewNotifier.build()` | `lib/features/interview/state/interview_notifier.dart:343` |
| `spec_notifier.generate()` | `lib/features/spec_generation/spec_notifier.dart:30` |
| `worksheet_notifier.generate()` | `lib/features/spec_generation/worksheet_notifier.dart:25` |
| Phase-aware CTA switch | `lib/features/projects/screens/project_detail_screen.dart` — `_buildCta()` |
| `_PhaseTimeline` phase checks | `project_detail_screen.dart:287-289` |
| Project mode badge | `project_detail_screen.dart:77-88` |

---

## Design Decisions (locked — do not deviate)

1. **No new `ProjectMode` enum value.** Feature interviews use `ProjectMode.build`. The feature trigger is `InterviewArgs.priorSpecVersion != null`. The project's DB `mode` column stays `build` and is never changed by a feature interview.

2. **Same project folder, new spec version.** V2 artifacts sit alongside V1 in the same project folder. The folder is not recreated. `writeLockedSpec` is already write-once per version (it checks file existence) — rely on that.

3. **First pass: pre-loaded context, same funnel.** The Feature interview runs the exact same L1→L4 funnel as V1 Build. The difference is the system prompt — it injects the prior spec and V2 seeds so the LLM knows the context. Abbreviated L1/L2 logic is deferred to a future pass.

4. **Phase strings are version-prefixed:** `v1_interview`, `v1_spec_locked`, `v1_worksheet_complete`, `v2_interview`, `v2_spec_locked`, `v2_worksheet_complete`, etc. All phase logic uses helpers `_stageOf(phase)` and `_versionOf(phase)` to avoid a long chain of hardcoded string checks.

5. **Only V1→V2 CTA is in scope.** The "Start V3 Interview" CTA (from `v2_worksheet_complete`) follows the same pattern and can be added in a second pass. For now, the "Start V{n+1} Interview" button is shown for ANY `worksheet_complete` phase so it works generically.

---

## Files to Modify (9 files)

### 1. `lib/features/interview/providers/interview_providers.dart`

Add `priorSpecVersion: String?` to `InterviewArgs`. Update `==` and `hashCode`.

```dart
@immutable
class InterviewArgs {
  final String path;
  final String name;
  final ProjectMode mode;
  final String? priorSpecVersion;  // null = V1 Build; non-null = Feature interview

  const InterviewArgs({
    required this.path,
    required this.name,
    required this.mode,
    this.priorSpecVersion,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterviewArgs &&
          other.path == path &&
          other.name == name &&
          other.mode == mode &&
          other.priorSpecVersion == priorSpecVersion);

  @override
  int get hashCode => Object.hash(path, name, mode, priorSpecVersion);
}
```

---

### 2. `lib/features/interview/state/interview_state.dart`

Add `featureContext: String?` to `InterviewState`. This is loaded once in `InterviewNotifier.build()` and never changes during the interview.

**(a)** Add field:
```dart
final String? featureContext;  // non-null for Feature interviews; loaded from disk in build()
```

**(b)** Update constructor — add `this.featureContext,` as an optional named param (nullable, so no `required`).

**(c)** Update `InterviewState.empty()` factory — add `featureContext: null,` to the constructor call.

**(d)** Update `copyWith` — add `String? featureContext` param and `featureContext: featureContext ?? this.featureContext,` in the return.

---

### 3. `lib/features/interview/state/interview_notifier.dart`

Three changes:

#### 3a. `InterviewNotifier.build()` — load feature context when `priorSpecVersion != null`

The family arg is `args` (`this.arg` in `FamilyAsyncNotifier`). Add this block at the top of `build()`, before constructing the empty state:

```dart
@override
Future<InterviewState> build(InterviewArgs args) async {
  final dims = dimensionsFor(args.mode);

  String? featureContext;
  if (args.priorSpecVersion != null) {
    final repo = ref.read(projectFileRepositoryProvider);
    featureContext = await repo.readFeatureContext(
      args.path,
      args.name,
      args.priorSpecVersion!,
    );
  }

  return InterviewState.empty(args.path, args.name, dims)
      .copyWith(featureContext: featureContext);
}
```

Note: `InterviewState.empty()` returns a state with all defaults. `.copyWith(featureContext: featureContext)` overlays the loaded context. This is correct because `empty()` initializes `featureContext: null`.

#### 3b. Add `_featureInterviewSystemPrompt` function (module level, near `_buildInterviewSystemPrompt`)

```dart
String _featureInterviewSystemPrompt(InterviewState state,
    {String? ingestedContext, required String priorSpecVersion}) {
  final nextVersion = _nextSpecVersion(priorSpecVersion);

  final refBlock = ingestedContext != null
      ? '\n\nREFERENCE CONTEXT:\n'
          'The following was extracted from reference documents provided by the user. '
          'Use it to inform your questions but do not treat it as binding — '
          'surface any tensions between the reference material and the user\'s answers.\n\n'
          '$ingestedContext\n'
      : '';

  final contextBlock = state.featureContext != null
      ? '\n\nFEATURE CONTEXT — READ BEFORE ASKING ANYTHING:\n'
          'You are running a Feature Interview to scope $nextVersion.\n'
          'The prior spec and deferred features are below. '
          'Use them so you do not re-ask questions already answered in $priorSpecVersion.\n\n'
          '${state.featureContext}\n'
      : '';

  final extractedJson =
      const JsonEncoder.withIndent('  ').convert(state.extracted);

  return '''You are The Forge interviewer — a sharp, direct product architect
running a Feature Interview for a project called "${state.projectName}".
You are scoping $nextVersion. $priorSpecVersion is already shipped.
$refBlock$contextBlock
THE FUNNEL — you are currently at ${state.currentLayer}. Do not advance until
the exit condition is met. Never ask about a later layer early.

L1 OUTCOME REFRAME (keep this short — 1-2 turns maximum):
The core outcome and user from $priorSpecVersion are already known (see FEATURE CONTEXT above).
Ask: "Given $priorSpecVersion is live, what is the ONE next capability that makes it
more valuable for [user]?" Confirm or adjust the outcome and user quickly, then exit L1.
Exit: outcome and primary user confirmed.

L2 DECOMPOSITION:
The V2 Seeds in the FEATURE CONTEXT are your capability menu. Present the most
relevant 3-5 seeds as candidates. Push back if the user wants something outside
the seeds (ask why it belongs in $nextVersion). Hard cap at 5. Exit: confirmed list.

L3 POC REDUCTION:
Same as $priorSpecVersion: one sub-capability, 3-5 step demo script.
Every seed not chosen and every feature mentioned but absent from the demo goes
on the $nextVersion seed list. Read the seed list back for confirmation.
Exit: capability chosen, demo confirmed, seeds confirmed.

L4 CRITICAL PATH (INCREMENTAL — key difference from $priorSpecVersion):
Most architecture is inherited. Ask ONLY about what changes:
- Which $priorSpecVersion components does this feature touch?
- What is new — not in $priorSpecVersion at all?
- Identity/platform/input/output: inherit from $priorSpecVersion unless the
  demo implies a change. Only ask if the demo requires something different.
Run the blocker scan. Draft the 1-3 step sequence to a working demo.
Exit: incremental changes confirmed, blocker scan done.

STATE SO FAR (cumulative extracted map — re-emit every field every turn):
$extractedJson

RULES
- Ask ONE question per turn. Acknowledge the answer first. Be concise.
- The $priorSpecVersion locked spec is immutable. Never suggest modifying it.
- When the user mentions a feature not in the seeds, acknowledge it, add it
  to the $nextVersion seed list, and return to the current layer's question.
- One new feature per version. If the user wants two, pick one and defer.
- When answers conflict: "Your answers on [X] and [Y] pull in opposite
  directions. [X] implies [A]. [Y] implies [B]. I recommend [conservative
  option] for $nextVersion because [reason]. Do you accept this scope?"

After EVERY response, append a fenced forge-state block. MANDATORY every turn.
Emit the FULL extracted map each turn (cumulative, not deltas):

\`\`\`forge-state
{
  "layer": "${state.currentLayer}",
  "layerComplete": false,
  "extracted": { ... full map ... },
  "conflicts": []
}
\`\`\`

Set layerComplete: true only when the current layer exit condition is met.''';
}
```

Add a small helper at module level (near `_completedLayers`):

```dart
String _nextSpecVersion(String current) {
  if (current.startsWith('v')) {
    final n = int.tryParse(current.substring(1));
    if (n != null) return 'v${n + 1}';
  }
  return 'v2';
}
```

#### 3c. Update `_interviewSystemPrompt` to route to the feature prompt

```dart
String _interviewSystemPrompt(InterviewState state,
    {String? ingestedContext, String? priorSpecVersion}) {
  final isBuild = state.dimensions == buildDimensions;
  if (!isBuild) {
    return _auditInterviewSystemPrompt(state, ingestedContext: ingestedContext);
  }
  if (priorSpecVersion != null) {
    return _featureInterviewSystemPrompt(state,
        ingestedContext: ingestedContext,
        priorSpecVersion: priorSpecVersion);
  }
  return _buildInterviewSystemPrompt(state, ingestedContext: ingestedContext);
}
```

#### 3d. Pass `priorSpecVersion` through `_buildFlow` calls

In `_buildFlow`, `_auditFlow`, both retry calls, and the `_interviewSystemPrompt` calls, thread `priorSpecVersion: arg.priorSpecVersion` through. `arg` (the family parameter) is accessible as a field on `FamilyAsyncNotifier`.

In `addUserMessage()`, the existing split on `isBuild` stays. In `_buildFlow`, change every `_interviewSystemPrompt(withUser, ingestedContext: ingestedContext)` call to:
```dart
_interviewSystemPrompt(withUser,
    ingestedContext: ingestedContext,
    priorSpecVersion: arg.priorSpecVersion)
```

There are three such call sites in `_buildFlow` (initial call, retry call, parseDegraded retry). Update all three.

---

### 4. `lib/features/interview/ui/interview_screen.dart`

The "Generate Spec" button currently pushes `SpecGenerationScreen(interviewState: interviewState)`. Change it to also pass `targetSpecVersion`:

```dart
if (state.specGenEnabled)
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        icon: const Icon(Icons.auto_awesome),
        label: Text(args.priorSpecVersion != null
            ? 'Generate ${_nextSpecVersion(args.priorSpecVersion!)} Spec'
            : 'Generate Spec'),
        onPressed: () {
          final interviewState =
              ref.read(interviewProvider(args)).valueOrNull;
          if (interviewState == null) return;
          final targetVersion = args.priorSpecVersion != null
              ? _nextSpecVersion(args.priorSpecVersion!)
              : 'v1';
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SpecGenerationScreen(
                interviewState: interviewState,
                targetSpecVersion: targetVersion,
              ),
            ),
          );
        },
      ),
    ),
  ),
```

`_nextSpecVersion` is a top-level function in `interview_notifier.dart`. Import it — OR duplicate the one-liner inline (it's simple enough). Your call; avoid import cycles. Check whether `interview_notifier.dart` is already imported in `interview_screen.dart` — if so, use it directly.

**Check the imports in `interview_screen.dart` first** — it imports `interview_providers.dart` already. `_nextSpecVersion` is in `interview_notifier.dart` which is NOT imported in the screen. The cleanest solution: add a public top-level function `nextSpecVersion(String current)` to `interview_notifier.dart` (rename the private one, or add a public wrapper). OR duplicate the one-liner inline in the screen file. Your call.

---

### 5. `lib/features/spec_generation/spec_generation_screen.dart`

Add `targetSpecVersion` parameter:

```dart
class SpecGenerationScreen extends ConsumerStatefulWidget {
  const SpecGenerationScreen({
    super.key,
    required this.interviewState,
    this.targetSpecVersion = 'v1',   // default preserves backward compat
  });
  final InterviewState interviewState;
  final String targetSpecVersion;
```

In `initState`, pass it through:
```dart
ref.read(specNotifierProvider.notifier)
    .generate(widget.interviewState, targetSpecVersion: widget.targetSpecVersion);
```

In `_DoneBody` construction, the `specVersion` for `WorksheetGenerationScreen` comes from `state.specVersion`. That still works — `spec_notifier` stores the version in `SpecGenState.specVersion`. No change needed at this call site.

---

### 6. `lib/features/spec_generation/spec_notifier.dart`

Change `generate()` to accept `targetSpecVersion`:

```dart
Future<void> generate(InterviewState interviewState,
    {String targetSpecVersion = 'v1'}) async {
  if (state.status == SpecGenStatus.generating) return;
  state = const SpecGenState(status: SpecGenStatus.generating);

  final specVersion = targetSpecVersion;  // replace `const specVersion = 'v1'`
  // ... rest unchanged ...
```

Also update the phase string — currently hardcoded to `'v1_spec_locked'`:
```dart
// Before:
await db.updateProjectPhase(projectName, 'v1_spec_locked', specVersion);

// After:
await db.updateProjectPhase(projectName, '${specVersion}_spec_locked', specVersion);
```

Also update `_updateReadme` — it hardcodes `v1_spec_locked` in the replacement string:
```dart
String _updateReadme(String current, String specVersion) {
  return current
      .replaceFirst(RegExp(r'\*\*Current phase:\*\*.*'),
          '**Current phase:** ${specVersion}_spec_locked')
      // ... rest unchanged
```

---

### 7. `lib/features/spec_generation/worksheet_notifier.dart`

Currently hardcodes `'v1_worksheet_complete'`. Make it version-aware:

```dart
// Before:
await ref.read(forgeDatabaseProvider).updateProjectPhase(
      projectName,
      'v1_worksheet_complete',
      specVersion,
    );

// After:
await ref.read(forgeDatabaseProvider).updateProjectPhase(
      projectName,
      '${specVersion}_worksheet_complete',
      specVersion,
    );
```

Also update `_updateReadme`-style logic if present. Check the method — the README update is in `worksheet_notifier.dart` and uses a literal string. Find `v1_worksheet_complete` or `'Setup worksheet:' Complete` references and make them version-neutral or pass `specVersion` through.

---

### 8. `lib/features/projects/screens/project_detail_screen.dart`

Three changes to this file:

#### 8a. Add phase helper functions (module level, before `_PhaseTimeline`)

```dart
// Extract version prefix: 'v1_interview' → 'v1', 'v2_spec_locked' → 'v2'
String _versionOf(String phase) {
  final idx = phase.indexOf('_');
  return idx > 0 ? phase.substring(0, idx) : 'v1';
}

// Extract stage: 'v1_interview' → 'interview', 'v2_spec_locked' → 'spec_locked'
String _stageOf(String phase) {
  final idx = phase.indexOf('_');
  return idx > 0 ? phase.substring(idx + 1) : phase;
}

// Derive next version string: 'v1' → 'v2', 'v2' → 'v3'
String _nextVersion(String current) {
  if (current.startsWith('v')) {
    final n = int.tryParse(current.substring(1));
    if (n != null) return 'v${n + 1}';
  }
  return 'v2';
}
```

#### 8b. Update `_ctaSectionLabel` and `_buildCta` to use stage helpers

```dart
String _ctaSectionLabel(String phase) => switch (_stageOf(phase)) {
      'spec_locked' => 'NEXT STEP',
      'worksheet_complete' => 'STATUS',
      _ => 'INTERVIEW',
    };
```

For `_buildCta`, replace the phase string switch with a stage-based switch:

```dart
Widget _buildCta(
    BuildContext context, Project live, ProjectMode mode, String sv) {
  final stage = _stageOf(live.phase);
  final version = _versionOf(live.phase);

  return switch (stage) {
    'spec_locked' => FilledButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WorksheetGenerationScreen(
            projectPath: live.path,
            projectName: live.name,
            specVersion: sv,
          ),
        )),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE8A04C),
          foregroundColor: const Color(0xFF0F0F10),
        ),
        child: const Text(
          'Generate Setup Worksheet →',
          style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
        ),
      ),
    'worksheet_complete' => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✓ Ready badge (existing green container)
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF22C55E)),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF22C55E), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    '${version.toUpperCase()} ready for executor',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Menlo',
                      color: Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Start next version interview (Build mode only)
          if (mode == ProjectMode.build) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InterviewScreen(
                      args: InterviewArgs(
                        path: live.path,
                        name: live.name,
                        mode: ProjectMode.build,
                        priorSpecVersion: version,  // e.g. 'v1'
                      ),
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE8A04C)),
                  foregroundColor: const Color(0xFFE8A04C),
                ),
                child: Text(
                  'Start ${_nextVersion(version).toUpperCase()} Interview →',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Menlo',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    _ => FilledButton(
        // Default: start/continue current-version interview
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InterviewScreen(
              args: InterviewArgs(
                path: live.path,
                name: live.name,
                mode: mode,
                // priorSpecVersion is null for v1_interview
              ),
            ),
          ),
        ),
        // ... existing style unchanged ...
        child: Text(
          version == 'v1'
              ? 'Start Build Interview'
              : 'Continue ${version.toUpperCase()} Interview',
          // ... existing style ...
        ),
      ),
  };
}
```

Read the current `_buildCta` method carefully before rewriting — keep the existing button style exactly. Only the logic and label change.

#### 8c. Update `_PhaseTimeline` to use stage helpers

In `_PhaseTimelineState.build()`, replace the hardcoded phase checks:

```dart
// Before:
final interviewDone = pj.phase != 'v1_interview';
final worksheetDone = pj.phase == 'v1_worksheet_complete';
final worksheetCurrent = pj.phase == 'v1_spec_locked';

// After:
final stage = _stageOf(pj.phase);
final interviewDone = stage != 'interview';
final worksheetDone = stage == 'worksheet_complete';
final worksheetCurrent = stage == 'spec_locked';
```

Also update the mode badge in `ProjectDetailScreen.build()`:

```dart
// Before:
Text(isBuild ? 'BUILD INTERVIEW' : 'AUDIT INTERVIEW')

// After:
final version = _versionOf(live.phase);
final versionSuffix = version == 'v1' ? '' : ' — ${version.toUpperCase()}';
Text(isBuild ? 'BUILD INTERVIEW$versionSuffix' : 'AUDIT INTERVIEW')
```

Also update the artifact open call in `_PhaseTimeline._openArtifact` for the Interview step. Currently it opens `_LockedSpec_$sv.md` — `sv` comes from `pj.specVersion ?? 'v1'`. This is already correct since `specVersion` in the DB is always the latest locked spec version. No change needed here.

---

### 9. `lib/data/filesystem/project_file_repository.dart`

Add `readFeatureContext` method:

```dart
/// Reads the prior locked spec and V2 seeds for a Feature interview.
/// Returns a formatted context block, or null if neither file exists.
Future<String?> readFeatureContext(
    String projectPath, String projectName, String priorSpecVersion) async {
  final specFile = File(p.join(
      projectPath, 'specs', '${projectName}_LockedSpec_$priorSpecVersion.md'));
  final seedsFile = File(p.join(
      projectPath, 'ingested', '${projectName}_V2Seeds.md'));

  final specContent =
      specFile.existsSync() ? await specFile.readAsString() : null;
  final seedsContent =
      seedsFile.existsSync() ? await seedsFile.readAsString() : null;

  if (specContent == null && seedsContent == null) return null;

  final parts = <String>[];
  if (specContent != null) {
    parts.add('PRIOR LOCKED SPEC ($priorSpecVersion — immutable):\n$specContent');
  }
  if (seedsContent != null) {
    parts.add('V2 SEEDS (features deferred from $priorSpecVersion):\n$seedsContent');
  }
  return parts.join('\n\n---\n\n');
}
```

---

## Filesystem Details

| Artifact | Path (V2 example) |
|---|---|
| Locked Spec v2 | `{projectPath}/specs/{projectName}_LockedSpec_v2.md` |
| Bullet Handoff v2 | `{projectPath}/handoffs/{projectName}_BulletHandoff_v2_Interview.md` |
| /goal v2 | `{projectPath}/handoffs/{projectName}_goal_v2.md` |
| Handoff Package v2 | `{projectPath}/handoffs/{projectName}_HandoffPackage_v2.json` |
| Setup Worksheet v2 | `{projectPath}/worksheets/{projectName}_SetupWorksheet_v2.md` |
| V{n+1} Seeds | `{projectPath}/ingested/{projectName}_V2Seeds.md` (overwritten at L3) |

All existing V1 files are untouched. `writeLockedSpec` already throws `SpecAlreadyExistsException` if the file exists — this is the correct guard.

---

## Key Invariants (do not break)

- `dart analyze lib/` zero warnings before done.
- No Firebase imports.
- V1 artifacts are immutable — no code path may overwrite them.
- `priorSpecVersion == null` → exact same behavior as today (V1 Build interview). All existing tests and flows unchanged.
- `InterviewNotifier.build()` is `async` — the feature context disk read is safe there.
- The `featureContext` field on `InterviewState` is set once in `build()` and never updated by `copyWith` during the interview — treat it as read-only after initialization.
- Phase strings for V2+ must follow the `v{n}_{stage}` pattern exactly: `v2_interview`, `v2_spec_locked`, `v2_worksheet_complete`. Other patterns will break the `_stageOf`/`_versionOf` helpers.

---

## Out of Scope

- `new_project_screen.dart` — Feature interviews are launched from `ProjectDetailScreen`. No Feature card in the new-project flow.
- V2 seeds file naming — the seeds file is always `{projectName}_V2Seeds.md` regardless of version. In a future pass it can become `{projectName}_V{n+1}Seeds.md`.
- Abbreviated L1/L2 funnel for feature interviews — deferred to §FM2. The current pass uses the full 4-layer funnel with prior context.
- Audit Interview versioning — Audit projects do not get a "Start V2" button. The `if (mode == ProjectMode.build)` gate handles this.
- The `GenerationPhaseBar` in generation screens — it shows `Interview → Spec → Worksheet → Ready`. For V2, these labels stay the same; the bar is still correct for the V2 generation cycle. A "V2" label enhancement is deferred.

---

## File Read Order (before editing)

1. `lib/features/interview/providers/interview_providers.dart`
2. `lib/features/interview/state/interview_state.dart`
3. `lib/features/interview/state/interview_notifier.dart` — read the full file; note all `_interviewSystemPrompt` call sites in `_buildFlow`
4. `lib/features/interview/ui/interview_screen.dart` — note the Generate Spec button and its imports
5. `lib/features/spec_generation/spec_notifier.dart`
6. `lib/features/spec_generation/spec_generation_screen.dart`
7. `lib/features/spec_generation/worksheet_notifier.dart`
8. `lib/features/projects/screens/project_detail_screen.dart` — read all of `_buildCta`, `_ctaSectionLabel`, `_PhaseTimelineState.build()`
9. `lib/data/filesystem/project_file_repository.dart` — skim for existing read methods to match the new `readFeatureContext` style

---

## Verification Checklist

```bash
cd "/Volumes/Marc Working Drive/Development/the-forge-feature-mode"
dart analyze lib/                          # zero issues required
grep -ri firebase lib/                     # zero matches
grep -rn "v1_worksheet_complete" lib/      # should return zero (replaced by stage helpers)
grep -rn "v1_spec_locked" lib/             # should return zero
grep -rn "v1_interview" lib/               # should return zero
git diff --stat main..HEAD                 # should show 9 files only
git status --short                         # must be empty
```

Runtime smoke (manual — overseer runs this):
1. Open an existing completed project (Forkit — `phase = v1_worksheet_complete`). Confirm "V1 READY FOR EXECUTOR" green badge + "Start V2 Interview →" amber outlined button both appear.
2. Tap "Start V2 Interview →". Confirm the interview screen opens, appBar says "Build Interview — Forkit", and the funnel layer strip shows L1 current.
3. Check the system prompt content — the FEATURE CONTEXT block should appear with the Forkit V1 spec and V2 seeds (if V2Seeds.md exists).
4. Walk through one layer. Confirm `currentLayer` advances normally.
5. Complete the interview. Tap "Generate V2 Spec". Confirm `_LockedSpec_v2.md` appears in the SPECS sidebar.
6. Confirm the project phase updates to `v2_spec_locked` and the CTA shows "Generate Setup Worksheet →".
7. Open an Audit project. Confirm no "Start V2 Interview" button appears.

---

## Self-Correction Checklist

Before reporting done, verify:
- `arg` (the family parameter on `FamilyAsyncNotifier`) is accessible in `InterviewNotifier` methods as `arg` (not `args`). Check the existing `build(InterviewArgs args)` signature — `args` is the build parameter; in other methods, use `arg` (the Riverpod `FamilyAsyncNotifier` property).
- In `_buildFlow`, `arg.priorSpecVersion` is the correct access path. Verify by checking how `withUser.currentLayer` etc. are read (those come from `withUser`, the state snapshot) vs. `arg.priorSpecVersion` (from the family key).
- The `_nextSpecVersion` / `_nextVersion` helpers appear in two places (notifier + detail screen). They are identical. Do not import across layers — duplicate the trivial one-liner in each file. Import cycles between `interview_notifier.dart` and `project_detail_screen.dart` are not worth a shared util file.

---

## Branch Hygiene

- Branch: `wt/feature-mode` (already created off `main`)
- Commit convention: `feat(§FM1): <what>`
- Do not merge to `main` — overseer merges after review

---

*Plan written: 2026-06-12 · Ready for handoff to DeepSeek V4 Pro · Worktree: `wt/feature-mode`*
