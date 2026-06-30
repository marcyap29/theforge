import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ingestion/reverse_ingestion_notifier.dart';
import '../models/reverse_ingestion_summary.dart';
import 'reverse_ingestion_summary_screen.dart';

class ReverseIngestionProgressScreen extends ConsumerWidget {
  final String projectPath;

  const ReverseIngestionProgressScreen({
    super.key,
    required this.projectPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reverseIngestionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingesting Codebase'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: switch (s.state) {
        IngestionState.done => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    size: 80, color: Color(0xFF22C55E)),
                const SizedBox(height: 16),
                const Text(
                  'Ingestion Complete',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Menlo',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReverseIngestionSummaryScreen(
                        projectPath: projectPath,
                        projectName: projectPath.split('/').last,
                      ),
                    ),
                  ),
                  child: const Text('View Summary →'),
                ),
              ],
            ),
          ),
        IngestionState.error => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 80, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Text(
                  s.error ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFEF4444), fontFamily: 'Menlo'),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => ref
                      .read(reverseIngestionNotifierProvider.notifier)
                      .startIngestion(projectPath),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        _ => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFFE8A04C)),
                const SizedBox(height: 24),
                Text(
                  switch (s.state) {
                    IngestionState.scanning => 'Scanning codebase...',
                    IngestionState.processing => 'Extracting component info...',
                    IngestionState.aggregating => 'Aggregating results...',
                    _ => 'Preparing...',
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Menlo',
                    color: Color(0xFFE5E5E7),
                  ),
                ),
              ],
            ),
          ),
      },
    );
  }
}
