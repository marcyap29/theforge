import '../interview/state/interview_dimension.dart';
import '../interview/state/interview_state.dart';

String buildSpecPrompt(InterviewState state) {
  final isBuild = state.dimensions == buildDimensions;
  final modeLabel = isBuild ? 'Build' : 'Audit';
  final transcript = state.turns
      .map((t) => '${t.isUser ? "USER" : "INTERVIEWER"}: ${t.content}')
      .join('\n\n');
  final confidenceSummary = state.dimensions
      .map((d) {
        final s = state.confidenceMap[d.id]!;
        final label = switch (s) {
          DimensionState.resolved => 'RESOLVED',
          DimensionState.partial => 'PARTIAL',
          DimensionState.unknown => 'UNKNOWN',
        };
        return '- ${d.label}: $label';
      })
      .join('\n');

  final specStructure =
      isBuild ? _buildSpecStructure : _auditSpecStructure;

  return '''You are The Forge spec writer — a sharp, direct technical architect.

PROJECT: ${state.projectName}
MODE: $modeLabel Interview

INTERVIEW TRANSCRIPT:
$transcript

CONFIDENCE MAP:
$confidenceSummary

Generate a complete $modeLabel Locked Spec following this exact structure. Be specific and concrete — no "TBD", no filler. Every Completion Criterion must be autonomously verifiable by an executor agent. Every Accepted Decision must state what was rejected and why.

$specStructure''';
}

const _buildSpecStructure = '''
## 1. Immutable Goal Statement
[Single sentence: "{AppName} is a {what it does} for {primary user}."]

## 2. Hard Constraints
| Constraint | Value |
|---|---|
| Platform | |
| Framework | |
| Identity model | |
| [any other non-negotiables extracted from the interview] | |

## 3. Component Map
| Component | Responsibility |
|---|---|
| [one row per component — single responsibility each] | |

## 4. Interface Contracts
[For each component from §3: what goes in, what comes out]

## 5. Completion Criteria
| Criterion | Component | How to verify |
|---|---|---|
| [what must be true when the build is done] | [which component] | [exact command or check] |

## 6. Static Content Specs
[Skip this section if no static content — otherwise list copy, images, icons required]

## 7. Explicit Out-of-Scope List
- [each item the user deferred or confirmed is not in v1]

## 8. Accepted Decisions
| Decision | Chosen | Rejected | Reasoning | Confidence |
|---|---|---|---|---|

## 9. Open Flags
| Flag | Component | Options | Recommended default |
|---|---|---|---|

## 10. v2 Architecture Notes
- [seeds for v2 based on deferred items or future signals from the interview]
''';

const _auditSpecStructure = '''
## 1. Project Goal Statement
[What this project is actually trying to do, as established in the audit]

## 2. Current Build State
**Shipped:** [list]
**In progress:** [list]
**Not started:** [list]

## 3. Component and Feature Map
| Component / Feature | Owner | Status |
|---|---|---|

## 4. Active Blocker Registry
| Blocker | Component | Owner | Blocked since | Downstream impact |
|---|---|---|---|---|

## 5. Decision Debt Log
| Decision | What was decided | Documented? | Source | Conflict? |
|---|---|---|---|---|

## 6. Technical Debt Log
| Item | Location | Owner | Notes |
|---|---|---|---|

## 7. AI and Token Usage Summary
[Who uses AI, on what tasks, at what approximate spend]

## 8. Documentation Gaps
- [each place where documentation is missing or contradicted]

## 9. Confidence Map
| Dimension | Level | Notes |
|---|---|---|

## 10. Next Phase Seeds
- [recommended next actions based on what was established]
''';

String buildBulletHandoff(InterviewState state, String specVersion) {
  final isBuild = state.dimensions == buildDimensions;
  final modeLabel = isBuild ? 'Build' : 'Audit';
  final now = DateTime.now();
  final dateStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final resolvedDims = state.dimensions
      .where((d) => state.confidenceMap[d.id] == DimensionState.resolved)
      .map((d) => '- ${d.label}: resolved')
      .join('\n');

  return '''# ${state.projectName} — Bullet Handoff
**Phase:** Interview → Spec Generation
**Interview mode:** $modeLabel
**Date:** $dateStr
**Spec version:** $specVersion
**Completion criteria met:** All ${state.dimensions.length} confidence dimensions resolved; all conflicts resolved

## What Was Decided
$resolvedDims

## What Was Explicitly Deferred
- (see Out-of-Scope list in the locked spec)

## Open Items
- (see Open Flags section in the locked spec)

## What the Next Agent or Session Needs to Know
- Spec is locked and immutable — do not accept scope additions without a new interview
- Setup Worksheet must be complete before executor starts
- All deferred items are v2 seed items — document, do not build
''';
}

String buildAuditEntry(
    String projectName, String specVersion, String provider) {
  final now = DateTime.now().toIso8601String();
  return '\n## $now — Spec Generated\n'
      '- Version: $specVersion\n'
      '- Provider: $provider\n'
      '- Status: locked\n'
      '---\n';
}
