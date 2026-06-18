import 'package:flutter/foundation.dart';

import 'failure_signal_engine.dart';

@immutable
class AlertEntry {
  final String id;
  final String engineerHandle;
  final SignalType signalType;
  final SignalSeverity severity;
  final String detail;
  final DateTime createdAt;
  final bool dismissed;

  const AlertEntry({
    required this.id,
    required this.engineerHandle,
    required this.signalType,
    required this.severity,
    required this.detail,
    required this.createdAt,
    this.dismissed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'engineerHandle': engineerHandle,
        'signalType': signalType.name,
        'severity': severity.name,
        'detail': detail,
        'createdAt': createdAt.toIso8601String(),
        'dismissed': dismissed,
      };

  factory AlertEntry.fromJson(Map<String, dynamic> json) => AlertEntry(
        id: json['id'] as String,
        engineerHandle: json['engineerHandle'] as String,
        signalType: SignalType.values.byName(json['signalType'] as String),
        severity: SignalSeverity.values.byName(json['severity'] as String),
        detail: json['detail'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dismissed: json['dismissed'] as bool? ?? false,
      );

  AlertEntry copyWithDismissed() => AlertEntry(
        id: id,
        engineerHandle: engineerHandle,
        signalType: signalType,
        severity: severity,
        detail: detail,
        createdAt: createdAt,
        dismissed: true,
      );
}

class AlertEngine {
  const AlertEngine();

  List<AlertEntry> evaluate({
    required List<FailureSignal> signals,
    required List<AlertEntry> existingLog,
  }) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    final recent = existingLog.where((e) => e.createdAt.isAfter(cutoff)).toList();

    final out = <AlertEntry>[];
    for (final signal in signals) {
      final isDuplicate = recent.any(
        (e) =>
            e.engineerHandle == signal.engineerHandle &&
            e.signalType == signal.type,
      );
      if (isDuplicate) continue;
      out.add(AlertEntry(
        id:
            '${signal.engineerHandle}_${signal.type.name}_${now.millisecondsSinceEpoch}',
        engineerHandle: signal.engineerHandle,
        signalType: signal.type,
        severity: signal.severity,
        detail: signal.detail,
        createdAt: now,
      ));
    }
    return out;
  }
}