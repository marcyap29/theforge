import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../../projects/providers/providers.dart';
import '../providers/interview_providers.dart';
import 'interview_dimension.dart';
import 'interview_state.dart';

typedef StubLlmResult = ({
  String interviewerText,
  Map<String, DimensionState> confidenceUpdates,
  List<ConflictItem> newConflicts,
});

typedef ForgeStateParse = ({
  Map<String, dynamic>? extracted,
  String? layer,
  bool layerComplete,
  List<ConflictItem> conflicts,
  String visibleText,
  bool parseOk,
});

StubLlmResult stubInterviewStep(InterviewState state, String userMessage) {
  final userTurnCount = state.turns.where((t) => t.isUser).length;
  final dims = state.dimensions;
  final total = dims.length;

  if (userTurnCount >= 1 && userTurnCount <= total) {
    final resolvedIndex = userTurnCount - 1;
    final nextIndex = userTurnCount < total ? userTurnCount : -1;
    final nextQuestion =
        nextIndex >= 0 ? dims[nextIndex].question : 'All dimensions covered.';
    return (
      interviewerText: 'Understood. $nextQuestion',
      confidenceUpdates: {dims[resolvedIndex].id: DimensionState.resolved},
      newConflicts: const [],
    );
  }

  if (userTurnCount > total) {
    return (
      interviewerText: 'Interview complete. Nothing left to ask.',
      confidenceUpdates: const {},
      newConflicts: const [],
    );
  }

  return (
    interviewerText: dims[0].question,
    confidenceUpdates: const {},
    newConflicts: const [],
  );
}

