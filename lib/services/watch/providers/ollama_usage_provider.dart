import '../usage_provider.dart';

class OllamaUsageProvider implements UsageProvider {
  const OllamaUsageProvider();

  @override
  String get providerName => 'ollama';

  @override
  Future<EngineerUsage> fetchUsage({
    required String engineerHandle,
    required String apiKey,
    required int lookbackDays,
  }) async {
    return EngineerUsage(
      engineerHandle: engineerHandle,
      providerName: providerName,
      dailyBreakdown: const [],
      totalCostUSD30d: 0,
      sessionCount: 0,
      alertFlags: const ['local_model_unsupported'],
    );
  }
}