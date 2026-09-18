import 'package:flutter/material.dart';

import '../models/tracker_enums.dart';
import '../scan/feature_scan.dart';

/// Reviews an epic decomposition. Returns the sub-features the user kept (to be
/// created, nested under the epic), or null to cancel.
Future<List<ArchitectSubFeature>?> showArchitectReviewSheet(
    BuildContext context, ArchitectPlan plan) {
  return showDialog<List<ArchitectSubFeature>>(
    context: context,
    builder: (ctx) => _ArchitectDialog(plan: plan),
  );
}

class _ArchitectDialog extends StatefulWidget {
  const _ArchitectDialog({required this.plan});
  final ArchitectPlan plan;

  @override
  State<_ArchitectDialog> createState() => _ArchitectDialogState();
}

class _ArchitectDialogState extends State<_ArchitectDialog> {
  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final selected = plan.subFeatures.where((s) => s.selected).length;
    return AlertDialog(
      backgroundColor: const Color(0xFF141416),
      title: Row(children: [
        Icon(plan.isEpic ? Icons.account_tree_outlined : Icons.check_circle_outline,
            size: 20,
            color: plan.isEpic
                ? const Color(0xFFBA68C8)
                : const Color(0xFF81C784)),
        const SizedBox(width: 8),
        Text(plan.isEpic ? 'This is an epic — break it down' : 'Build plan'),
      ]),
      content: SizedBox(
        width: 600,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (plan.rationale.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(plan.rationale,
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF9CA3AF))),
              ),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Kept sub-features become tracked items nested under this feature '
                '(which becomes an epic). "Manual" items are human/ML/data work — '
                'the AI won\'t try to code-generate them.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
              ),
            ),
            for (final s in plan.subFeatures) _row(s),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: selected == 0
              ? null
              : () => Navigator.of(context)
                  .pop(plan.subFeatures.where((s) => s.selected).toList()),
          child: Text('Add $selected to board'),
        ),
      ],
    );
  }

  Widget _row(ArchitectSubFeature s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              value: s.selected,
              onChanged: (v) => setState(() => s.selected = v ?? false),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(s.title,
                        style: const TextStyle(
                            fontSize: 13.5, color: Color(0xFFE5E5E7))),
                  ),
                  const SizedBox(width: 8),
                  _kindTag(s.buildKind),
                ]),
                if ((s.description ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(s.description!,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFFB0B0B4))),
                  ),
                if (s.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(s.reason,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindTag(BuildKind kind) {
    if (kind == BuildKind.standard) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        kind == BuildKind.manual ? 'manual · human/ML' : kind.label,
        style: TextStyle(fontSize: 10, color: kind.color),
      ),
    );
  }
}
