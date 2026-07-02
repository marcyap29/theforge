import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ingestion/pull_ingestion_notifier.dart';
import '../models/pull_ingestion_summary.dart';
import 'pull_ingestion_summary_screen.dart';

class PullIngestionProgressScreen extends ConsumerStatefulWidget {
  final String projectPath;

  const PullIngestionProgressScreen({super.key, required this.projectPath});

  @override
  ConsumerState<PullIngestionProgressScreen> createState() =>
      _PullIngestionProgressScreenState();
}

class _PullIngestionProgressScreenState
    extends ConsumerState<PullIngestionProgressScreen> {
  Set<String> _confirmedModules = {};

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(pullIngestionNotifierProvider);

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
              const Icon(
                Icons.check_circle,
                size: 80,
                color: Color(0xFF22C55E),
              ),
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
                    builder: (_) => PullIngestionSummaryScreen(
                      projectPath: widget.projectPath,
                      projectName: widget.projectPath.split('/').last,
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
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              Text(
                s.error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontFamily: 'Menlo',
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => ref
                    .read(pullIngestionNotifierProvider.notifier)
                    .startIngestion(widget.projectPath),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        IngestionState.awaitingConfirmation => _buildConfirmation(s),
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
                  IngestionState.synthesizing => 'Synthesizing modules...',
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

  Widget _buildConfirmation(PullIngestionState s) {
    final modules = s.detectedModules ?? [];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm Detected Modules',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Menlo',
              color: Color(0xFFE5E5E7),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select which modules to ingest. All are checked by default.',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Menlo',
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: modules.map((name) {
                final isChecked =
                    _confirmedModules.isEmpty ||
                    _confirmedModules.contains(name);
                return CheckboxListTile(
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Menlo',
                      color: Color(0xFFE5E5E7),
                    ),
                  ),
                  value: isChecked,
                  activeColor: const Color(0xFFE8A04C),
                  onChanged: (checked) {
                    setState(() {
                      if (_confirmedModules.isEmpty) {
                        _confirmedModules = Set<String>.from(modules);
                      }
                      if (checked == true) {
                        _confirmedModules.add(name);
                      } else {
                        _confirmedModules.remove(name);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: modules.isNotEmpty
                  ? () {
                      final toConfirm = _confirmedModules.isEmpty
                          ? List<String>.from(modules)
                          : _confirmedModules.toList();
                      ref
                          .read(pullIngestionNotifierProvider.notifier)
                          .confirmModules(toConfirm, widget.projectPath);
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8A04C),
              ),
              child: const Text('Confirm →'),
            ),
          ),
        ],
      ),
    );
  }
}
