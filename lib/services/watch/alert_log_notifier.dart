import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'alert_engine.dart';

class AlertLogNotifier extends AsyncNotifier<List<AlertEntry>> {
  static const _configFileName = 'forge_config.json';
  static const _logKey = 'watch_alert_log';

  static Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _configFileName));
  }

  static Future<Map<String, dynamic>> _readConfigFile() async {
    try {
      final file = await _configFile();
      if (!file.existsSync()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeConfigFile(Map<String, dynamic> data) async {
    try {
      final file = await _configFile();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
    } catch (_) {}
  }

  @override
  Future<List<AlertEntry>> build() async {
    final config = await _readConfigFile();
    final logJson = config[_logKey] as List<dynamic>?;
    if (logJson == null || logJson.isEmpty) return const [];
    try {
      return logJson
          .map((e) => AlertEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> appendAlerts(List<AlertEntry> newEntries) async {
    if (newEntries.isEmpty) return;
    final current = state.valueOrNull ?? const [];
    final updated = [...newEntries, ...current];
    await _persist(updated);
    state = AsyncData(updated);
  }

  Future<void> dismissAlert(String id) async {
    final current = state.valueOrNull ?? const [];
    final updated = current
        .map((e) => e.id == id ? e.copyWithDismissed() : e)
        .toList();
    await _persist(updated);
    state = AsyncData(updated);
  }

  Future<void> clearDismissed() async {
    final current = state.valueOrNull ?? const [];
    final updated = current.where((e) => !e.dismissed).toList();
    await _persist(updated);
    state = AsyncData(updated);
  }

  Future<void> _persist(List<AlertEntry> entries) async {
    final config = await _readConfigFile();
    config[_logKey] = entries.map((e) => e.toJson()).toList();
    await _writeConfigFile(config);
  }
}

final alertLogProvider =
    AsyncNotifierProvider<AlertLogNotifier, List<AlertEntry>>(
  AlertLogNotifier.new,
);