ForgeStateParse parseForgeState(String llmRaw) {
  final fencePattern = RegExp(r'```forge-state[^\n]*\n([\s\S]*?)\n\s*```');
  final match = fencePattern.firstMatch(llmRaw);

  if (match == null) {
    return (
      extracted: null,
      layer: null,
      layerComplete: false,
      conflicts: const [],
      visibleText: llmRaw,
      parseOk: false,
    );
  }

  final visibleText = llmRaw.replaceFirst(match.group(0)!, '').trim();
  final jsonStr = match.group(1)!;

  ForgeStateParse degradedResult() => (
        extracted: null,
        layer: null,
        layerComplete: false,
        conflicts: const <ConflictItem>[],
        visibleText: visibleText,
        parseOk: false,
      );

  try {
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    final extractedRaw = parsed['extracted'] as Map<String, dynamic>? ?? {};
    final extracted = <String, dynamic>{
      'outcome': extractedRaw['outcome'] as String?,
      'primaryUser': extractedRaw['primaryUser'] as String?,
      // Safe list parsing: LLMs sometimes emit strings ("none", "TBD") for
      // list fields. Hard cast as List<dynamic>? throws TypeError → degrades
      // the entire parse. Use 'is' check and normalize to empty list.
      'capabilities': extractedRaw['capabilities'] is List<dynamic>
          ? (extractedRaw['capabilities'] as List<dynamic>).cast<String>()
          : <String>[],
      'chosenCapability': extractedRaw['chosenCapability'] as String?,
      'demoScript': extractedRaw['demoScript'] is List<dynamic>
          ? (extractedRaw['demoScript'] as List<dynamic>).cast<String>()
          : <String>[],
      'v2Seeds': extractedRaw['v2Seeds'] is List<dynamic>
          ? (extractedRaw['v2Seeds'] as List<dynamic>).cast<String>()
          : <String>[],
      'platform': extractedRaw['platform'] as String?,
      'identityModel': extractedRaw['identityModel'] as String?,
      'inputModel': extractedRaw['inputModel'] as String?,
      'outputModel': extractedRaw['outputModel'] as String?,
      // Safe parse: LLMs often output "None" or a string for no external
      // services. Hard-casting as List throws TypeError → degrades the whole
      // parse. Use 'is' check and normalize non-list values to an empty list.
      'externalServices': extractedRaw['externalServices'] is List<dynamic>
          ? (extractedRaw['externalServices'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .toList()
          : <Map<String, dynamic>>[],
    };

    final layer = parsed['layer'] as String?;
    final layerComplete = parsed['layerComplete'] as bool? ?? false;

    final conflictsRaw = parsed['conflicts'] as List<dynamic>? ?? [];
    final conflicts = conflictsRaw.map((c) {
      final cm = c as Map<String, dynamic>;
      final a = cm['a'] as String? ?? '';
      final b = cm['b'] as String? ?? '';
      final id =
          '${a}_$b'.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
      return ConflictItem(
        id: id,
        dimensionALabel: a,
        dimensionBLabel: b,
        description: cm['description'] as String? ?? '',
        recommendation: cm['recommendation'] as String? ?? '',
      );
    }).toList();

    return (
      extracted: extracted,
      layer: layer,
      layerComplete: layerComplete,
      conflicts: conflicts,
      visibleText: visibleText,
      parseOk: true,
    );
  } on FormatException {
    return degradedResult();
  } on TypeError {
    return degradedResult();
  }
}

// Omits null values and empty lists before encoding the extracted map.
// Sending null fields on every turn wastes ~80-120 tokens with no signal value.
String _compactExtractedJson(Map<String, dynamic> extracted) {
  final compact = Map.fromEntries(
    extracted.entries.where((e) {
      final v = e.value;
      return v != null && !(v is List && v.isEmpty);
    }),
  );
  return const JsonEncoder.withIndent('  ').convert(compact);
}

String _v2SeedsMarkdown(List<String> seeds) {
  if (seeds.isEmpty) return '# V2 Seeds\n\n_(none captured)_\n';
  return '# V2 Seeds\n\n${seeds.map((s) => '- $s').join('\n')}\n';
}

List<String> _completedLayers(String currentLayer) {
  const order = ['L1', 'L2', 'L3', 'L4'];
  final idx = order.indexOf(currentLayer);
  if (idx <= 0) return const [];
  return order.sublist(0, idx);
}

// Proxy layer advancement from the confidence map when the forge-state block
// is unavailable (parseDegraded path). The stub marks buildDimensions in
// array order, so confidence resolution is a reliable layer proxy.
String _layerFromConfidence(
    String current, Map<String, DimensionState> map) {
  bool resolved(String id) => map[id] == DimensionState.resolved;
  switch (current) {
    case 'L1':
      if (resolved('corePurpose') && resolved('primaryUser')) return 'L2';
    case 'L2':
      if (resolved('identityModel') || resolved('inputModel')) return 'L3';
    case 'L3':
      if (resolved('outputModel') || resolved('platform')) return 'L4';
  }
  return current;
}

String _auditInterviewSystemPrompt(InterviewState state,
    {String? ingestedContext}) {
  const modeLabel = 'Audit Interview';

  final resolved = state.dimensions
      .where((d) => state.confidenceMap[d.id] == DimensionState.resolved)
      .map((d) => d.label)
      .join(', ');
  final remaining = state.dimensions
      .where((d) => state.confidenceMap[d.id] != DimensionState.resolved)
      .map((d) => '${d.label}: ${d.question}')
      .join('\n');

  final refBlock = ingestedContext != null
      ? '\n\nREFERENCE CONTEXT:\n'
          'The following was extracted from reference documents provided by the user. '
          'Use it to inform your questions but do not treat it as binding — '
          'surface any tensions between the reference material and the user\'s answers.\n\n'
          '$ingestedContext'
      : '';

  return '''You are The Forge interviewer — a sharp, direct product architect
running a $modeLabel for a project called "${state.projectName}".
$refBlock
Your goal: resolve ${state.dimensions.length} confidence dimensions through conversation.
Ask ONE question per turn. Be concise. Acknowledge the user's answer first.

Resolved so far: ${resolved.isEmpty ? 'none yet' : resolved}
Still needed:
$remaining

If a conflict exists between answers, surface it with:
"Your answers on [X] and [Y] pull in opposite directions. [X] implies [A]. [Y] implies [B].
I recommend [conservative option] for v1 because [reason]. Do you accept this scope?"

Do not ask about resolved dimensions. If all are resolved, confirm and stop.''';
}

String _buildInterviewSystemPrompt(InterviewState state,
    {String? ingestedContext}) {
  final refBlock = ingestedContext != null
      ? '\n\nREFERENCE CONTEXT:\n'
          'The following was extracted from reference documents provided by the user. '
          'Use it to inform your questions but do not treat it as binding — '
          'surface any tensions between the reference material and the user\'s answers.\n\n'
          '$ingestedContext\n'
      : '';

  final extractedJson = _compactExtractedJson(state.extracted);

  return '''You are The Forge interviewer — a sharp, direct product architect
running a Build Interview for a project called "${state.projectName}". Your
job is to reach a locked V1 spec an autonomous executor can build in one
pass. You are the user's product manager: push back on scope, force the
proof-of-concept cut, keep every deferred idea on the record.
$refBlock
THE FUNNEL — you are currently at ${state.currentLayer}. Do not advance until
the exit condition is met. Never ask about a later layer early.

L1 OUTCOME: Establish the one thing this app does for its user that nothing
they use today does, and who that user is. Exit: you restate it as "For
[user], this app [outcome]" and the user confirms.

L2 DECOMPOSITION: Get the 3-5 capabilities required to deliver L1. Push back
on lists over 5 and on anything that doesn't trace to the outcome. Exit:
confirmed list.

L3 POC REDUCTION: Force the choice of ONE capability as proof, then get a
3-5 step demo script ("open the app, do X, see Y"). Every capability not
chosen and every feature mentioned but absent from the demo goes on the v2
seed list. Read the seed list back for confirmation. Exit: capability chosen,
demo confirmed, seeds confirmed.

L4 CRITICAL PATH: Do not ask open questions here. Deduce platform, identity,
input, output, and services from the demo script and propose conservative
defaults the user confirms or corrects. Identity defaults to none. Run the
blocker scan: ask what they already have set up, then propose stripping
every external service that is not itself the chosen capability (local
storage over cloud, mocks over live APIs, no auth over OAuth). Draft the 1-3
step sequence to a working demo and ask them to correct it. Exit: all
defaults confirmed or overridden, blocker scan done, sequence confirmed.

STATE SO FAR (cumulative `extracted` map — re-emit every field every turn):
$extractedJson

RULES
- Ask ONE question per turn. Acknowledge the answer first. Be concise.
- When answers conflict: "Your answers on [X] and [Y] pull in opposite
  directions. [X] implies [A]. [Y] implies [B]. I recommend [conservative
  option] for v1 because [reason]. Do you accept this scope?" Do not proceed
  past a conflict.
- Never accept "all of the above". Pressure-test it.
- When the user is uncertain, recommend the conservative default and move on.
- If the user pitches a new feature at any layer, acknowledge it, add it to
  the v2 seeds, and return to the current layer's question.
- L2 capabilities: hard cap at 5. Demo script: 3 to 5 steps. Hard limits.

After EVERY response, append a fenced forge-state block. The block is
MANDATORY on every turn, even when nothing changed. Emit the FULL extracted
map each turn (cumulative, not deltas):

\`\`\`forge-state
{
  "layer": "${state.currentLayer}",
  "layerComplete": false,
  "extracted": { ... full map ... },
  "conflicts": []
}
\`\`\`

Set `layerComplete: true` only when the current layer's exit condition is
met. Set `conflicts: []` unless you detected an actual contradiction.''';
}

String? _extractGoalStatement(String? featureContext) {
  if (featureContext == null) return null;
  final lines = featureContext.split('\n');
  bool inGoalSection = false;
  for (final line in lines) {
    if (RegExp(r'##\s+\d*\.?\s*(Immutable )?Goal Statement', caseSensitive: false)
        .hasMatch(line)) {
      inGoalSection = true;
      continue;
    }
    if (inGoalSection) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        if (trimmed.startsWith('#')) break;
        continue;
      }
      return trimmed.replaceAll(RegExp(r'^\*+|\*+$'), '').trim();
    }
  }
  return null;
}

