import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

@immutable
class EngineerRosterEntry {
  final String handle;
  final String providerType;
  final String apiKey;
  final double alertThreshold;

  const EngineerRosterEntry({
    required this.handle,
    required this.providerType,
    required this.apiKey,
    required this.alertThreshold,
  });

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'providerType': providerType,
        'apiKey': apiKey,
        'alertThreshold': alertThreshold,
      };

  factory EngineerRosterEntry.fromJson(Map<String, dynamic> json) {
    return EngineerRosterEntry(
      handle: json['handle'] as String,
      providerType: json['providerType'] as String,
      apiKey: json['apiKey'] as String,
      alertThreshold: (json['alertThreshold'] as num).toDouble(),
    );
  }
}

const EngineerRosterEntry _defaultEntry = EngineerRosterEntry(
  handle: 'demo',
  providerType: 'demo',
  apiKey: '',
  alertThreshold: 200.0,
);

class EngineerRosterNotifier
    extends AsyncNotifier<List<EngineerRosterEntry>> {
  static const _configFileName = 'forge_config.json';
  static const _rosterKey = 'watch_engineer_roster';

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
  Future<List<EngineerRosterEntry>> build() async {
    final config = await _readConfigFile();
    final rosterJson = config[_rosterKey] as List<dynamic>?;
    if (rosterJson == null || rosterJson.isEmpty) {
      return const [_defaultEntry];
    }
    try {
      return rosterJson
          .map((e) =>
              EngineerRosterEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [_defaultEntry];
    }
  }

  Future<void> addEntry(EngineerRosterEntry entry) async {
    final current = state.valueOrNull ?? const [_defaultEntry];
    final updated = [...current, entry];
    await _persist(updated);
    state = AsyncData(updated);
  }

  Future<void> removeEntry(String handle) async {
    final current = state.valueOrNull ?? const [_defaultEntry];
    final updated = current.where((e) => e.handle != handle).toList();
    final toWrite = updated.isEmpty ? const [_defaultEntry] : updated;
    await _persist(toWrite);
    state = AsyncData(toWrite);
  }

  Future<void> _persist(List<EngineerRosterEntry> entries) async {
    final config = await _readConfigFile();
    config[_rosterKey] = entries.map((e) => e.toJson()).toList();
    await _writeConfigFile(config);
  }
}

final engineerRosterProvider =
    AsyncNotifierProvider<EngineerRosterNotifier, List<EngineerRosterEntry>>(
  EngineerRosterNotifier.new,
);