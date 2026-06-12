import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'generation_widgets.dart';
import 'worksheet_notifier.dart';

class WorksheetGenerationScreen extends ConsumerStatefulWidget {
  const WorksheetGenerationScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
    required this.specVersion,
  });

  final String projectPath;
  final String projectName;
  final String specVersion;

  @override
  ConsumerState<WorksheetGenerationScreen> createState() =>
      _WorksheetGenerationScreenState();
}

class _WorksheetGenerationScreenState
    extends ConsumerState<WorksheetGenerationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(worksheetNotifierProvider.notifier).generate(
            projectPath: widget.projectPath,
            projectName: widget.projectName,
            specVersion: widget.specVersion,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(worksheetNotifierProvider);
    final isDone = state.status == WorksheetGenStatus.done;

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Worksheet — ${widget.projectName}'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          GenerationPhaseBar(currentStep: 'worksheet', isDone: isDone),
          Expanded(
            child: switch (state.status) {
              WorksheetGenStatus.idle ||
              WorksheetGenStatus.generating =>
                _GeneratingBody(projectName: widget.projectName),
              WorksheetGenStatus.done => _DoneBody(
                  worksheetFilename:
                      state.worksheetFilename ?? 'worksheet',
                  onBack: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                ),
              WorksheetGenStatus.error => _ErrorBody(
                  message: state.errorMessage ?? 'Unknown error',
                  onRetry: () =>
                      ref.read(worksheetNotifierProvider.notifier).generate(
                            projectPath: widget.projectPath,
                            projectName: widget.projectName,
                            specVersion: widget.specVersion,
                          ),
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
                  'Building your setup worksheet…  10–20 seconds.',
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
            title: 'Setup Worksheet',
            description:
                'A step-by-step human-action checklist for every external service '
                'your build requires — account creation, API key generation, '
                'security configuration, and environment variables. Complete this '
                'before the executor starts. The executor cannot run without it.',
          ),
          SizedBox(height: 8),
          ArtifactInfoCard(
            title: 'Environment Variables Table',
            description:
                'The exact variable names and values your executor needs, '
                'formatted to paste directly into your harness config. '
                'Free tier limits are listed for every service so V1 ships at zero cost.',
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
          TipRotator(tips: worksheetTips),
        ],
      ),
    );
  }
}

// ── Done ──────────────────────────────────────────────────────────────────────

class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.worksheetFilename, required this.onBack});

  final String worksheetFilename;
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
              'Worksheet ready — $worksheetFilename',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5E7),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Complete every step in the worksheet before starting your executor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onBack,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8A04C),
                foregroundColor: const Color(0xFF0F0F10),
              ),
              child: const Text('Back to Projects'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              'Worksheet generation failed',
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
          ],
        ),
      ),
    );
  }
}
