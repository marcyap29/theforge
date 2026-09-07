import 'package:flutter/material.dart';

import '../models/tracker_enums.dart';

/// A horizontal segmented bar showing the distribution of a project's features
/// across statuses. Each segment is sized proportional to its count.
class FeatureStatusBar extends StatelessWidget {
  const FeatureStatusBar({
    super.key,
    required this.counts,
    this.height = 8,
  });

  final Map<FeatureStatus, int> counts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }

    final segments = <Widget>[];
    for (final status in FeatureStatus.board) {
      final c = counts[status] ?? 0;
      if (c == 0) continue;
      segments.add(
        Expanded(
          flex: c,
          child: Container(color: status.color),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(children: segments),
      ),
    );
  }
}
