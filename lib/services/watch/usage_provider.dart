import 'package:flutter/foundation.dart';

@immutable
class DailyUsage {
  final DateTime date;
  final int tokensUsed;
  final double costUSD;

  const DailyUsage({
    required this.date,
    required this.tokensUsed,
    required this.costUSD,
  });
}

@immutable
class EngineerUsage {
  final String engineerHandle;
  final String providerName;
  final List<DailyUsage> dailyBreakdown;
  final double totalCostUSD30d;
  final int sessionCount;
  final List<String> alertFlags;

  const EngineerUsage({
    required this.engineerHandle,
    required this.providerName,
    required this.dailyBreakdown,
    required this.totalCostUSD30d,
    required this.sessionCount,
    this.alertFlags = const [],
  });
}

abstract class UsageProvider {
  String get providerName;

  Future<EngineerUsage> fetchUsage({
    required String engineerHandle,
    required String apiKey,
    required int lookbackDays,
  });
}