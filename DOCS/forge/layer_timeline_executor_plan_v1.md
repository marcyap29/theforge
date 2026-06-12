# §UI1 — Layer Sub-Timeline

## Scoped Executor Prompt for DeepSeek V4 Pro

**Feature:** Add a stacked 4-dot sub-row (L1 / L2 / L3 / L4) beneath the "Interview" step in `_PhaseTimeline`. Dots are gray (future), amber-pulse (current), or green (done). Layer state is persisted to disk at each transition so the detail screen can read it without holding interview state in memory.

**Definition of done:** The detail screen shows a 4-dot L1–L4 sub-row below the Interview step. Dots reflect the real persisted layer state. Audit mode shows no sub-row. `dart analyze lib/` → zero issues. Worktree `wt/layer-timeline` ready for review.

---

## ⚠ Branch context

This worktree branches off `wt/interview-funnel`, NOT `main`. That branch added:
- `InterviewState.currentLayer` (string: `'L1'`–`'L4'`, or `''` for Audit)
- `InterviewState.extracted` map
- `buildLayers` constant in `interview_dimension.dart`
- `ProjectFileRepository.writeIngestedFile()`

Do NOT re-add any of those. They already exist in this worktree.

**Merge order:** `wt/layer-timeline` merges AFTER `wt/interview-funnel` lands on `main`. The overseer handles the rebase/merge sequence.

---

## Project Context

- **Stack:** Flutter 3.38.7 / Dart 3.10.7 / Riverpod / local filesystem (no Firebase)
- **Repo root (worktree):** `/Volumes/Marc Working Drive/Development/the-forge-layer-timeline/`
- **Linter:** `dart analyze lib/` — zero warnings required before done

### Existing patterns to match

| Pattern | Where to find it |
|---|---|
| Phase timeline widget | `lib/features/projects/screens/project_detail_screen.dart` — `_PhaseTimeline`, `_TimelineStep`, `_TimelineConnector` |
| `_TimelineStep` dot states | `project_detail_screen.dart:355–432` — gray / amber-pulse / green already implemented |
| RouteAware sidebar refresh | `_FilesSidebarState` in `project_detail_screen.dart` — `RouteAware.didPopNext()` + `setState` pattern |
| Disk write under `ingested/` | `ProjectFileRepository.writeIngestedFile()` — writes named file under `{projectPath}/ingested/` |
| Existing disk read pattern | `ProjectFileRepository.readIngestedSummary()` — null-safe read, returns `null` if file absent |
| Layer definitions | `lib/features/interview/state/interview_dimension.dart` — `buildLayers` const list (L1–L4) |
| `currentLayer` on state | `lib/features/interview/state/interview_state.dart` — `String currentLayer` field |
| Interview notifier | `lib/features/interview/state/interview_notifier.dart` — `_buildFlow()` writes state each turn |

---

## Files to Modify (3 files)

### 1. `lib/data/filesystem/project_file_repository.dart`

Add two methods after `writeIngestedFile`:

```dart
/// Persists the current interview layer to disk.
/// Writes to {projectPath}/audit/{projectName}_InterviewState.json
/// This is an idempotent overwrite — not write-once.
Future<void> writeInterviewProgress(
    String projectPath, String projectName, Map<String, dynamic> data) async {
  final auditDir = Directory(p.join(projectPath, 'audit'));
  final file = File(p.join(auditDir.path, '${projectName}_InterviewState.json'));
  await file.writeAsString(jsonEncode(data));
}

/// Reads persisted interview progress. Returns null if file absent.
Future<Map<String, dynamic>?> readInterviewProgress(
    String projectPath, String projectName) async {
  final file = File(
      p.join(projectPath, 'audit', '${projectName}_InterviewState.json'));
  if (!file.existsSync()) return null;
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } on FormatException {
    return null;
  }
}
```

`jsonEncode`/`jsonDecode` are in `dart:convert` — already imported at the top of this file.

---

### 2. `lib/features/interview/state/interview_notifier.dart`

In `_buildFlow`, after the final `state = AsyncData(withUser.copyWith(...))` call that sets `currentLayer`, add a disk-persist call:

```dart
// Persist layer progress so the detail screen can read it without holding
// interview state in memory (§PERSIST).
await repo.writeInterviewProgress(
  withUser.projectPath,
  withUser.projectName,
  {
    'currentLayer': newLayer,
    'completedLayers': _completedLayers(newLayer),
  },
);
```

Add the helper function at module level (next to `_v2SeedsMarkdown`):

```dart
List<String> _completedLayers(String currentLayer) {
  const order = ['L1', 'L2', 'L3', 'L4'];
  final idx = order.indexOf(currentLayer);
  if (idx <= 0) return const [];
  return order.sublist(0, idx);
}
```

The `repo` variable is already in scope in `_buildFlow` — it's the same `ref.read(projectFileRepositoryProvider)` call at the top of that method. No new imports needed.

