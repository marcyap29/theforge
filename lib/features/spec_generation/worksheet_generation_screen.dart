import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Worksheet — ${widget.projectName}'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (state.status) {
            WorksheetGenStatus.idle ||
            WorksheetGenStatus.generating =>
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE8A04C)),
                  SizedBox(height: 24),
                  Text(
                    'Generating setup worksheet…\nThis takes 10–20 seconds.',
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
            WorksheetGenStatus.done => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF22C55E), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Worksheet ready — ${state.worksheetFilename}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE5E5E7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete the worksheet before starting the executor.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A04C),
                      foregroundColor: const Color(0xFF0F0F10),
                    ),
                    child: const Text('Back to Projects'),
                  ),
                ],
              ),
            WorksheetGenStatus.error => Column(
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
                    onPressed: () => ref
                        .read(worksheetNotifierProvider.notifier)
                        .generate(
                          projectPath: widget.projectPath,
                          projectName: widget.projectName,
                          specVersion: widget.specVersion,
                        ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