List<String> _extractComponents(String? featureContext) {
  if (featureContext == null) return const [];
  final lines = featureContext.split('\n');
  bool inComponentSection = false;
  bool pastHeader = false;
  final components = <String>[];
  for (final line in lines) {
    if (RegExp(r'##\s+\d*\.?\s*Component\s+(Map|List)', caseSensitive: false)
        .hasMatch(line)) {
      inComponentSection = true;
      pastHeader = false;
      continue;
    }
    if (inComponentSection) {
      if (line.trim().startsWith('#')) break;
      if (!line.trim().startsWith('|')) continue;
      if (!pastHeader) {
        // Skip header row and separator row
        if (line.contains('---')) {
          pastHeader = true;
        }
        continue;
      }
      final cols = line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (cols.isNotEmpty) {
        final name = cols[0].replaceAll(RegExp(r'[`*_]'), '').trim();
        if (name.isNotEmpty) components.add(name);
      }
    }
  }
  return components;
}

String _featureInterviewSystemPrompt(InterviewState state,
    {String? ingestedContext, required String priorSpecVersion, String? complianceContext}) {
  final nextVersion = nextSpecVersion(priorSpecVersion);
  final goalStatement = _extractGoalStatement(state.featureContext);
  final components = _extractComponents(state.featureContext);

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
          'Do not re-ask anything already established in $priorSpecVersion.\n\n'
          '${state.featureContext}\n'
      : '';

  final goalRef = goalStatement != null
      ? '\n\nSCOPE ANCHOR — $priorSpecVersion core purpose (immutable):\n'
          '"$goalStatement"\n'
          'Every suggestion in this interview must trace to this purpose or extend it '
          'naturally. If it does not, say so kindly and offer to seed it for a future version.\n'
      : '';

  final componentList = components.isNotEmpty
      ? components.join(', ')
      : '(see spec above)';

  final extractedJson = _compactExtractedJson(state.extracted);

  final complianceBlock = complianceContext != null
      ? '\n\nV1 BUILD COMPLIANCE — USE THIS TO SCOPE THE V2 INTERVIEW:\n'
          '$complianceContext\n'
          'Items marked ❌ or ⚠️ from V1 may need to be addressed or explicitly deferred before scoping V2.'
      : '';

  return '''You are The Forge interviewer — a sharp, direct product architect
running a Feature Interview for a project called "${state.projectName}".
You are scoping $nextVersion. $priorSpecVersion is already shipped and immutable.
$refBlock$contextBlock$goalRef$complianceBlock
THE FUNNEL — you are currently at ${state.currentLayer}. Do not advance until
the exit condition is met. Never ask about a later layer early.

L1 OPENING — PRESENT FIRST, THEN ASK (1-2 turns):
Do NOT open with a question. Start by presenting what $priorSpecVersion delivered:
"${state.projectName} $priorSpecVersion shipped [restate the outcome in one sentence from FEATURE CONTEXT].
The components built were: $componentList.
The features deferred were: [list the v2 seeds from FEATURE CONTEXT, or 'none captured' if empty].
What is the ONE thing you\'d add or improve for $nextVersion?"
After the user responds, confirm it in one sentence and exit L1.
Exit: new outcome confirmed.

L2 DECOMPOSITION:
Present the deferred seeds from FEATURE CONTEXT as the candidate menu for $nextVersion.
Hard cap at 5 capabilities. If the user suggests something not in the seeds, apply the
SCOPE GUARD below before accepting it. Exit: confirmed capability list.

L3 POC REDUCTION:
One capability chosen as proof. Get a 3-5 step demo script. Every capability not
chosen and every new feature mentioned goes on the next-version seed list.
Read the seed list back. Exit: capability chosen, demo confirmed, seeds confirmed.

L4 CRITICAL PATH (INCREMENTAL):
Most architecture is inherited from $priorSpecVersion. Ask ONLY about what changes:
- Which $priorSpecVersion components does this feature touch?
- What is genuinely new (not in $priorSpecVersion)?
- Inherit platform/identity/input/output from $priorSpecVersion unless the demo
  requires something different — only ask if there is a real change.
Run the blocker scan. Draft the 1-3 step sequence. Exit: incremental delta confirmed.

SCOPE GUARD (apply at every layer whenever a suggestion arrives):
1. Check: does this trace to the SCOPE ANCHOR above, or pull toward a different direction?
2. If it fits: accept and continue.
3. If it does not fit, respond kindly:
   "The core of ${state.projectName} is [restate anchor]. [Suggestion] feels like it's
   pulling toward [different direction] — that could be strong $nextVersion territory or
   even later. Want to seed it and keep $nextVersion focused on [closer alternative]?"
4. If the user insists after the pushback, accept it but flag it in the seed list with
   a note that it was outside the original scope anchor.
Never hard-block. Seed everything that gets deferred.

STATE SO FAR (cumulative extracted map — re-emit every field every turn):
$extractedJson

RULES
- Ask ONE question per turn. Acknowledge the answer first. Be concise.
- $priorSpecVersion is immutable. Never suggest changing it.
- One new capability per version. If the user wants two, pick one and defer the other.
- When answers conflict: state both sides, recommend the conservative path, ask for
  confirmation before proceeding.

After EVERY response, append a fenced forge-state block. MANDATORY every turn:

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

String _interviewSystemPrompt(InterviewState state,
    {String? ingestedContext, String? priorSpecVersion, String? complianceContext}) {
  final isBuild = state.dimensions == buildDimensions;
  if (!isBuild) {
    return _auditInterviewSystemPrompt(state, ingestedContext: ingestedContext);
  }
  if (priorSpecVersion != null) {
    return _featureInterviewSystemPrompt(state,
        ingestedContext: ingestedContext, priorSpecVersion: priorSpecVersion, complianceContext: complianceContext);
  }
  return _buildInterviewSystemPrompt(state, ingestedContext: ingestedContext);
}

bool _layerGateMet(String layer, Map<String, dynamic> extracted) {
  switch (layer) {
    case 'L1':
      return extracted['outcome'] != null && extracted['primaryUser'] != null;
    case 'L2':
      final caps = extracted['capabilities'] as List;
      return caps.length >= 3 && caps.length <= 5;
    case 'L3':
      final demo = extracted['demoScript'] as List;
      return extracted['chosenCapability'] != null &&
          demo.length >= 3 &&
          demo.length <= 5 &&
          extracted['v2Seeds'] is List;
    case 'L4':
      return extracted['platform'] != null &&
          extracted['identityModel'] != null &&
          extracted['inputModel'] != null &&
          extracted['outputModel'] != null &&
          extracted['externalServices'] is List;
    default:
      return false;
  }
}

String _nextLayer(String current) {
  switch (current) {
    case 'L1':
      return 'L2';
    case 'L2':
      return 'L3';
    case 'L3':
      return 'L4';
    default:
      return current;
  }
}

Map<String, DimensionState> _confidenceFromExtracted(
    Map<String, dynamic> extracted) {
  final updates = <String, DimensionState>{};
  if (extracted['outcome'] != null) {
    updates['corePurpose'] = DimensionState.resolved;
  }
  if (extracted['primaryUser'] != null) {
    updates['primaryUser'] = DimensionState.resolved;
  }
  if (extracted['identityModel'] != null) {
    updates['identityModel'] = DimensionState.resolved;
  }
  if (extracted['inputModel'] != null) {
    updates['inputModel'] = DimensionState.resolved;
  }
  if (extracted['outputModel'] != null) {
    updates['outputModel'] = DimensionState.resolved;
  }
  if (extracted['platform'] != null) {
    updates['platform'] = DimensionState.resolved;
  }
  final v2Seeds = extracted['v2Seeds'] as List;
  final demoScript = extracted['demoScript'] as List;
  if (v2Seeds.isNotEmpty && demoScript.isNotEmpty) {
    updates['scopeBoundary'] = DimensionState.resolved;
  }
  // externalServices resolves when the other L4 fields are present.
  // Checking the list type is unreliable — LLMs often emit "None" (string)
  // for projects with no external services. Instead: L4 completion (all
  // other platform/identity/input/output fields populated) implies the
  // external services question was answered, even if the answer is "none".
  if (extracted['platform'] != null &&
      extracted['identityModel'] != null &&
      extracted['inputModel'] != null &&
      extracted['outputModel'] != null) {
    updates['externalServices'] = DimensionState.resolved;
  }
  return updates;
}

// Returns a copy of `current` extracted map with all fields from `targetLayer`
// onward reset to their initial empty values, so only prior-layer data remains.
Map<String, dynamic> _extractedAtLayerStart(
    String targetLayer, Map<String, dynamic> current) {
  const order = ['L1', 'L2', 'L3', 'L4'];
  final idx = order.indexOf(targetLayer);
  final base = Map<String, dynamic>.from(current);
  // Clear fields belonging to the target layer and all later layers.
  if (idx <= 0) {
    base['outcome'] = null;
    base['primaryUser'] = null;
  }
  if (idx <= 1) base['capabilities'] = <String>[];
  if (idx <= 2) {
    base['chosenCapability'] = null;
    base['demoScript'] = <String>[];
    base['v2Seeds'] = <String>[];
  }
  if (idx <= 3) {
    base['platform'] = null;
    base['identityModel'] = null;
    base['inputModel'] = null;
    base['outputModel'] = null;
    base['externalServices'] = <Map<String, dynamic>>[];
  }
  return base;
}

String nextSpecVersion(String current) {
  if (current.startsWith('v')) {
    final n = int.tryParse(current.substring(1));
    if (n != null) return 'v${n + 1}';
  }
  return 'v2';
}

class InterviewNotifier
    extends FamilyAsyncNotifier<InterviewState, InterviewArgs> {
  // ── Opening message variations ───────────────────────────────────────────
  // Picked deterministically by projectName.hashCode % length — zero token cost.
  static const _buildOpeners = [
    "Hi! Let's spec out {name}. I'll walk you through four layers — starting with the outcome. What should this product actually do? In one sentence: what changes for someone when they use it?",
    "Welcome to the Build Interview for {name}. Let's start at the top — what outcome does this product create? Don't worry about features yet. What does the user walk away with?",
    "Let's scope {name}. Four layers, starting with Outcome. What's the single thing this product should accomplish? Describe it from the user's side — what can they do or have that they couldn't before?",
    "Ready to build the spec for {name}. First question: what problem does this solve, and what does success look like from the user's perspective? One or two sentences is perfect.",
  ];

  static const _featureOpeners = [
    "{prior} is shipped — time to scope the next version of {name}. What's the most important thing we didn't build in {prior} that users need next?",
    "Nice work on {prior}. Let's figure out what the next version of {name} should deliver. What was the biggest gap after {prior} shipped — the thing users needed that wasn't there?",
    "Building on {prior} for {name}. Let's start with the outcome for the next version. What capability or result would make the biggest difference to users right now?",
    "Let's scope the next version of {name}, building on {prior}. What's the one thing that would take this product from good to great for your users?",
  ];

  static const _auditOpeners = [
    "Hi! Let's audit {name}. Start with the big picture — what is this project actually trying to accomplish? Set aside the backlog; describe the goal as you'd explain it to a new team member.",
    "Welcome to the Audit Interview for {name}. First question: what's the real goal of this project? Not the features, not the roadmap — what outcome should it deliver?",
    "Let's capture the current state of {name}. Start here: what is this project supposed to do, and how close is it to doing that right now?",
    "Audit mode for {name}. Let's establish the baseline. What problem is this project solving, and what does 'done' look like from the team's perspective?",
  ];

  String _pickOpener(InterviewArgs args) {
    final idx = args.name.hashCode.abs();
    if (args.priorSpecVersion != null) {
      const list = _featureOpeners;
      return list[idx % list.length]
          .replaceAll('{name}', args.name)
          .replaceAll('{prior}', args.priorSpecVersion!.toUpperCase());
    }
    final isBuild = dimensionsFor(args.mode) == buildDimensions;
    final list = isBuild ? _buildOpeners : _auditOpeners;
    return list[idx % list.length].replaceAll('{name}', args.name);
  }

  InterviewState _withOpener(InterviewState state, InterviewArgs args) {
    final opener = InterviewTurn(
      role: 'interviewer',
      content: _pickOpener(args),
      timestamp: DateTime.now(),
    );
    return state.copyWith(turns: [opener]);
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Map<String, dynamic> _progressPayload(InterviewState s) => {
        'currentLayer': s.currentLayer,
        'completedLayers': _completedLayers(s.currentLayer),
        'layerBoundaries': s.layerBoundaries,
        'turns': s.turns
            .map((t) => {
                  'role': t.role,
                  'content': t.content,
                  'timestamp': t.timestamp.millisecondsSinceEpoch,
                })
            .toList(),
        'confidenceMap':
            s.confidenceMap.map((k, v) => MapEntry(k, v.name)),
        'extracted': s.extracted,
        'specGenEnabled': s.specGenEnabled,
      };

  InterviewState _restoreState(
      InterviewState empty, Map<String, dynamic> saved) {
    final turnsRaw = saved['turns'] as List<dynamic>? ?? [];
    final turns = turnsRaw.map((t) {
      final m = t as Map<String, dynamic>;
      return InterviewTurn(
        role: m['role'] as String? ?? 'interviewer',
        content: m['content'] as String? ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            m['timestamp'] as int? ?? 0),
      );
    }).toList();

    final confidenceRaw =
        saved['confidenceMap'] as Map<String, dynamic>? ?? {};
    final confidenceMap = <String, DimensionState>{};
    for (final entry in confidenceRaw.entries) {
      final ds = DimensionState.values
          .where((d) => d.name == entry.value)
          .firstOrNull;
      if (ds != null) confidenceMap[entry.key] = ds;
    }

    final boundariesRaw =
        saved['layerBoundaries'] as Map<String, dynamic>? ?? {};
    final layerBoundaries = boundariesRaw
        .map((k, v) => MapEntry(k, v as int));

    final restoredExtracted =
        (saved['extracted'] as Map<String, dynamic>?) ?? empty.extracted;

    // Re-evaluate specGenEnabled from extracted data rather than trusting the
    // saved boolean — interviews completed with older code saved false even
    // when the funnel was actually complete (externalServices TypeError bug).
    final savedSpecGen = saved['specGenEnabled'] as bool? ?? false;
    final specGenEnabled =
        savedSpecGen || _layerGateMet('L4', restoredExtracted);

    return empty.copyWith(
      turns: turns,
      currentLayer:
          saved['currentLayer'] as String? ?? empty.currentLayer,
      extracted: restoredExtracted,
      confidenceMap:
          confidenceMap.isNotEmpty ? confidenceMap : empty.confidenceMap,
      specGenEnabled: specGenEnabled,
      layerBoundaries: layerBoundaries,
    );
  }

  @override
  Future<InterviewState> build(InterviewArgs args) async {
    final dims = dimensionsFor(args.mode);
    final repo = ref.read(projectFileRepositoryProvider);

    String? featureContext;
    if (args.priorSpecVersion != null) {
      featureContext = await repo.readFeatureContext(
        args.path,
        args.name,
        args.priorSpecVersion!,
      );
    }

    final empty = InterviewState.empty(args.path, args.name, dims)
        .copyWith(featureContext: featureContext);

    // Restore persisted turns so closing/reopening the app resumes the interview
    final saved = await repo.readInterviewProgress(args.path, args.name);
    if (saved != null) {
      final turnsRaw = saved['turns'] as List<dynamic>?;
      if (turnsRaw != null && turnsRaw.isNotEmpty) {
        return _restoreState(empty, saved);
      }
    }

    return _withOpener(empty, args);
  }

  Future<void> addUserMessage(String text) async {
    final initial = state.valueOrNull;
    if (initial == null || initial.isLoading) return;
    if (text.trim().isEmpty) return;

    // On first user message, write an "active" phase to DB so the project list
    // CTA shows "Continue with VN Interview" if the user navigates away.
    if (initial.turns.where((t) => t.isUser).isEmpty) {
      final currentVersion = arg.priorSpecVersion != null
          ? nextSpecVersion(arg.priorSpecVersion!)
          : 'v1';
      await ref.read(forgeDatabaseProvider).updateProjectPhase(
        arg.name,
        '${currentVersion}_interview_active',
        currentVersion,
      );
      ref.read(projectListProvider.notifier).refresh();
    }

    final userTurn = InterviewTurn(
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    final withUser = initial.copyWith(
      turns: [...initial.turns, userTurn],
      isLoading: true,
    );
    state = AsyncData(withUser);

    final isBuild = withUser.dimensions == buildDimensions;

    if (!isBuild) {
      await _auditFlow(withUser, text);
      return;
    }

    await _buildFlow(withUser, text);
  }

  Future<void> _auditFlow(InterviewState withUser, String text) async {
    final stub = stubInterviewStep(withUser, text);

    final llmService = ref.read(llmServiceProvider);
    final repo = ref.read(projectFileRepositoryProvider);
    final ingestedContext =
        await repo.readIngestedSummary(withUser.projectPath);
    bool llmFailed = false;
    String llmText;
    try {
      llmText = await llmService.complete(
        systemPrompt: _interviewSystemPrompt(withUser,
            ingestedContext: ingestedContext,
            priorSpecVersion: arg.priorSpecVersion,
            complianceContext: arg.complianceContext),
        userPrompt: text.trim(),
        temperature: 0.1,
        role: LlmRole.executor,
      );
    } catch (_) {
      llmText = stub.interviewerText;
      llmFailed = true;
    }

    final newMap = Map<String, DimensionState>.from(withUser.confidenceMap);
    stub.confidenceUpdates.forEach((k, v) => newMap[k] = v);
    final allResolved =
        newMap.values.every((s) => s == DimensionState.resolved);
    final newConflicts = [...withUser.openConflicts, ...stub.newConflicts];
    final specGenEnabled = allResolved && newConflicts.isEmpty;

    final interviewerTurn = InterviewTurn(
      role: 'interviewer',
      content: llmText,
      timestamp: DateTime.now(),
    );

    final nextState = withUser.copyWith(
      confidenceMap: newMap,
      turns: [...withUser.turns, interviewerTurn],
      openConflicts: newConflicts,
      specGenEnabled: specGenEnabled,
      isLoading: false,
      llmUnavailable: withUser.llmUnavailable || llmFailed,
    );
    state = AsyncData(nextState);
    await ref.read(projectFileRepositoryProvider).writeInterviewProgress(
      nextState.projectPath,
      nextState.projectName,
      _progressPayload(nextState),
    );
  }

  Future<void> _buildFlow(InterviewState withUser, String text) async {
    final llmService = ref.read(llmServiceProvider);
    final repo = ref.read(projectFileRepositoryProvider);
    final ingestedContext =
        await repo.readIngestedSummary(withUser.projectPath);

    // Build contextual user prompt. The system prompt already carries the
    // cumulative `extractedJson`, so the full history is redundant once data
    // is extracted. Keep only the last 6 turns (3 exchanges) for immediate
    // conversational context; older turns are already captured in the state.
    final priorTurns =
        withUser.turns.sublist(0, withUser.turns.length - 1);
    final windowTurns = priorTurns.length > 6
        ? priorTurns.sublist(priorTurns.length - 6)
        : priorTurns;
    final historyBlock = windowTurns.isEmpty
        ? ''
        : windowTurns
                .map((t) =>
                    '${t.isUser ? "User" : "Interviewer"}: ${t.content}')
                .join('\n\n') +
            '\n\n---\n\n';
    final contextualPrompt = '${historyBlock}User: ${text.trim()}';

    bool llmFailed = false;
    String llmRaw = '';
    try {
      llmRaw = await llmService.complete(
        systemPrompt: _interviewSystemPrompt(withUser,
            ingestedContext: ingestedContext,
            priorSpecVersion: arg.priorSpecVersion,
            complianceContext: arg.complianceContext),
        userPrompt: contextualPrompt,
        temperature: 0.1,
        role: LlmRole.executor,
      );
    } catch (_) {
      llmFailed = true;
    }

    if (llmFailed) {
      final stub = stubInterviewStep(withUser, text);
      final newMap = Map<String, DimensionState>.from(withUser.confidenceMap);
      stub.confidenceUpdates.forEach((k, v) => newMap[k] = v);
      final allResolved =
          newMap.values.every((s) => s == DimensionState.resolved);
      final interviewerTurn = InterviewTurn(
        role: 'interviewer',
        content: stub.interviewerText,
        timestamp: DateTime.now(),
      );
      state = AsyncData(
        withUser.copyWith(
          confidenceMap: newMap,
          turns: [...withUser.turns, interviewerTurn],
          specGenEnabled: allResolved && withUser.openConflicts.isEmpty,
          isLoading: false,
          llmUnavailable: true,
        ),
      );
      return;
    }

    var parse = parseForgeState(llmRaw);

    if (!parse.parseOk) {
      // Retry with a minimal prompt — no need to re-send full history.
      // The LLM only needs its previous response + the format requirement.
      String retryRaw;
      try {
        retryRaw = await llmService.complete(
          systemPrompt: 'Append a forge-state block to the message below. '
              'Do not change the message text. Output the original message '
              'followed immediately by the block.\n\n'
              'Required format:\n'
              '```forge-state\n'
              '{"layer":"${withUser.currentLayer}","layerComplete":false,'
              '"extracted":{...full map...},"conflicts":[]}\n'
              '```\n\n'
              'Current extracted state:\n'
              '${_compactExtractedJson(withUser.extracted)}',
          userPrompt: llmRaw,
          temperature: 0.1,
          role: LlmRole.executor,
        );
      } catch (_) {
        retryRaw = '';
      }
      parse = parseForgeState(retryRaw.isNotEmpty ? retryRaw : llmRaw);
    }

    // forge-state block missing after retry — advance state using stub proxy
    // so the layer doesn't freeze. Show LLM text (better than stub text).
    if (!parse.parseOk) {
      final stub = stubInterviewStep(withUser, text);
      final newMap = Map<String, DimensionState>.from(withUser.confidenceMap);
      stub.confidenceUpdates.forEach((k, v) => newMap[k] = v);
      final newLayerDegraded =
          _layerFromConfidence(withUser.currentLayer, newMap);
      final allResolved =
          newMap.values.every((s) => s == DimensionState.resolved);
      final interviewerTurn = InterviewTurn(
        role: 'interviewer',
        content: parse.visibleText,
        timestamp: DateTime.now(),
      );
      state = AsyncData(
        withUser.copyWith(
          confidenceMap: newMap,
          turns: [...withUser.turns, interviewerTurn],
          isLoading: false,
          parseDegraded: true,
          currentLayer: newLayerDegraded,
          specGenEnabled: allResolved && withUser.openConflicts.isEmpty,
        ),
      );
      await repo.writeInterviewProgress(
        withUser.projectPath,
        withUser.projectName,
        _progressPayload(state.requireValue),
      );
      return;
    }

    final mergedExtracted = Map<String, dynamic>.from(withUser.extracted);
    if (parse.extracted != null) {
      for (final key in parse.extracted!.keys) {
        final value = parse.extracted![key];
        if (value != null && (value is! List || value.isNotEmpty)) {
          mergedExtracted[key] = value;
        }
      }
    }

    // Flutter side is authoritative for layer advancement — do not require
    // layerComplete from the LLM (models copy the false-example literally).
    String newLayer = withUser.currentLayer;
    if (_layerGateMet(withUser.currentLayer, mergedExtracted)) {
      newLayer = _nextLayer(withUser.currentLayer);
    }

    final confidenceUpdates = _confidenceFromExtracted(mergedExtracted);
    final newMap = Map<String, DimensionState>.from(withUser.confidenceMap);
    newMap.addAll(confidenceUpdates);

    final newConflicts = [...withUser.openConflicts, ...parse.conflicts];

    final allResolved =
        newMap.values.every((s) => s == DimensionState.resolved);
    // Also enable when L4 gate is met — the completed funnel is the real
    // signal. Individual dimension tracking can fail when the LLM emits
    // unexpected formats, so treat funnel completion as sufficient.
    final l4GateMet = _layerGateMet('L4', mergedExtracted);
    final specGenEnabled =
        (allResolved || l4GateMet) && newConflicts.isEmpty;

    // Write v2 seeds when we advance out of L3 (gate just passed).
    if (withUser.currentLayer == 'L3' && newLayer == 'L4') {
      final v2Seeds = mergedExtracted['v2Seeds'] as List<String>;
      await repo.writeIngestedFile(
        withUser.projectPath,
        '${withUser.projectName}_V2Seeds.md',
        _v2SeedsMarkdown(v2Seeds),
      );
    }

    final interviewerTurn = InterviewTurn(
      role: 'interviewer',
      content: parse.visibleText,
      timestamp: DateTime.now(),
    );

    // Record layer boundary when the layer advances.
    // Value = total turn count after this AI response — that's where the NEW
    // layer begins (next user message). rewindToLayer uses this to truncate.
    final newBoundaries = Map<String, int>.from(withUser.layerBoundaries);
    if (newLayer != withUser.currentLayer) {
      newBoundaries[newLayer] = withUser.turns.length + 1;
    }

    state = AsyncData(
      withUser.copyWith(
        confidenceMap: newMap,
        turns: [...withUser.turns, interviewerTurn],
        openConflicts: newConflicts,
        specGenEnabled: specGenEnabled,
        isLoading: false,
        llmUnavailable: false,
        currentLayer: newLayer,
        extracted: mergedExtracted,
        parseDegraded: false,
        layerBoundaries: newBoundaries,
      ),
    );

    await repo.writeInterviewProgress(
      withUser.projectPath,
      withUser.projectName,
      _progressPayload(state.requireValue),
    );
  }

  void resolveConflict(String conflictId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.openConflicts
        .where((c) => c.id != conflictId)
        .toList(growable: false);
    final allResolved = current.confidenceMap.values
        .every((s) => s == DimensionState.resolved);
    state = AsyncData(
      current.copyWith(
        openConflicts: updated,
        specGenEnabled: allResolved && updated.isEmpty,
      ),
    );
  }

  Future<void> rewindToLayer(String layer) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Turn index to truncate to: keep everything before this layer started.
    // L1 always starts at turn 1 (index 0 = opener). All others use the
    // recorded boundary, defaulting to 1 if the layer was never reached.
    final truncateTo = layer == 'L1'
        ? 1
        : (current.layerBoundaries[layer] ?? 1);
    final truncatedTurns = current.turns
        .sublist(0, truncateTo.clamp(0, current.turns.length));

    // Clear extracted data for target layer and later.
    final clearedExtracted = _extractedAtLayerStart(layer, current.extracted);

    // Re-derive confidence from the remaining data so the meter is accurate.
    final freshConfidence = <String, DimensionState>{
      for (final d in current.dimensions) d.id: DimensionState.unknown,
    };
    freshConfidence.addAll(_confidenceFromExtracted(clearedExtracted));

    // Drop boundaries for layers we're rewinding through.
    const order = ['L1', 'L2', 'L3', 'L4'];
    final targetIdx = order.indexOf(layer);
    final updatedBoundaries = Map<String, int>.from(current.layerBoundaries)
      ..removeWhere((k, _) => order.indexOf(k) >= targetIdx);

    final rewound = current.copyWith(
      turns: truncatedTurns,
      currentLayer: layer,
      extracted: clearedExtracted,
      confidenceMap: freshConfidence,
      openConflicts: const [],
      specGenEnabled: false,
      isLoading: false,
      layerBoundaries: updatedBoundaries,
    );
    state = AsyncData(rewound);

    // Persist the rewound state so it survives an app restart.
    await ref.read(projectFileRepositoryProvider).writeInterviewProgress(
      current.projectPath,
      current.projectName,
      _progressPayload(rewound),
    );
  }

  void rewindTo(int turnIndex) {
    final current = state.valueOrNull;
    if (current == null || turnIndex < 0 || turnIndex >= current.turns.length) return;
    state = AsyncData(
      current.copyWith(
        turns: current.turns.sublist(0, turnIndex),
        isLoading: false,
        openConflicts: const [],
        specGenEnabled: false,
        // Reset layer to initial: 'L1' for build mode, '' for audit mode.
        // The LLM will correct it on the next response via forge-state JSON.
        currentLayer: current.currentLayer.isNotEmpty ? 'L1' : '',
      ),
    );
  }

  Future<void> reset() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(projectFileRepositoryProvider).clearInterviewProgress(
      current.projectPath,
      current.projectName,
    );
    final empty = InterviewState.empty(
      current.projectPath,
      current.projectName,
      current.dimensions,
    );
    state = AsyncData(_withOpener(empty, arg));
  }
}
