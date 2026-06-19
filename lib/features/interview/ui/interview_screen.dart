import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../features/spec_generation/spec_generation_screen.dart';
import '../../projects/ingestion/ingestion_notifier.dart';
import '../../projects/ingestion/reference_docs_screen.dart';
import '../providers/interview_providers.dart';
import '../state/interview_notifier.dart';
import '../state/interview_state.dart';
import 'confidence_meter.dart';

class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({super.key, required this.args});

  final InterviewArgs args;

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseOpacity;
  late final FocusNode _composerFocus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseOpacity = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _composerFocus = FocusNode(onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
      if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
      if (!_isLoading) _send();
      return KeyEventResult.handled;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerFocus.requestFocus();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _pulseCtrl.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    _controller.clear();
    _composerFocus.requestFocus();
    _scrollToBottom();
    await ref.read(interviewProvider(widget.args).notifier).addUserMessage(text);
    _scrollToBottom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final stateAsync = ref.watch(interviewProvider(args));
    _isLoading = stateAsync.valueOrNull?.isLoading ?? false;
    final notifier = ref.read(interviewProvider(args).notifier);
    final modeLabel = args.mode == ProjectMode.build ? 'Build' : 'Audit';

    ref.listen(interviewProvider(args), (prev, next) {
      final prevLen = prev?.valueOrNull?.turns.length ?? 0;
      final nextLen = next.valueOrNull?.turns.length ?? 0;
      if (nextLen > prevLen) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('$modeLabel Interview — ${args.name}'),
        actions: [
          _DocCountChip(projectPath: args.path),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restart interview',
            onPressed: notifier.reset,
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $error'),
          ),
        ),
        data: (state) {
          return Column(
            children: [
              if (args.priorSpecVersion != null &&
                  state.featureContext != null)
                _V1BuiltHeader(
                  featureContext: state.featureContext!,
                  priorVersion: args.priorSpecVersion!,
                ),
              if (args.mode == ProjectMode.build &&
                  state.currentLayer.isNotEmpty)
                _InterviewLayerStrip(
                  currentLayer: state.currentLayer,
                  allComplete: state.specGenEnabled,
                  pulseOpacity: _pulseOpacity,
                  priorVersion: args.priorSpecVersion,
                ),
              ConfidenceMeter(
                dimensions: state.dimensions,
                confidenceMap: state.confidenceMap,
              ),
              if (state.openConflicts.isNotEmpty)
                _ConflictSurface(
                  conflicts: state.openConflicts,
                  isLoading: state.isLoading,
                  onResolve: notifier.resolveConflict,
                ),
              if (state.llmUnavailable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: const Color(0xFF1C1C1E),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 12, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'No LLM configured — running in offline mode. Add a key in Settings.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontFamily: 'Menlo'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/settings'),
                        child: const Text('Settings', style: TextStyle(fontSize: 11, color: Color(0xFFE8A04C))),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: state.turns.isEmpty
                    ? _EmptyChat(dimensionCount: state.dimensions.length)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.turns.length,
                        itemBuilder: (context, i) {
                          final turn = state.turns[i];
                          return _TurnBubble(
                            turn: turn,
                            onEdit: turn.isUser
                                ? () {
                                    _controller.text = turn.content;
                                    notifier.rewindTo(i);
                                    _composerFocus.requestFocus();
                                  }
                                : null,
                          );
                        },
                      ),
              ),
              _Composer(
                controller: _controller,
                focusNode: _composerFocus,
                isLoading: _isLoading,
                onSend: _send,
              ),
              // Escape hatch: if the LLM completed L4 but the gate didn't fire
              // (e.g. externalServices parsed as a string instead of a list),
              // surface a manual override after enough turns.
              if (!state.specGenEnabled &&
                  state.currentLayer == 'L4' &&
                  state.turns.where((t) => t.isUser).length >= 4)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        final interviewState =
                            ref.read(interviewProvider(args)).valueOrNull;
                        if (interviewState == null) return;
                        final targetVersion = args.priorSpecVersion != null
                            ? nextSpecVersion(args.priorSpecVersion!)
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
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                      ),
                      child: const Text(
                        'Interview finished but button not appearing? → Generate spec with current data',
                        style: TextStyle(fontSize: 11, fontFamily: 'Menlo'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              if (state.specGenEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(args.priorSpecVersion != null
                          ? 'Generate ${nextSpecVersion(args.priorSpecVersion!)} Spec'
                          : 'Generate Spec'),
                      onPressed: () {
                        final interviewState =
                            ref.read(interviewProvider(args)).valueOrNull;
                        if (interviewState == null) return;
                        final targetVersion = args.priorSpecVersion != null
                            ? nextSpecVersion(args.priorSpecVersion!)
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
            ],
          );
        },
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.dimensionCount});

  final int dimensionCount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Type a greeting to start the interview.\n\n'
          'You will be walked through $dimensionCount confidence dimensions.\n'
          'Conflicts between answers will be surfaced before spec generation.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TurnBubble extends StatelessWidget {
  const _TurnBubble({required this.turn, this.onEdit});
  final InterviewTurn turn;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    final bubbleColor =
        isUser ? const Color(0xFF1F2937) : const Color(0xFF1C1C1E);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 640),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'YOU' : 'INTERVIEWER',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  turn.content,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Menlo',
                    height: 1.4,
                    color: Color(0xFFE5E5E7),
                  ),
                ),
              ],
            ),
          ),
          if (isUser && onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 6, right: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 11,
                        color: Color(0xFF4B5563)),
                    SizedBox(width: 3),
                    Text(
                      'edit',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF4B5563),
                        fontFamily: 'Menlo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConflictSurface extends StatelessWidget {
  const _ConflictSurface({
    required this.conflicts,
    required this.isLoading,
    required this.onResolve,
  });

  final List<ConflictItem> conflicts;
  final bool isLoading;
  final void Function(String conflictId) onResolve;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2A1F0A),
        border: Border(
          top: BorderSide(color: Color(0xFFE8A04C), width: 1),
          bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < conflicts.length; i++) ...[
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFE8A04C),
                ),
                const SizedBox(width: 6),
                Text(
                  'CONFLICT — ${conflicts[i].dimensionALabel} ↔ ${conflicts[i].dimensionBLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Color(0xFFE8A04C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              conflicts[i].description,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Menlo',
                height: 1.4,
                color: Color(0xFFE5E5E7),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed:
                    isLoading ? null : () => onResolve(conflicts[i].id),
                child: Text('Accept: ${conflicts[i].recommendation}'),
              ),
            ),
            if (i < conflicts.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        border: Border(
          top: BorderSide(color: Color(0xFF2C2C2E), width: 1),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                textField: true,
                label: 'Interview response',
                child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isLoading,
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 13,
                  color: Color(0xFFE5E5E7),
                ),
                decoration: InputDecoration(
                  hintText: isLoading
                      ? 'Thinking…'
                      : 'Type your answer… (Shift+Enter for new line)',
                  hintStyle: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontFamily: 'Menlo',
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0F0F10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFE8A04C)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              width: 44,
              child: FilledButton(
                onPressed: isLoading ? null : onSend,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFFE8A04C),
                  foregroundColor: const Color(0xFF0F0F10),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0F0F10),
                        ),
                      )
                    : const Icon(Icons.send, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterviewLayerStrip extends StatelessWidget {
  const _InterviewLayerStrip({
    required this.currentLayer,
    required this.allComplete,
    required this.pulseOpacity,
    this.priorVersion,
  });

  final String currentLayer;
  final bool allComplete;
  final Animation<double> pulseOpacity;
  final String? priorVersion;

  @override
  Widget build(BuildContext context) {
    const layers = ['L1', 'L2', 'L3', 'L4'];
    const labels = ['Outcome', 'Decomposition', 'PoC', 'Critical Path'];
    final idx = layers.indexOf(currentLayer);
    final completed = idx > 0 ? layers.sublist(0, idx) : <String>[];
    final label = priorVersion != null
        ? '${nextSpecVersion(priorVersion!).toUpperCase()} FUNNEL'
        : 'FUNNEL';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F10),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF6B7280),
              fontFamily: 'Menlo',
            ),
          ),
          const SizedBox(width: 16),
          for (int i = 0; i < layers.length; i++) ...[
            _LayerIndicator(
              id: layers[i],
              label: labels[i],
              isDone: allComplete || completed.contains(layers[i]),
              isCurrent: !allComplete && currentLayer == layers[i],
              pulseOpacity: pulseOpacity,
            ),
            if (i < layers.length - 1)
              Container(
                width: 28,
                height: 1,
                margin: const EdgeInsets.only(bottom: 14),
                color: (allComplete || completed.contains(layers[i]))
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF2C2C2E),
              ),
          ],
        ],
      ),
    );
  }
}

