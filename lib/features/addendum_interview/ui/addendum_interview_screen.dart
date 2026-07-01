import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/addendum_interview_notifier.dart';

class AddendumInterviewScreen extends ConsumerStatefulWidget {
  const AddendumInterviewScreen({required this.args});
  final AddendumInterviewArgs args;

  @override
  ConsumerState<AddendumInterviewScreen> createState() =>
      _AddendumInterviewScreenState();
}

class _AddendumInterviewScreenState
    extends ConsumerState<AddendumInterviewScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(AddendumInterviewNotifier notifier) {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    notifier.addUserMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(addendumInterviewProvider(widget.args));
    final notifier =
        ref.read(addendumInterviewProvider(widget.args).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          '${widget.args.projectName} — Addendum ${widget.args.baseVersion}.1',
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 13,
            color: Color(0xFFE5E5E7),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF6B7280)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF2C2C2E)),
        ),
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e.toString(),
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontFamily: 'Menlo')),
        ),
        data: (state) {
          if (state.isComplete) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF22C55E), size: 48),
                    const SizedBox(height: 16),
                    Text(
                      '${state.minorVersion} spec generated',
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 16,
                        color: Color(0xFFE5E5E7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.specFilename ?? '',
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A04C),
                        foregroundColor: const Color(0xFF0F0F10),
                      ),
                      child: const Text('Done',
                          style: TextStyle(
                              fontFamily: 'Menlo',
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            );
          }

          _scrollToBottom();

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.turns.length,
                  itemBuilder: (context, i) {
                    final turn = state.turns[i];
                    return Align(
                      alignment: turn.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: 560),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: turn.isUser
                              ? const Color(0xFF1C1C1E)
                              : const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: turn.isUser
                                ? const Color(0xFF3C3C3E)
                                : const Color(0xFF2C2C2E),
                          ),
                        ),
                        child: Text(
                          turn.text,
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 12,
                            height: 1.6,
                            color: Color(0xFFE5E5E7),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontFamily: 'Menlo',
                        fontSize: 11),
                  ),
                ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Color(0xFF2C2C2E))),
                  color: Color(0xFF141414),
                ),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    if (state.turns.length >= 3)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: state.isLoading
                                ? null
                                : notifier.generateMinorSpec,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE8A04C),
                              foregroundColor: const Color(0xFF0F0F10),
                              disabledBackgroundColor:
                                  const Color(0xFF2C2C2E),
                            ),
                            child: Text(
                              'Generate ${state.minorVersion} Spec',
                              style: const TextStyle(
                                  fontFamily: 'Menlo',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            enabled: !state.isLoading,
                            style: const TextStyle(
                              fontFamily: 'Menlo',
                              fontSize: 12,
                              color: Color(0xFFE5E5E7),
                            ),
                            decoration: InputDecoration(
                              hintText: state.isLoading
                                  ? 'Thinking…'
                                  : 'Describe what to add…',
                              hintStyle: const TextStyle(
                                  fontFamily: 'Menlo',
                                  fontSize: 12,
                                  color: Color(0xFF6B7280)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFF3C3C3E)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFF3C3C3E)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE8A04C)),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) => _send(notifier),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: state.isLoading
                              ? null
                              : () => _send(notifier),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE8A04C),
                            foregroundColor: const Color(0xFF0F0F10),
                            disabledBackgroundColor:
                                const Color(0xFF2C2C2E),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Send',
                              style: TextStyle(
                                  fontFamily: 'Menlo',
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
