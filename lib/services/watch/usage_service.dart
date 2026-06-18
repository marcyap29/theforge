import '../../features/settings/engineer_roster_notifier.dart';
import 'demo_usage_provider.dart';
import 'providers/anthropic_usage_provider.dart';
import 'providers/gemini_usage_provider.dart';
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
        final usage = await provider.fetchUsage(
          engineerHandle: entry.handle,
          apiKey: entry.apiKey,
          lookbackDays: lookbackDays,
        );
        results.add(usage);
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
        return AnthropicUsageProvider(apiKey: entry.apiKey);
      case 'openai':
        return OpenAiUsageProvider(apiKey: entry.apiKey);
      case 'gemini':
        return const GeminiUsageProvider();
      case 'demo':
        return const DemoUsageProvider();
      default:
        return const OllamaUsageProvider();
    }
  }
}