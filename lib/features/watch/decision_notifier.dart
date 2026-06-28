import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/swarmspace/swarmspace_service_provider.dart';
import 'decision_models.dart';
import 'watch_data_notifier.dart';

class DecisionNotifier extends AsyncNotifier<DecisionResult?> {
  @override
  Future<DecisionResult?> build() async => null;

  Future<void> runSimulation(DecisionInput input) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final watchDataAsync = ref.read(watchDataProvider);
      if (watchDataAsync.value == null) throw Exception('Watch data not loaded');

      final service = ref.read(swarmspaceServiceProvider);
      if (service == null) throw Exception('SwarmSpace API key not configured');

      final query = _buildQuery(input, watchDataAsync.value!);
      final markdown = await service.deepResearch(query);
      return DecisionResult(markdown: markdown, simulatedAt: DateTime.now());
    });
  }

  void reset() => state = const AsyncData(null);

  String _buildQuery(DecisionInput input, WatchData watchData) {
    final totalSpend = watchData.usage.fold<double>(0, (s, u) => s + u.totalCostUSD30d);
    final optionsList = input.options
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    return '''
# Engineering Decision Simulation

## Decision
${input.question}

## Context & Constraints
${input.context}

## Options Under Consideration
$optionsList

## Engineering Telemetry
- Workspace spend (30d): \$${totalSpend.toStringAsFixed(0)}
- Active failure signals: ${watchData.workspaceSignals.length}
- Signal types: ${watchData.workspaceSignals.map((s) => s.type.name).join(', ')}

## Simulation Request
Run a 50-iteration Monte Carlo simulation. Vary: market conditions, team velocity, technical risk realization, resource constraints. Provide:
1. Recommended option with confidence score (0-100%)
2. Regret risk (Low / Medium / High)
3. Critical time horizon for this decision
4. Top 3 risk factors that could flip the recommendation
5. Engineering-specific observations from the telemetry above
''';
  }
}

final decisionProvider = AsyncNotifierProvider<DecisionNotifier, DecisionResult?>(
  DecisionNotifier.new,
);
