import '../../features/settings/engineer_roster_notifier.dart';
import 'demo_usage_provider.dart';
import 'providers/anthropic_usage_provider.dart';
import 'providers/ollama_usage_provider.dart';
import 'providers/openai_usage_provider.dart';
import 'usage_provider.dart';

class UsageService {
  const UsageService({required this.roster});

  final List<EngineerRosterEntry> roster;

  Future<List<EngineerUsage>> fetchAllUsage({
    int lookbackDays = 30,
  }) async {
    final results = <EngineerUsage>[];
    for (final entry in roster) {
      final provider = _resolveProvider(entry);
      try {
        final raw = await provider.fetchUsage(
          engineerHandle: entry.handle,
          apiKey: entry.apiKey,
          lookbackDays: lookbackDays,
        );
        // Evaluate alert flags here using the per-engineer threshold from the
        // roster — providers return raw data; the service owns flag logic.
        final flags = List<String>.from(raw.alertFlags);
        if (raw.totalCostUSD30d > entry.alertThreshold &&
            !flags.contains('spend_threshold')) {
          flags.add('spend_threshold');
        }
        if (raw.dailyBreakdown.any((d) => d.costUSD > 100) &&
            !flags.contains('runaway_session')) {
          flags.add('runaway_session');
        }
        results.add(EngineerUsage(
          engineerHandle: raw.engineerHandle,
          providerName: raw.providerName,
          dailyBreakdown: raw.dailyBreakdown,
          totalCostUSD30d: raw.totalCostUSD30d,
          sessionCount: raw.sessionCount,
          alertFlags: flags,
        ));
      } catch (_) {
        results.add(
          EngineerUsage(
            engineerHandle: entry.handle,
            providerName: entry.providerType,
            dailyBreakdown: const [],
            totalCostUSD30d: 0,
            sessionCount: 0,
            alertFlags: const ['fetch_error'],
          ),
        );
      }
    }
    return results;
  }

  UsageProvider _resolveProvider(EngineerRosterEntry entry) {
    switch (entry.providerType) {
      case 'anthropic':
        return const AnthropicUsageProvider();
      case 'openai':
        return const OpenAiUsageProvider();
      case 'demo':
        return const DemoUsageProvider();
      default:
        return const OllamaUsageProvider();
    }
  }
}