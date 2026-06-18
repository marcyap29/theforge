import '../usage_provider.dart';

class GeminiUsageProvider implements UsageProvider {
  const GeminiUsageProvider();

  @override
  String get providerName => 'gemini';

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
      alertFlags: const ['api_unsupported'],
    );
  }
}