**Important:** The write happens AFTER the `state = AsyncData(...)` update — do not reorder.

**Also important:** Do NOT add this write to `_auditFlow`. Audit mode has no layers; writing an empty layer file would confuse the detail screen reader.

---

### 3. `lib/features/projects/screens/project_detail_screen.dart`

Three additions to this file.

#### 3a. Wrap `_PhaseTimeline` in a `FutureBuilder` that loads layer progress on mount

`_PhaseTimeline` is currently a `StatefulWidget` reading only `project` (sync, from drift). It needs to additionally load the async `InterviewProgress` JSON on mount and on `didPopNext`.

**Do not convert `_PhaseTimeline` into a `ConsumerWidget`.** Keep it a `StatefulWidget`. Load the progress file in `initState` + `didPopNext` via a `FutureBuilder` or a local `_progress` state field.

Preferred pattern — local async state field (matches `_FilesSidebarState`):

```dart
class _PhaseTimelineState extends State<_PhaseTimeline>
    with SingleTickerProviderStateMixin, RouteAware {

  // ... existing _pulseCtrl and _pulseOpacity fields ...

  Map<String, dynamic>? _progress;  // null = file absent or not yet loaded

  @override
  void initState() {
    super.initState();
    // ... existing animation setup ...
    _loadProgress();
  }

  @override
  void didPopNext() => _loadProgress();  // refresh when interview screen pops

  void _loadProgress() {
    final repo = ProjectFileRepository();
    repo
        .readInterviewProgress(widget.project.path, widget.project.name)
        .then((data) {
      if (mounted) setState(() => _progress = data);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register with routeObserver — same pattern as _FilesSidebarState
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ...
}
```

`routeObserver` is already a top-level `RouteObserver<ModalRoute<void>>` registered in `lib/core/app.dart`. It is already imported/used by `_FilesSidebarState` in this same file — check how `_FilesSidebarState` references it and match exactly.

#### 3b. Pass `_progress` to the Interview step's child

In `_PhaseTimelineState.build`, after building the Interview `_TimelineStep`, add the sub-row conditionally:

```dart
// Interview step column — wrap in a Column so the sub-row stacks below it
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisSize: MainAxisSize.min,
  children: [
    _TimelineStep(
      label: 'Interview',
      isDone: interviewDone,
      isCurrent: !interviewDone,
      pulseOpacity: _pulseOpacity,
      onTap: /* existing onTap unchanged */,
    ),
    if (!interviewDone || _progress != null)   // show when in-progress OR complete
      _LayerSubRow(
        progress: _progress,
        interviewDone: interviewDone,
        pulseOpacity: _pulseOpacity,
      ),
  ],
),
```

Replace the bare `_TimelineStep(label: 'Interview', ...)` in the existing `Row(children: [...])` with this `Column`.

#### 3c. Add `_LayerSubRow` widget

Add this widget to the file, after `_TimelineStep`:

```dart
class _LayerSubRow extends StatelessWidget {
  const _LayerSubRow({
    required this.progress,
    required this.interviewDone,
    required this.pulseOpacity,
  });

  final Map<String, dynamic>? progress;
  final bool interviewDone;
  final Animation<double> pulseOpacity;

  @override
  Widget build(BuildContext context) {
    const layers = ['L1', 'L2', 'L3', 'L4'];

    // Derive state from persisted progress
    final currentLayer = progress?['currentLayer'] as String?;
    final completed = (progress?['completedLayers'] as List<dynamic>?)
            ?.cast<String>() ??
        <String>[];

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < layers.length; i++) ...[
            _LayerDot(
              label: layers[i],
              isDone: interviewDone || completed.contains(layers[i]),
              isCurrent: !interviewDone && currentLayer == layers[i],
              pulseOpacity: pulseOpacity,
            ),
            if (i < layers.length - 1)
              Container(
                width: 12,
                height: 1,
                margin: const EdgeInsets.only(bottom: 10),
                color: (interviewDone || completed.contains(layers[i]))
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF2C2C2E),
              ),
          ],
        ],
      ),
    );
  }
}

class _LayerDot extends StatelessWidget {
  const _LayerDot({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.pulseOpacity,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final Animation<double> pulseOpacity;

  @override
  Widget build(BuildContext context) {
    // Three states — match _TimelineStep color scheme exactly:
    //   done    → green check (Color 0xFF22C55E), size 12
    //   current → amber pulsing dot (Color 0xFFE8A04C), size 12
    //   future  → gray hollow circle (border Color 0xFF3D4452), size 12
    Widget dot;
    Color labelColor;

    if (isDone) {
      dot = const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 12);
      labelColor = const Color(0xFF22C55E);
    } else if (isCurrent) {
      dot = FadeTransition(
        opacity: pulseOpacity,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8A04C),
          ),
        ),
      );
      labelColor = const Color(0xFFE8A04C);
    } else {
      dot = Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3D4452), width: 1.0),
        ),
      );
      labelColor = const Color(0xFF4B5563);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontFamily: 'Menlo',
            letterSpacing: 0.3,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
```

