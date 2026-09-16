import 'package:flutter/material.dart';

import '../scan/feature_scan.dart';

/// Shows the proposed phased build order for review. Returns true to apply it
/// (write each phase's version + a running priority to the features), false/null
/// to cancel.
Future<bool?> showRoadmapReviewSheet(
    BuildContext context, List<RoadmapPhase> phases) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _RoadmapDialog(phases: phases),
  );
}

class _RoadmapDialog extends StatelessWidget {
  const _RoadmapDialog({required this.phases});
  final List<RoadmapPhase> phases;

  @override
  Widget build(BuildContext context) {
    final total = phases.fold<int>(0, (s, ph) => s + ph.entries.length);
    return AlertDialog(
      backgroundColor: const Color(0xFF141416),
      title: const Text('Proposed build order'),
      content: SizedBox(
        width: 580,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Applying sets each feature\'s target version (phase) and orders '
                'the board by build sequence.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
            for (var i = 0; i < phases.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Row(
                  children: [
                    Text(
                      'Phase ${i + 1} — ${phases[i].name}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE8A04C)),
                    ),
                    if (phases[i].version.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(phases[i].version,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9CA3AF))),
                      ),
                    ],
                  ],
                ),
              ),
              for (final e in phases[i].entries)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ${e.title}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFE5E5E7))),
                      if (e.reason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 1),
                          child: Text(e.reason,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Color(0xFF9CA3AF))),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: total == 0 ? null : () => Navigator.of(context).pop(true),
          child: const Text('Apply to board'),
        ),
      ],
    );
  }
}
