import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'briefing_notifier.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingAsync = ref.watch(briefingProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Briefing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Run Briefing',
            onPressed: () => ref.read(briefingProvider.notifier).runBriefing(),
          ),
        ],
      ),
      body: briefingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8A04C)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: $e',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontFamily: 'Menlo',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.read(briefingProvider.notifier).runBriefing(),
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _buildBody(context, ref, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BriefingState data) {
    switch (data.status) {
      case BriefingStatus.idle:
        return _IdleState(context);
      case BriefingStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8A04C)),
        );
      case BriefingStatus.done:
        return _displayMarkdown(data.markdown ?? '');
      case BriefingStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  data.errorMessage ?? 'Unknown error',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 14,
                    fontFamily: 'Menlo',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.read(briefingProvider.notifier).runBriefing(),
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _displayMarkdown(String markdown) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: SelectableText(
            markdown,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 13,
              color: Color(0xFFE5E5E7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _IdleState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            color: Color(0xFFE8A04C),
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'Run Briefing',
            style: TextStyle(
              color: Color(0xFFE5E5E7),
              fontSize: 18,
              fontFamily: 'Menlo',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Click the refresh icon to generate a deep research briefing using SwarmSpace',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
              fontFamily: 'Menlo',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
