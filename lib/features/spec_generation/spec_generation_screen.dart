import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interview/state/interview_state.dart';
import 'spec_notifier.dart';
import 'spec_providers.dart';
import 'worksheet_generation_screen.dart';

class SpecGenerationScreen extends ConsumerStatefulWidget {
  const SpecGenerationScreen({super.key, required this.interviewState});
  final InterviewState interviewState;

  @override
  ConsumerState<SpecGenerationScreen> createState() =>
      _SpecGenerationScreenState();
}

class _SpecGenerationScreenState
    extends ConsumerState<SpecGenerationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(specNotifierProvider.notifier).generate(widget.interviewState);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(specNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Generating Spec — ${widget.interviewState.projectName}'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (state.status) {
            SpecGenStatus.idle || SpecGenStatus.generating => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE8A04C)),
                  SizedBox(height: 24),
                  Text(
                    'Generating locked spec…\nThis takes 15–30 seconds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 13,
                      height: 1.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            SpecGenStatus.done => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF22C55E), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Spec locked — ${state.specFilename}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE5E5E7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bullet Handoff, /goal text, and Handoff Package written.',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 260,
                    child: FilledButton(
                      onPressed: () {
                        final specVersion = state.specVersion ?? 'v1';
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorksheetGenerationScreen(
                              projectPath:
                                  widget.interviewState.projectPath,
                              projectName:
                                  widget.interviewState.projectName,
                              specVersion: specVersion,
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A04C),
                        foregroundColor: const Color(0xFF0F0F10),
                      ),
                      child: const Text('Generate Setup Worksheet →'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text(
                      'Back to Projects',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            SpecGenStatus.error => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFEF4444), size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Spec generation failed',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE5E5E7)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
                      color: Color(0xFFEF4444),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(specNotifierProvider.notifier)
                            .generate(widget.interviewState),
                    child: const Text('Try Again'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    child: const Text(
                      'Back to Projects',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
