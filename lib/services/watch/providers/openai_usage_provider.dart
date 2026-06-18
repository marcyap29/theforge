import 'dart:convert';

import 'package:http/http.dart' as http;

import '../usage_provider.dart';

class OpenAiUsageProvider implements UsageProvider {
  OpenAiUsageProvider({required this.apiKey});
  final String apiKey;

  static const double _blendedCostPerToken = 0.000005; // $5/MTok blended

  @override
  String get providerName => 'openai';

  @override
  Future<EngineerUsage> fetchUsage({
    required String engineerHandle,
    required String apiKey,
    required int lookbackDays,
  }) async {
    final now = DateTime.now();
    final dates = List.generate(
      lookbackDays,
      (i) => now.subtract(Duration(days: i)),
    );

    try {
      final responses = await Future.wait(
        dates.map((d) => _fetchDay(d, apiKey)),
      );
      final breakdown = responses.whereType<DailyUsage>().toList();
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

  Future<DailyUsage?> _fetchDay(DateTime day, String apiKey) async {
    final dateStr = _formatDate(day);
    final response = await http.get(
      Uri.parse('https://api.openai.com/v1/usage?date=$dateStr'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'content-type': 'application/json',
      },
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = data['data'] as List<dynamic>? ?? const [];
    int contextTokens = 0;
    int generatedTokens = 0;
    for (final entry in entries) {
      final map = entry as Map<String, dynamic>;
      contextTokens += (map['n_context_tokens_total'] as num?)?.toInt() ?? 0;
      generatedTokens +=
          (map['n_generated_tokens_total'] as num?)?.toInt() ?? 0;
    }
    final tokens = contextTokens + generatedTokens;
    if (tokens == 0) return null;
    return DailyUsage(
      date: DateTime(day.year, day.month, day.day),
      tokensUsed: tokens,
      costUSD: tokens * _blendedCostPerToken,
    );
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