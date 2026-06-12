import '../interview/state/interview_dimension.dart';
import '../interview/state/interview_state.dart';

String buildSpecPrompt(InterviewState state, {String? ingestedContext}) {
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

  final refBlock = ingestedContext != null
      ? '\n\nREFERENCE CONTEXT (from user-supplied documents):\n'
          'Incorporate the following into the spec where relevant. '
          'Definitions should appear verbatim. Equations should be preserved. '
          'Constraints should be reflected in Hard Constraints and Out-of-Scope.\n\n'
          '$ingestedContext\n'
      : '';

  final specStructure =
      isBuild ? _buildSpecStructure : _auditSpecStructure;

  final extracted = state.extracted;
  final hasFunnelData = isBuild &&
      state.currentLayer.isNotEmpty &&
      extracted['outcome'] != null;

  final funnelBlock = hasFunnelData
      ? '''

FUNNEL OUTPUT (drive the spec from this — it is the user's confirmed V1 cut):

Outcome: ${extracted['outcome']}
Primary user: ${extracted['primaryUser']}
Capabilities (confirmed): ${(extracted['capabilities'] as List).join(', ')}
Chosen capability for V1: ${extracted['chosenCapability']}

Demo script (each step is a Completion Criterion row):
${(extracted['demoScript'] as List).asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Architectural defaults (confirmed by the user — put these in Hard Constraints):
- Platform: ${extracted['platform']}
- Identity model: ${extracted['identityModel']}
- Input model: ${extracted['inputModel']}
- Output model: ${extracted['outputModel']}

External services (only services with core=true belong in V1):
${(extracted['externalServices'] as List).map((s) => '- ${s['name']} (core=${s['core']}, stripped=${s['stripped']})').join('\n')}

V2 seeds (put these in Explicit Out-of-Scope and v2 Architecture Notes — never V1):
${(extracted['v2Seeds'] as List).map((s) => '- $s').join('\n')}
'''
      : '';

  return '''You are The Forge spec writer — a sharp, direct technical architect.

PROJECT: ${state.projectName}
MODE: $modeLabel Interview
$refBlock
INTERVIEW TRANSCRIPT:
$transcript

CONFIDENCE MAP:
$confidenceSummary
$funnelBlock
Generate a complete $modeLabel Locked Spec following this exact structure. Be specific and concrete — no "TBD", no filler. Every Completion Criterion must be autonomously verifiable by an executor agent. Every Accepted Decision must state what was rejected and why.
- Completion Criteria rows must mirror the demo script steps one-for-one.
- Hard Constraints come from the Architectural defaults block — do not invent.
- Anything in the V2 seeds list goes ONLY in Explicit Out-of-Scope (§7) and v2 Architecture Notes (§10). Never §3 Component Map or §5 Completion Criteria.

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

String buildGoalText(
    InterviewState state, String specVersion, String specContent) {
  final isBuild = state.dimensions == buildDimensions;
  final goalStatement =
      _extractSection(specContent, '## 1. Immutable Goal Statement') ??
          _extractSection(specContent, '## 1. Project Goal Statement') ??
          '(see locked spec)';
  final completionCriteria = isBuild
      ? (_extractSection(specContent, '## 5. Completion Criteria') ??
          '(see locked spec)')
      : '(Audit mode — see locked spec for next phase seeds)';

  return '''# /goal — ${state.projectName} $specVersion

## Outcome
$goalStatement

## Completion Criteria
$completionCriteria

## Constraints
(see Hard Constraints table in the locked spec)

## Boundaries
- Component ownership: see Component Map in the locked spec
- Out-of-scope: see Explicit Out-of-Scope List in the locked spec

## Iteration Policy
Work at low temperature. Resolve ambiguity conservatively. When uncertain
between two valid approaches, choose the one with less surface area. Flag
decisions you are not confident in rather than guessing.

## Stop Conditions
Stop and surface a blocker if:
- A completion criterion cannot be met without a decision not in this spec
- A required external service is unavailable or misconfigured
- The Setup Worksheet variables are missing or invalid

Do not stop because the work is hard. Stop only when genuinely blocked.
''';
}

List<String> parseComponentNames(String specContent) {
    final section = _extractSection(specContent, '## 3. Component Map');
    if (section == null) return [];
    return section
        .split('\n')
        .where((l) => l.startsWith('|') && !RegExp(r'^\|[-| ]+\|$').hasMatch(l.trim()))
        .skip(1)
        .map((l) {
          final cols = l.split('|');
          return cols.length > 1 ? cols[1].trim() : '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String buildExecutorTimelinePrompt(String projectName, String specContent) {
    final goal = _extractSection(specContent, '## 1. Immutable Goal Statement') ??
        _extractSection(specContent, '## 1. Project Goal Statement') ??
        '(see spec)';
    final constraints = _extractSection(specContent, '## 2. Hard Constraints') ?? '(see spec)';
    final componentSection = _extractSection(specContent, '## 3. Component Map') ?? '(see spec)';
    final components = parseComponentNames(specContent);
    final componentList = components.isEmpty
        ? '(no components found)'
        : components.map((c) => '- $c').join('\n');

    return '''You are a senior technical architect generating an ordered build sequence.

PROJECT: $projectName

GOAL:
$goal

HARD CONSTRAINTS:
$constraints

COMPONENT MAP (table):
$componentSection

COMPONENTS IDENTIFIED:
$componentList

Generate a concrete, ordered build sequence. Order by dependency: components with no upstream dependencies come first. Each step enables the next.

Output this exact format and nothing else:

# $projectName — Build Sequence

## Step 1: [ComponentName]
[One sentence: what to build and what it unblocks downstream]

## Step 2: [ComponentName]
[One sentence]

(continue for every component in the Component Map — one step per component, no extras)

Rules:
- Use the exact component names from the Component Map
- No TBD, no filler
- Each step's one sentence explains WHY it comes at this position
- Do not add components not in the spec''';
  }


Map<String, String> buildContextFiles(String projectName, String specVersion) {
  return {
    'file1': '${projectName}_LockedSpec_$specVersion.md',
    'file2': '${projectName}_DecisionContext_$specVersion.md',
    'file3': '${projectName}_ActiveState_$specVersion.md',
    'file4': '${projectName}_HandoffTrail_$specVersion.md',
    'file5': '${projectName}_OpenFlags_$specVersion.md',
  };
}

String buildDecisionContext(String projectName, String specVersion, String specContent) {
  final section = _extractSection(specContent, '## 8. Accepted Decisions') ?? '(none)';
  return '# $projectName — Decision Context $specVersion\n\n'
      '## Accepted Decisions\n$section\n';
}

String buildOpenFlags(String projectName, String specVersion, String specContent) {
  final openFlagsSection = _extractSection(specContent, '## 9. Open Flags') ?? '(none)';
  final outOfScopeSection =
      _extractSection(specContent, '## 7. Explicit Out-of-Scope List') ?? '(none)';
  final v2Section = _extractSection(specContent, '## 10. v2 Architecture Notes') ?? '(none)';
  return '# $projectName — Open Flags $specVersion\n\n'
      '## Open Flags\n$openFlagsSection\n\n'
      '## Explicit Out-of-Scope\n$outOfScopeSection\n\n'
      '## V2 Architecture Seeds\n$v2Section\n';
}

Map<String, dynamic> buildHandoffPackage(
    InterviewState state, String specVersion, String specContent) {
  final isBuild = state.dimensions == buildDimensions;
  final goalStatement =
      _extractSection(specContent, '## 1. Immutable Goal Statement') ??
          _extractSection(specContent, '## 1. Project Goal Statement') ??
          '';
  final now = DateTime.now().toIso8601String().split('T').first;

  if (isBuild) {
    return {
      'interviewMode': 'build',
      'specVersion': specVersion,
      'projectName': state.projectName,
      'appName': state.projectName,
      'lockedAt': now,
      'goalStatement': goalStatement.trim(),
      'openFlags': _countTableRows(specContent, '## 9. Open Flags'),
      'outOfScopeItems':
          _countListItems(specContent, '## 7. Explicit Out-of-Scope List'),
      'setupWorksheetComplete': false,
      'components': parseComponentNames(specContent),
      'contextFiles': buildContextFiles(state.projectName, specVersion),
      'v2SeedItems': <String>[],
    };
  } else {
    return {
      'interviewMode': 'audit',
      'specVersion': specVersion,
      'projectName': state.projectName,
      'auditDate': now,
      'goalStatement': goalStatement.trim(),
      'activeBlockers':
          _countTableRows(specContent, '## 4. Active Blocker Registry'),
      'decisionDebtItems':
          _countTableRows(specContent, '## 5. Decision Debt Log'),
      'technicalDebtItems':
          _countTableRows(specContent, '## 6. Technical Debt Log'),
      'documentationGaps':
          _countListItems(specContent, '## 8. Documentation Gaps'),
      'v2SeedItems': <String>[],
    };
  }
}

String? _extractSection(String content, String header) {
  final start = content.indexOf(header);
  if (start < 0) return null;
  final bodyStart = start + header.length;
  final nextHeader = content.indexOf('\n## ', bodyStart);
  final end = nextHeader < 0 ? content.length : nextHeader;
  return content.substring(bodyStart, end).trim();
}

int _countTableRows(String content, String sectionHeader) {
  final section = _extractSection(content, sectionHeader);
  if (section == null) return 0;
  final rows = section
      .split('\n')
      .where((l) => l.startsWith('|') && !RegExp(r'^\|[-| ]+\|$').hasMatch(l.trim()))
      .length;
  return (rows - 1).clamp(0, rows); // subtract header row, floor at 0
}

int _countListItems(String content, String sectionHeader) {
  final section = _extractSection(content, sectionHeader);
  if (section == null) return 0;
  return section
      .split('\n')
      .where(
          (l) => l.trimLeft().startsWith('- ') || l.trimLeft().startsWith('* '))
      .length;
}
