import 'dart:convert';

import 'package:http/http.dart' as http;

import '../usage_provider.dart';

class AnthropicUsageProvider implements UsageProvider {
  const AnthropicUsageProvider();

  static const double _blendedCostPerToken = 0.000009; // $9/MTok blended

  @override
  String get providerName => 'anthropic';

  @override
  Future<EngineerUsage> fetchUsage({
    required String engineerHandle,
    required String apiKey,
    required int lookbackDays,
  }) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays));
    final startDate = _formatDate(start);
    final endDate = _formatDate(now);

    final response = await http.get(
      Uri.parse(
        'https://api.anthropic.com/v1/usage'
        '?start_date=$startDate&end_date=$endDate',
      ),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      return _errorUsage(engineerHandle);
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = data['data'] as List<dynamic>? ?? const [];
      final breakdown = <DailyUsage>[];
      for (final entry in entries) {
        final map = entry as Map<String, dynamic>;
        final agg = map['aggregation_key'] as Map<String, dynamic>?;
        final dateStr = agg?['date'] as String?;
        if (dateStr == null) continue;
        final date = DateTime.tryParse(dateStr);
        if (date == null) continue;
        final inputTokens = (map['input_tokens'] as num?)?.toInt() ?? 0;
        final outputTokens = (map['output_tokens'] as num?)?.toInt() ?? 0;
        final tokens = inputTokens + outputTokens;
        breakdown.add(
          DailyUsage(
            date: date,
            tokensUsed: tokens,
            costUSD: tokens * _blendedCostPerToken,
          ),
        );
      }
      final total = breakdown.fold<double>(0, (s, d) => s + d.costUSD);
      return EngineerUsage(
        engineerHandle: engineerHandle,
        providerName: providerName,
        dailyBreakdown: breakdown,
        totalCostUSD30d: total,
        sessionCount: breakdown.length,
      );
    } on FormatException {
      return _errorUsage(engineerHandle);
    } on TypeError {
      return _errorUsage(engineerHandle);
    }
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  EngineerUsage _errorUsage(String handle) => EngineerUsage(
        engineerHandle: handle,
        providerName: providerName,
        dailyBreakdown: const [],
        totalCostUSD30d: 0,
        sessionCount: 0,
        alertFlags: const ['api_error'],
      );
}