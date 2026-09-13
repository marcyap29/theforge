import 'package:flutter/material.dart';

import '../scan/feature_dedup.dart';

/// Reviews proposed duplicate groups before deleting. Each group is opt-in
/// (checked by default); returns the set of feature IDs to delete, or null if
/// cancelled.
Future<Set<String>?> showDedupReviewSheet(
  BuildContext context,
  List<DuplicateGroup> groups,
) {
  return showDialog<Set<String>>(
    context: context,
    builder: (ctx) => _DedupReviewDialog(groups: groups),
  );
}

class _DedupReviewDialog extends StatefulWidget {
  const _DedupReviewDialog({required this.groups});
  final List<DuplicateGroup> groups;

  @override
  State<_DedupReviewDialog> createState() => _DedupReviewDialogState();
}

class _DedupReviewDialogState extends State<_DedupReviewDialog> {
  late final List<bool> _apply =
      List<bool>.filled(widget.groups.length, true);

  int get _toDelete {
    var n = 0;
    for (var i = 0; i < widget.groups.length; i++) {
      if (_apply[i]) n += widget.groups[i].duplicates.length;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141416),
      title: Text('Remove duplicates · ${widget.groups.length} group(s)'),
      content: SizedBox(
        width: 560,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.groups.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 16, color: Color(0xFF2C2C2E)),
          itemBuilder: (_, i) {
            final g = widget.groups[i];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _apply[i],
                  onChanged: (v) => setState(() => _apply[i] = v ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.check_circle,
                            size: 14, color: Color(0xFF81C784)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Keep: ${g.keeper.title}  ·  ${g.keeper.status}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFE5E5E7),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      for (final d in g.duplicates)
                        Padding(
                          padding: const EdgeInsets.only(left: 20, top: 2),
                          child: Row(children: [
                            const Icon(Icons.remove_circle_outline,
                                size: 13, color: Color(0xFFE57373)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('${d.title}  ·  ${d.status}',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF9CA3AF),
                                      decoration: TextDecoration.lineThrough)),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _toDelete == 0
              ? null
              : () {
                  final ids = <String>{};
                  for (var i = 0; i < widget.groups.length; i++) {
                    if (_apply[i]) {
                      ids.addAll(widget.groups[i].duplicates.map((d) => d.id));
                    }
                  }
                  Navigator.of(context).pop(ids);
                },
          icon: const Icon(Icons.delete_sweep_outlined, size: 16),
          label: Text('Remove $_toDelete'),
        ),
      ],
    );
  }
}
