import 'dart:math';

import 'usage_provider.dart';

class DemoUsageProvider implements UsageProvider {
  const DemoUsageProvider();

  @override
  String get providerName => 'demo';

  static const Map<String, double> _baselines = {
    'runaway': 135.0, // 9x
    'ghost': 1.50, // 0.1x
    'highperformer': 22.50, // 1.5x
    'self': 15.0, // 1.0x
  };

  @override
  Future<EngineerUsage> fetchUsage({
    required String engineerHandle,
    required String apiKey,
    required int lookbackDays,
  }) async {
    final baseline = _baselines[engineerHandle] ?? 15.0;
    final rng = Random(42);
    final now = DateTime.now();
    final days = lookbackDays.clamp(1, 30);

    final breakdown = <DailyUsage>[];
    for (var i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final variance = 1.0 + (rng.nextDouble() * 0.4 - 0.2); // ±20%
      final dailyCost = baseline * variance;
      final tokensUsed = (dailyCost / 0.000009).round();
      breakdown.add(
        DailyUsage(
          date: date,
          tokensUsed: tokensUsed,
          costUSD: dailyCost,
        ),
      );
    }

    final total = breakdown.fold<double>(0, (s, d) => s + d.costUSD);
    final anyRunawayDay = breakdown.any((d) => d.costUSD > 100);
    final flags = <String>[];
    if (total > 200) flags.add('spend_threshold');
    if (anyRunawayDay) flags.add('runaway_session');

    return EngineerUsage(
      engineerHandle: engineerHandle,
      providerName: providerName,
      dailyBreakdown: breakdown,
      totalCostUSD30d: total,
      sessionCount: breakdown.length,
      alertFlags: flags,
    );
  }
}