import 'package:flutter/material.dart';

import '../models/tracker_enums.dart';
import '../scan/feature_scan.dart';

/// Shows the reviewable list of scanned features. Returns the accepted subset
/// (with any status edits) or null if cancelled.
Future<List<ProposedFeature>?> showScanReviewSheet(
  BuildContext context,
  List<ProposedFeature> proposals,
) {
  return showDialog<List<ProposedFeature>>(
    context: context,
    builder: (_) => _ScanReviewDialog(proposals: proposals),
  );
}

class _ScanReviewDialog extends StatefulWidget {
  const _ScanReviewDialog({required this.proposals});
  final List<ProposedFeature> proposals;

  @override
  State<_ScanReviewDialog> createState() => _ScanReviewDialogState();
}

class _ScanReviewDialogState extends State<_ScanReviewDialog> {
  late final List<ProposedFeature> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.proposals;
  }

  int get _selectedCount => _items.where((f) => f.selected).length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Row(
        children: [
          const Expanded(
            child: Text('Review scanned features',
                style: TextStyle(color: Color(0xFFE5E5E7), fontSize: 16)),
          ),
          Text('$_selectedCount selected',
              style: const TextStyle(color: Color(0xFF8A8A8E), fontSize: 12)),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Uncheck any you don\'t want. Tap a status to change it. '
                'Importing replaces the current tracked feature list.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                itemBuilder: (context, i) {
                  final f = _items[i];
                  return _ProposalRow(
                    feature: f,
                    onToggle: () => setState(() => f.selected = !f.selected),
                    onCycleStatus: () => setState(() {
                      const order = FeatureStatus.board;
                      final idx = order.indexOf(f.status);
                      f.status = order[(idx + 1) % order.length];
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedCount == 0
              ? null
              : () => Navigator.pop(
                  context, _items.where((f) => f.selected).toList()),
          child: Text('Import $_selectedCount',
              style: TextStyle(
                  color: _selectedCount == 0
                      ? const Color(0xFF6B7280)
                      : const Color(0xFFE8A04C))),
        ),
      ],
    );
  }
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({
    required this.feature,
    required this.onToggle,
    required this.onCycleStatus,
  });

  final ProposedFeature feature;
  final VoidCallback onToggle;
  final VoidCallback onCycleStatus;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: feature.selected,
              activeColor: const Color(0xFFE8A04C),
              onChanged: (_) => onToggle(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feature.title,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFE5E5E7))),
                  if (feature.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(feature.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9CA3AF))),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onCycleStatus,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: feature.status.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: feature.status.color.withValues(alpha: 0.5)),
                ),
                child: Text(feature.status.label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Menlo',
                        color: feature.status.color)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
