import 'package:flutter/material.dart';

/// A compact line-level diff between two strings, rendered like a unified diff
/// (green additions, red deletions, grey context). Uses an LCS so unchanged
/// lines stay aligned. Output is capped to keep the approval card readable.
class DiffView extends StatelessWidget {
  const DiffView({
    super.key,
    required this.oldText,
    required this.newText,
    this.maxLines = 400,
  });

  final String oldText;
  final String newText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final rows = _diff(
      oldText.isEmpty ? const [] : oldText.split('\n'),
      newText.split('\n'),
    );
    final shown = rows.length > maxLines ? rows.sublist(0, maxLines) : rows;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in shown)
            Text(
              '${r.marker} ${r.text}',
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 11.5,
                height: 1.35,
                color: switch (r.marker) {
                  '+' => const Color(0xFF81C784),
                  '-' => const Color(0xFFE57373),
                  _ => const Color(0xFF8A8A8E),
                },
              ),
            ),
          if (rows.length > maxLines)
            Text('… ${rows.length - maxLines} more lines',
                style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  static List<_DiffRow> _diff(List<String> a, List<String> b) {
    final n = a.length, m = b.length;
    // LCS length table.
    final lcs =
        List.generate(n + 1, (_) => List<int>.filled(m + 1, 0), growable: false);
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        lcs[i][j] = a[i] == b[j]
            ? lcs[i + 1][j + 1] + 1
            : (lcs[i + 1][j] >= lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
      }
    }
    final rows = <_DiffRow>[];
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        rows.add(_DiffRow(' ', a[i]));
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        rows.add(_DiffRow('-', a[i]));
        i++;
      } else {
        rows.add(_DiffRow('+', b[j]));
        j++;
      }
    }
    while (i < n) {
      rows.add(_DiffRow('-', a[i++]));
    }
    while (j < m) {
      rows.add(_DiffRow('+', b[j++]));
    }
    return rows;
  }
}

class _DiffRow {
  _DiffRow(this.marker, this.text);
  final String marker;
  final String text;
}
