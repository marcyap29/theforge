import 'package:flutter/material.dart';

import '../widgets/status_chip.dart';
import 'checkin_service.dart';

/// Shows the check-in proposal for review. The user accepts/unchecks individual
/// changes and new features (mutating the proposal in place). Returns true to
/// apply the accepted items, false/null to discard.
Future<bool?> showCheckinReviewDialog(
  BuildContext context,
  CheckinProposal proposal,
) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _CheckinReviewDialog(proposal: proposal),
  );
}

class _CheckinReviewDialog extends StatefulWidget {
  const _CheckinReviewDialog({required this.proposal});
  final CheckinProposal proposal;

  @override
  State<_CheckinReviewDialog> createState() => _CheckinReviewDialogState();
}

class _CheckinReviewDialogState extends State<_CheckinReviewDialog> {
  CheckinProposal get p => widget.proposal;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Row(
        children: [
          const Icon(Icons.assignment_turned_in_outlined,
              color: Color(0xFFE8A04C), size: 20),
          const SizedBox(width: 8),
          const Text('Check-in', style: TextStyle(color: Color(0xFFE5E5E7))),
          const Spacer(),
          Text('${p.commitCount} commits',
              style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 12)),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 500,
        child: ListView(
          children: [
            _section('Summary'),
            Text(p.narrative,
                style: const TextStyle(color: Color(0xFFCFCFD2), fontSize: 13)),
            if (p.flags.isNotEmpty) ...[
              _section('Flags'),
              ...p.flags.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠  ',
                            style: TextStyle(color: Color(0xFFE8A04C))),
                        Expanded(
                          child: Text(f,
                              style: const TextStyle(
                                  color: Color(0xFFCFCFD2), fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
            ],
            if (p.changes.isNotEmpty) ...[
              _section('Proposed status changes'),
              ...p.changes.map(_changeRow),
            ],
            if (p.newFeatures.isNotEmpty) ...[
              _section('New features detected'),
              ...p.newFeatures.map(_newFeatureRow),
            ],
            if (p.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Nothing to apply — you\'re up to date.',
                    style: TextStyle(color: Color(0xFF8A8A8E), fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Dismiss'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apply & mark reviewed',
              style: TextStyle(color: Color(0xFFE8A04C))),
        ),
      ],
    );
  }

  Widget _section(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF8A8A8E),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _changeRow(FeatureStatusChange c) {
    return InkWell(
      onTap: () => setState(() => c.accepted = !c.accepted),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: c.accepted,
              activeColor: const Color(0xFFE8A04C),
              onChanged: (_) => setState(() => c.accepted = !c.accepted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.feature.title,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFE5E5E7))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusChip(
                          label: c.current.label,
                          color: c.current.color,
                          dense: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward,
                            size: 12, color: Color(0xFF8A8A8E)),
                      ),
                      StatusChip(
                          label: c.proposed.label,
                          color: c.proposed.color,
                          dense: true),
                    ],
                  ),
                  if (c.reason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(c.reason,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newFeatureRow(dynamic pf) {
    // pf is ProposedFeature (mutable selected + status).
    return InkWell(
      onTap: () => setState(() => pf.selected = !pf.selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: pf.selected,
              activeColor: const Color(0xFFE8A04C),
              onChanged: (_) => setState(() => pf.selected = !pf.selected),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pf.title,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFE5E5E7))),
                  if (pf.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(pf.description!,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(
                label: pf.status.label, color: pf.status.color, dense: true),
          ],
        ),
      ),
    );
  }
}
