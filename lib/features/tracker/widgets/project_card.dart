import 'package:flutter/material.dart';

import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';
import 'feature_status_bar.dart';
import 'status_chip.dart';

/// A single project tile on the portfolio dashboard: name, status, a
/// feature-distribution bar, roll-up counts, and a "review due" nudge.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onOpenDetail,
  });

  final PortfolioEntry entry;

  /// Open the feature board / tracker.
  final VoidCallback onOpen;

  /// Open the full Forge project detail (interview/spec pipeline).
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final counts = entry.counts;
    final status = entry.status;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE5E5E7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(label: status.label, color: status.color, dense: true),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _subtitle(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A8A8E)),
              ),
              const SizedBox(height: 12),
              FeatureStatusBar(counts: counts),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _rollup(counts),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontFamily: 'Menlo',
                      ),
                    ),
                  ),
                  if (entry.reviewDue)
                    const StatusChip(
                      label: 'Review due',
                      color: Color(0xFFE8A04C),
                      icon: Icons.notifications_active_outlined,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    _reviewedLabel(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Open Forge project (interview / spec)',
                    icon: const Icon(Icons.build_outlined,
                        size: 16, color: Color(0xFF8A8A8E)),
                    onPressed: onOpenDetail,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final total = entry.totalCount;
    if (total == 0) return 'No features tracked yet';
    return '$total feature${total == 1 ? '' : 's'} tracked';
  }

  String _rollup(Map<FeatureStatus, int> counts) {
    final parts = <String>[];
    for (final s in FeatureStatus.board) {
      final c = counts[s] ?? 0;
      if (c > 0) parts.add('$c ${s.label.toLowerCase()}');
    }
    if (parts.isEmpty) return '—';
    return parts.join(' · ');
  }

  String _reviewedLabel() {
    final last = entry.tracking?.lastReviewedAt;
    if (last == null) return 'Never reviewed';
    final dt = DateTime.fromMillisecondsSinceEpoch(last);
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return 'Reviewed $y-$m-$d';
  }
}
