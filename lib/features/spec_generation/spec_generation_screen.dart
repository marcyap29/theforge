import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interview/state/interview_state.dart';
import 'generation_widgets.dart';
import 'spec_notifier.dart';
import 'spec_providers.dart';
import 'worksheet_generation_screen.dart';

class SpecGenerationScreen extends ConsumerStatefulWidget {
  const SpecGenerationScreen({
    super.key,
    required this.interviewState,
    this.targetSpecVersion = 'v1',
  });
  final InterviewState interviewState;
  final String targetSpecVersion;

  @override
  ConsumerState<SpecGenerationScreen> createState() =>
      _SpecGenerationScreenState();
}

class _SpecGenerationScreenState extends ConsumerState<SpecGenerationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(specNotifierProvider.notifier).generate(
            widget.interviewState,
            targetSpecVersion: widget.targetSpecVersion,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(specNotifierProvider);
    final projectName = widget.interviewState.projectName;

    final isDone = state.status == SpecGenStatus.done;

    return Scaffold(
      appBar: AppBar(
        title: Text('Generating Spec — $projectName'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          GenerationPhaseBar(currentStep: 'spec', isDone: isDone),
          Expanded(
            child: switch (state.status) {
              SpecGenStatus.idle || SpecGenStatus.generating => _GeneratingBody(
                  projectName: projectName,
                ),
              SpecGenStatus.done => _DoneBody(
                  specFilename: state.specFilename ?? 'spec',
                  onWorksheet: () {
                    final specVersion = state.specVersion ?? 'v1';
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => WorksheetGenerationScreen(
                        projectPath: widget.interviewState.projectPath,
                        projectName: projectName,
                        specVersion: specVersion,
                      ),
                    ));
                  },
                  onBack: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              SpecGenStatus.error => _ErrorBody(
                  message: state.errorMessage ?? 'Unknown error',
                  onRetry: () => ref
                      .read(specNotifierProvider.notifier)
                      .generate(widget.interviewState),
                  onBack: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
            },
          ),
        ],
      ),
    );
  }
}

// ── Generating ────────────────────────────────────────────────────────────────

class _GeneratingBody extends StatelessWidget {
  const _GeneratingBody({required this.projectName});
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(32, 32, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spinner + status
          Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: Color(0xFFE8A04C)),
                SizedBox(height: 20),
                Text(
                  'Building your locked spec…  15–30 seconds.',
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
          ),
          SizedBox(height: 36),

          // What's being generated
          Text(
            'WHAT\'S BEING GENERATED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF6B7280),
              fontFamily: 'Menlo',
            ),
          ),
          SizedBox(height: 10),
          ArtifactInfoCard(
            title: 'Locked Spec',
            description:
                'The immutable architecture blueprint. Every executor agent builds '
                'against this document exactly. Once written it is never edited — '
                'amendments produce a new versioned spec.',
          ),
          SizedBox(height: 8),
          ArtifactInfoCard(
            title: 'Bullet Handoff',
            description:
                'A human-scannable phase summary: what was decided, what was '
                'explicitly deferred, and what the next agent or session needs to '
                'know. This is also your v2 interview starting point.',
          ),
          SizedBox(height: 8),
          ArtifactInfoCard(
            title: '/goal text',
            description:
                'Your spec translated into executor harness format. Paste this '
                'directly into Claude Code, or any autonomous build agent, to start '
                'the build loop. Includes your Completion Criteria as checkable items.',
          ),
          SizedBox(height: 8),
          ArtifactInfoCard(
            title: 'Handoff Package',
            description:
                'Structured JSON summary of the full Forge run. The Forge MCP server '
                'reads this to route your project and provide context to executor '
                'agents in subsequent sessions.',
          ),
          SizedBox(height: 36),

          // Tips
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 12, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Text(
                'WHILE YOU WAIT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Color(0xFF6B7280),
                  fontFamily: 'Menlo',
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          TipRotator(tips: specGenTips),
        ],
      ),
    );
  }
}

// ── Done ──────────────────────────────────────────────────────────────────────

class _DoneBody extends StatelessWidget {
  const _DoneBody({
    required this.specFilename,
    required this.onWorksheet,
    required this.onBack,
  });

  final String specFilename;
  final VoidCallback onWorksheet;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
              'Spec locked — $specFilename',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5E7),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bullet Handoff, /goal text, and Handoff Package written.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 260,
              child: FilledButton(
                onPressed: onWorksheet,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A04C),
                  foregroundColor: const Color(0xFF0F0F10),
                ),
                child: const Text('Generate Setup Worksheet →'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text(
                'Back to Projects',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
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
              message,
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
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onBack,
              child: const Text(
                'Back to Projects',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