class _LayerIndicator extends StatelessWidget {
  const _LayerIndicator({
    required this.id,
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.pulseOpacity,
  });

  final String id;
  final String label;
  final bool isDone;
  final bool isCurrent;
  final Animation<double> pulseOpacity;

  @override
  Widget build(BuildContext context) {
    Widget dot;
    Color textColor;

    if (isDone) {
      dot = const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14);
      textColor = const Color(0xFF22C55E);
    } else if (isCurrent) {
      dot = FadeTransition(
        opacity: pulseOpacity,
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE8A04C),
          ),
        ),
      );
      textColor = const Color(0xFFE8A04C);
    } else {
      dot = Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3D4452), width: 1.0),
        ),
      );
      textColor = const Color(0xFF4B5563);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 3),
        Text(
          id,
          style: TextStyle(
            fontSize: 9,
            fontFamily: 'Menlo',
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontFamily: 'Menlo',
            color: textColor.withAlpha(180),
          ),
        ),
      ],
    );
  }
}

class _V1BuiltHeader extends StatelessWidget {
  const _V1BuiltHeader({
    required this.featureContext,
    required this.priorVersion,
  });

  final String featureContext;
  final String priorVersion;

  List<String> _parseComponents() {
    final lines = featureContext.split('\n');
    bool inSection = false;
    bool pastHeader = false;
    final result = <String>[];
    for (final line in lines) {
      if (RegExp(r'##\s+\d*\.?\s*Component\s+(Map|List)', caseSensitive: false)
          .hasMatch(line)) {
        inSection = true;
        pastHeader = false;
        continue;
      }
      if (inSection) {
        if (line.trim().startsWith('#')) break;
        if (!line.trim().startsWith('|')) continue;
        if (!pastHeader) {
          if (line.contains('---')) pastHeader = true;
          continue;
        }
        final cols = line
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cols.isNotEmpty) {
          final name = cols[0].replaceAll(RegExp(r'[`*_]'), '').trim();
          if (name.isNotEmpty) result.add(name);
        }
      }
    }
    return result;
  }

  String? _parseGoal() {
    final lines = featureContext.split('\n');
    bool inSection = false;
    for (final line in lines) {
      if (RegExp(r'##\s+\d*\.?\s*(Immutable )?Goal Statement', caseSensitive: false)
          .hasMatch(line)) {
        inSection = true;
        continue;
      }
      if (inSection) {
        final t = line.trim();
        if (t.isEmpty) continue;
        if (t.startsWith('#')) break;
        return t.replaceAll(RegExp(r'^\*+|\*+$'), '').trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final components = _parseComponents();
    final goal = _parseGoal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1A0E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1A3324), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 12),
              const SizedBox(width: 6),
              Text(
                '${priorVersion.toUpperCase()} SHIPPED',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontFamily: 'Menlo',
                  color: Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          if (goal != null) ...[
            const SizedBox(height: 4),
            Text(
              goal,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Menlo',
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
          if (components.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final c in components)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2318),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF1A3324)),
                    ),
                    child: Text(
                      c,
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'Menlo',
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DocCountChip extends ConsumerWidget {
  const _DocCountChip({required this.projectPath});
  final String projectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(ingestionNotifierProvider).docs.length;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: TextButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ReferenceDocsScreen(projectPath: projectPath),
            ),
          );
        },
        icon: const Icon(Icons.upload_file_outlined,
            size: 14, color: Color(0xFF9CA3AF)),
        label: Text(
          '$count doc${count == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: 11,
            fontFamily: 'Menlo',
            color: Color(0xFF9CA3AF),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
