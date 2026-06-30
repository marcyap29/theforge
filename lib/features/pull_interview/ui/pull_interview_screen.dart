import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/spec_generation/as_built_spec_screen.dart';
import '../state/pull_interview_state.dart';

class PullInterviewScreen extends ConsumerStatefulWidget {
  const PullInterviewScreen({super.key, required this.args});

  final PullInterviewArgs args;

  @override
  ConsumerState<PullInterviewScreen> createState() =>
      _PullInterviewScreenState();
}

class _PullInterviewScreenState
    extends ConsumerState<PullInterviewScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final FocusNode _composerFocus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _composerFocus = FocusNode(onKeyEvent: (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey != LogicalKeyboardKey.enter) {
        return KeyEventResult.ignored;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      }
      if (!_isLoading) _send();
      return KeyEventResult.handled;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _composerFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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
    await ref
        .read(pullInterviewProvider(widget.args).notifier)
        .addUserMessage(text);
    _scrollToBottom();
  }

  Future<void> _generateSpec(PullInterviewState state) async {
    await ref
        .read(pullInterviewProvider(widget.args).notifier)
        .markComplete();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AsBuiltSpecScreen(
        projectPath: widget.args.projectPath,
        projectName: widget.args.projectName,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(pullInterviewProvider(widget.args));
    final state = stateAsync.valueOrNull;
    _isLoading = state?.isLoading ?? false;

    ref.listen(pullInterviewProvider(widget.args), (_, next) {
      if (next.valueOrNull?.turns.isNotEmpty ?? false) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Pull Interview — ${widget.args.projectName}'),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (s) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: s.turns.length,
                itemBuilder: (context, i) {
                  final turn = s.turns[i];
                  return _ChatBubble(turn: turn);
                },
              ),
            ),
            if (s.error != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  s.error!,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontFamily: 'Menlo',
                    fontSize: 12,
                  ),
                ),
              ),
            _Composer(
              controller: _controller,
              focusNode: _composerFocus,
              isLoading: _isLoading,
              onSend: _send,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: s.canGenerateSpec && !_isLoading
                      ? () => _generateSpec(s)
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: const Color(0xFFE8A04C),
                    foregroundColor: const Color(0xFF0F0F10),
                    disabledBackgroundColor: const Color(0xFF2C2C2E),
                    disabledForegroundColor: const Color(0xFF6B7280),
                  ),
                  child: const Text(
                    'Generate As-Built Spec →',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontFamily: 'Menlo'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final PullInterviewTurn turn;
  const _ChatBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF78350F)
              : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
          border: isUser
              ? null
              : Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 13,
            height: 1.5,
            color: isUser
                ? const Color(0xFFFDE68A)
                : const Color(0xFFE5E5E7),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F10),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isLoading,
              maxLines: null,
              style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 13,
                  color: Color(0xFFE5E5E7)),
              decoration: const InputDecoration(
                hintText: 'Answer the question… (Enter to send)',
                hintStyle: TextStyle(color: Color(0xFF6B7280)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isLoading ? null : onSend,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFFE8A04C)),
                  )
                : const Icon(Icons.send, color: Color(0xFFE8A04C)),
          ),
        ],
      ),
    );
  }
}
