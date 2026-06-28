import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/watch/spec_drift_engine.dart';
import 'watch_data_notifier.dart';

class SpecDriftScreen extends ConsumerWidget {
  const SpecDriftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(watchDataProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Spec Drift'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(watchDataProvider.notifier).refresh(),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8A04C)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _buildBody(data.specDrift),
      ),
    );
  }

  Widget _buildBody(List<SpecDriftResult> results) {
    if (results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline,
                  color: Color(0xFF22C55E), size: 48),
              SizedBox(height: 16),
              Text(
                'No spec drift detected',
                style: TextStyle(
                  color: Color(0xFFE5E5E7),
                  fontSize: 16,
                  fontFamily: 'Menlo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Projects with locked specs and a configured repo path\n'
                'will appear here when drift is detected.',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontFamily: 'Menlo',
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: results.map((r) => _DriftCard(result: r)).toList(),
    );
  }
}

class _DriftCard extends StatelessWidget {
  const _DriftCard({required this.result});
  final SpecDriftResult result;

  @override
  Widget build(BuildContext context) {
    final scoreColor = result.driftScore >= 70
        ? const Color(0xFFEF4444)
        : result.driftScore >= 30
            ? const Color(0xFFE8A04C)
            : const Color(0xFF22C55E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.projectName,
                  style: const TextStyle(
                    color: Color(0xFFE5E5E7),
                    fontSize: 14,
                    fontFamily: 'Menlo',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${result.specVersion} · '
                  '${result.failedCount} missing · '
                  '${result.uncertainCount} partial',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                    fontFamily: 'Menlo',
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.driftScore}',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 24,
                  fontFamily: 'Menlo',
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '/ 100',
                style: TextStyle(
                  color: scoreColor.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontFamily: 'Menlo',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
