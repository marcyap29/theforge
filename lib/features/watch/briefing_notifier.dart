import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/swarmspace/swarmspace_service_provider.dart';
import 'watch_data_notifier.dart';

enum BriefingStatus { idle, loading, done, error }

class BriefingState {
  final BriefingStatus status;
  final String? markdown;
  final String? errorMessage;

  const BriefingState({
    this.status = BriefingStatus.idle,
    this.markdown,
    this.errorMessage,
  });

  BriefingState copyWith({
    BriefingStatus? status,
    String? markdown,
    String? errorMessage,
  }) {
    return BriefingState(
      status: status ?? this.status,
      markdown: markdown ?? this.markdown,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BriefingNotifier extends AsyncNotifier<BriefingState> {
  @override
  Future<BriefingState> build() async => const BriefingState();

  Future<void> runBriefing() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final watchData = ref.read(watchDataProvider);
      if (watchData.value == null) {
        throw Exception('Watch data not loaded');
      }

      final service = ref.read(swarmspaceServiceProvider);
      if (service == null) {
        throw Exception('SwarmSpace API key not configured');
      }

      final markdown =
          await service.deepResearch(_buildQuery(watchData.value!));

      return BriefingState(
        status: BriefingStatus.done,
        markdown: markdown,
      );
    });
  }

  String _buildQuery(WatchData watchData) {
    final allCommits = watchData.allCommits;
    final workspaceSignals = watchData.workspaceSignals;

    return '''
# The Forge Briefing Request

## Context
This briefing aggregates recent development activity and failure signals from The Forge monitoring system.

## Git Activity Summary
- Total commits analyzed: ${allCommits.length}
- Time period: Recent activity in repository

## Failure Signals Detected
${workspaceSignals.map((s) => '- ${s.type.name}: ${s.detail}').join('\n')}

## Request
Please provide a deep research briefing on recent development patterns, potential issues, and recommendations based on the above data.
''';
  }
}

final briefingProvider =
    AsyncNotifierProvider<BriefingNotifier, BriefingState>(
  BriefingNotifier.new,
);
