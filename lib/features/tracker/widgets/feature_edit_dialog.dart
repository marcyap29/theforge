import 'package:flutter/material.dart';

import '../../../data/local_db/forge_database.dart';
import '../models/tracker_enums.dart';

/// Result returned by [showFeatureEditDialog].
class FeatureEditResult {
  FeatureEditResult({
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.targetVersion,
  });

  final String title;
  final String? description;
  final FeatureStatus status;
  final int? priority;
  final String? targetVersion;
}

/// Shows a create/edit dialog for a feature. Pass [existing] to edit.
Future<FeatureEditResult?> showFeatureEditDialog(
  BuildContext context, {
  Feature? existing,
}) {
  return showDialog<FeatureEditResult>(
    context: context,
    builder: (_) => _FeatureEditDialog(existing: existing),
  );
}

class _FeatureEditDialog extends StatefulWidget {
  const _FeatureEditDialog({this.existing});
  final Feature? existing;

  @override
  State<_FeatureEditDialog> createState() => _FeatureEditDialogState();
}

class _FeatureEditDialogState extends State<_FeatureEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _version;
  late final TextEditingController _priority;
  late FeatureStatus _status;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _version = TextEditingController(text: e?.targetVersion ?? '');
    _priority =
        TextEditingController(text: e?.priority?.toString() ?? '');
    _status = e != null ? FeatureStatus.fromWire(e.status) : FeatureStatus.planned;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _version.dispose();
    _priority.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      FeatureEditResult(
        title: title,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        status: _status,
        priority: int.tryParse(_priority.text.trim()),
        targetVersion:
            _version.text.trim().isEmpty ? null : _version.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      title: Text(
        widget.existing == null ? 'Add Feature' : 'Edit Feature',
        style: const TextStyle(color: Color(0xFFE5E5E7), fontSize: 16),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_title, 'Title', autofocus: true, onSubmit: _submit),
              const SizedBox(height: 12),
              _field(_desc, 'Description (optional)', maxLines: 3),
              const SizedBox(height: 12),
              const Text('Status',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: FeatureStatus.board.map((s) {
                  final selected = s == _status;
                  return ChoiceChip(
                    label: Text(s.label),
                    selected: selected,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: selected ? Colors.black : s.color,
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: s.color,
                    backgroundColor: s.color.withValues(alpha: 0.15),
                    side: BorderSide(color: s.color.withValues(alpha: 0.5)),
                    onSelected: (_) => setState(() => _status = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(_priority, 'Priority (number)',
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_version, 'Target version'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.existing == null ? 'Add' : 'Save',
            style: const TextStyle(color: Color(0xFFE8A04C)),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    bool autofocus = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    VoidCallback? onSubmit,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Menlo',
        fontSize: 13,
        color: Color(0xFFE5E5E7),
      ),
      onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFF0F0F10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE8A04C)),
        ),
      ),
    );
  }
}
