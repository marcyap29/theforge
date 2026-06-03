import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../providers/interview_providers.dart';
import '../state/interview_state.dart';
import 'confidence_meter.dart';

class InterviewScreen extends ConsumerStatefulWidget {
  const InterviewScreen({super.key, required this.args});

  final InterviewArgs args;

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final stateAsync = ref.watch(interviewProvider(args));
    final notifier = ref.read(interviewProvider(args).notifier);
    final modeLabel = args.mode == ProjectMode.build ? 'Build' : 'Audit';

    return Scaffold(
      appBar: AppBar(
        title: Text('$modeLabel Interview — ${args.name}'),
        actions: [
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
              Expanded(
                child: state.turns.isEmpty
                    ? _EmptyChat(dimensionCount: state.dimensions.length)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.turns.length,
                        itemBuilder: (context, i) =>
                            _TurnBubble(turn: state.turns[i]),
                      ),
              ),
              _Composer(
                controller: _controller,
                isLoading: state.isLoading,
                onSend: (text) async {
                  await notifier.addUserMessage(text);
                  _controller.clear();
                  _scrollToBottom();
                },
              ),
              if (state.specGenEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate Spec'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Spec generation — coming in §6.'),
                            duration: Duration(seconds: 2),
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
  const _TurnBubble({required this.turn});
  final InterviewTurn turn;

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    final bubbleColor =
        isUser ? const Color(0xFF1F2937) : const Color(0xFF1C1C1E);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isLoading;
  final Future<void> Function(String text) onSend;

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
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 13,
                  color: Color(0xFFE5E5E7),
                ),
                decoration: InputDecoration(
                  hintText: isLoading ? 'Thinking…' : 'Type your answer…',
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
                onSubmitted: isLoading
                    ? null
                    : (text) {
                        if (text.trim().isEmpty) return;
                        onSend(text);
                      },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              width: 44,
              child: FilledButton(
                onPressed: isLoading
                    ? null
                    : () {
                        if (controller.text.trim().isEmpty) return;
                        onSend(controller.text);
                      },
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