**Audit mode:** `_LayerSubRow` should NOT render for Audit projects. In `_PhaseTimelineState.build`, gate the sub-row on `mode == ProjectMode.build`:

```dart
if (mode == ProjectMode.build && (!interviewDone || _progress != null))
  _LayerSubRow( ... ),
```

`mode` is already computed in `build()` (line 258 of the original file). No extra logic needed.

---

## Filesystem Details

| File | Path |
|---|---|
| Interview progress (written per turn) | `{projectPath}/audit/{projectName}_InterviewState.json` |
| JSON shape | `{ "currentLayer": "L3", "completedLayers": ["L1", "L2"] }` |

Written in `audit/` rather than `ingested/` because:
- `audit/` already exists for every project (created in `createProject`)
- `ingested/` is for reference doc inputs; this is process state
- Writing to `audit/` costs nothing and survives if `ingested/` is ever cleaned

The file is **idempotent overwrite** — not write-once. Every layer transition replaces it.

---

## Key Invariants (do not break)

- `dart analyze lib/` zero warnings before reporting done.
- No Firebase imports (`grep -ri firebase lib/` returns nothing).
- **Audit mode: no sub-row, no disk write.** The `writeInterviewProgress` call is gated to `_buildFlow` only; `_auditFlow` is untouched.
- `_PhaseTimeline` stays a `StatefulWidget` — do not convert to `ConsumerWidget`.
- The sub-row uses the same `_pulseOpacity` animation from `_PhaseTimelineState` — do not create a second `AnimationController`.
- The existing `_TimelineStep`, `_TimelineConnector`, colors, and Menlo font are unchanged — `_LayerDot` is a smaller-scale variant of `_TimelineStep`, not a replacement.
- `writeInterviewProgress` writes to `audit/` — that directory always exists. Do NOT call `auditDir.create()` — it already exists and trying to create it throws if it's already there. Write to the file directly.
- `readInterviewProgress` returns `null` on absent file or malformed JSON — never throws. The UI must handle `_progress == null` gracefully (sub-row shows all-gray when null).

---

## Out of Scope

- No tapping L-dots (no navigation on tap — they are display-only).
- No tooltip/hover label showing the layer purpose (future pass).
- No changes to `InterviewScreen` UI.
- No changes to the Audit interview flow.
- No changes to Worksheet or Ready steps.
- No new Riverpod providers — the progress is read via a plain `ProjectFileRepository()` instantiation in `_loadProgress`, same as `_FilesSidebarState` pattern.
- No database schema changes.

---

## File Read Order (recommended)

Before editing, read these in order:

1. `lib/features/projects/screens/project_detail_screen.dart` — full file; understand `_FilesSidebarState.didPopNext()` and `routeObserver` usage before writing the RouteAware subscription
2. `lib/data/filesystem/project_file_repository.dart` — confirm `audit/` dir creation in `createProject()`, and the end of the file where `writeIngestedFile` was added
3. `lib/features/interview/state/interview_notifier.dart` — find the end of `_buildFlow` where the final `state = AsyncData(...)` is written; insert the `writeInterviewProgress` call immediately after
4. `lib/features/interview/state/interview_dimension.dart` — confirm `buildLayers` is already there (it is — do not re-add)
5. `lib/core/app.dart` — confirm `routeObserver` is declared there; note the exact variable name

---

## Verification Checklist

```bash
cd "/Volumes/Marc Working Drive/Development/the-forge-layer-timeline"
dart analyze lib/                         # zero issues required
grep -ri firebase lib/                    # zero matches
grep -rn "writeInterviewProgress" lib/    # should appear in project_file_repository.dart + interview_notifier.dart only
git diff --stat wt/interview-funnel..HEAD # should show 3 files only
git status --short                        # must be empty
```

Runtime smoke (manual — overseer runs this):
1. Open worktree app, create a fresh Build project "LayerTest".
2. Start the interview. After the first user message, the detail screen should show L1 as amber-pulsing.
3. Walk to L3. L1 and L2 dots should be green, L3 amber, L4 gray.
4. After the full interview completes, all 4 dots should be green.
5. Create an Audit project "AuditTest". Confirm no sub-row appears beneath Interview.

---

## Branch Hygiene

- Branch: `wt/layer-timeline` (already created off `wt/interview-funnel`)
- Commit message convention: `feat(§UI1): <what>`
- Do not commit `pubspec.lock` unless dependencies changed (they should not).
- Do not merge to `main` directly — overseer merges `wt/interview-funnel` first, then rebases this branch.

---

*Plan written: 2026-06-12 · Ready for handoff to DeepSeek V4 Pro · Worktree: `wt/layer-timeline`*
*Branches off: `wt/interview-funnel` (c83fc5a)*
