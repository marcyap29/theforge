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
      'capabilities':
          (extractedRaw['capabilities'] as List<dynamic>?)?.cast<String>() ??
              <String>[],
      'chosenCapability': extractedRaw['chosenCapability'] as String?,
      'demoScript':
          (extractedRaw['demoScript'] as List<dynamic>?)?.cast<String>() ??
              <String>[],
      'v2Seeds':
          (extractedRaw['v2Seeds'] as List<dynamic>?)?.cast<String>() ??
              <String>[],
      'platform': extractedRaw['platform'] as String?,
      'identityModel': extractedRaw['identityModel'] as String?,
      'inputModel': extractedRaw['inputModel'] as String?,
      'outputModel': extractedRaw['outputModel'] as String?,
      'externalServices':
          (extractedRaw['externalServices'] as List<dynamic>?)
                  ?.map((e) => e as Map<String, dynamic>)
                  .toList() ??
              <Map<String, dynamic>>[],
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

  final extractedJson =
      const JsonEncoder.withIndent('  ').convert(state.extracted);

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

String _interviewSystemPrompt(InterviewState state,
    {String? ingestedContext}) {
  final isBuild = state.dimensions == buildDimensions;
  if (!isBuild) {
    return _auditInterviewSystemPrompt(state, ingestedContext: ingestedContext);
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
  if (extracted['externalServices'] is List) {
    updates['externalServices'] = DimensionState.resolved;
  }
  return updates;
}

class InterviewNotifier
    extends FamilyAsyncNotifier<InterviewState, InterviewArgs> {
  @override
  Future<InterviewState> build(InterviewArgs args) async {
    final dims = dimensionsFor(args.mode);
    return InterviewState.empty(args.path, args.name, dims);
  }

  Future<void> addUserMessage(String text) async {
    final initial = state.valueOrNull;
    if (initial == null || initial.isLoading) return;
    if (text.trim().isEmpty) return;

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
            ingestedContext: ingestedContext),
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

    state = AsyncData(
      withUser.copyWith(
        confidenceMap: newMap,
        turns: [...withUser.turns, interviewerTurn],
        openConflicts: newConflicts,
        specGenEnabled: specGenEnabled,
        isLoading: false,
        llmUnavailable: withUser.llmUnavailable || llmFailed,
      ),
    );
  }

  Future<void> _buildFlow(InterviewState withUser, String text) async {
    final llmService = ref.read(llmServiceProvider);
    final repo = ref.read(projectFileRepositoryProvider);
    final ingestedContext =
        await repo.readIngestedSummary(withUser.projectPath);

    bool llmFailed = false;
    String llmRaw = '';
    try {
      llmRaw = await llmService.complete(
        systemPrompt: _interviewSystemPrompt(withUser,
            ingestedContext: ingestedContext),
        userPrompt: text.trim(),
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
      String retryRaw;
      try {
        retryRaw = await llmService.complete(
          systemPrompt: _interviewSystemPrompt(withUser,
              ingestedContext: ingestedContext),
          userPrompt:
              '${text.trim()}\n\nYour previous response did not include a ```forge-state block. '
              'Re-emit the SAME answer with the mandatory ```forge-state JSON block appended. '
              'The block is required on every turn.',
          temperature: 0.1,
          role: LlmRole.executor,
        );
      } catch (_) {
        final interviewerTurn = InterviewTurn(
          role: 'interviewer',
          content: parse.visibleText,
          timestamp: DateTime.now(),
        );
        state = AsyncData(
          withUser.copyWith(
            turns: [...withUser.turns, interviewerTurn],
            isLoading: false,
            parseDegraded: true,
          ),
        );
        return;
      }
      parse = parseForgeState(retryRaw);
    }

    if (!parse.parseOk) {
      final interviewerTurn = InterviewTurn(
        role: 'interviewer',
        content: parse.visibleText,
        timestamp: DateTime.now(),
      );
      state = AsyncData(
        withUser.copyWith(
          turns: [...withUser.turns, interviewerTurn],
          isLoading: false,
          parseDegraded: true,
        ),
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
    final specGenEnabled = allResolved && newConflicts.isEmpty;

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

    state = AsyncData(
      withUser.copyWith(
        confidenceMap: newMap,
        turns: [...withUser.turns, interviewerTurn],
        openConflicts: newConflicts,
        specGenEnabled: specGenEnabled,
        isLoading: false,
        currentLayer: newLayer,
        extracted: mergedExtracted,
        parseDegraded: false,
      ),
    );

    await repo.writeInterviewProgress(
      withUser.projectPath,
      withUser.projectName,
      {
        'currentLayer': newLayer,
        'completedLayers': _completedLayers(newLayer),
      },
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

  void reset() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      InterviewState.empty(
        current.projectPath,
        current.projectName,
        current.dimensions,
      ),
    );
  }
}
