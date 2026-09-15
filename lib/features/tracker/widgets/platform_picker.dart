import 'package:flutter/material.dart';

/// One selectable target platform for a new Flutter app.
class _Platform {
  const _Platform(this.id, this.label, this.icon);
  final String id; // flutter create --platforms value
  final String label;
  final IconData icon;
}

const _platforms = <_Platform>[
  _Platform('ios', 'iOS', Icons.phone_iphone),
  _Platform('android', 'Android', Icons.android),
  _Platform('macos', 'macOS', Icons.laptop_mac),
  _Platform('windows', 'Windows', Icons.desktop_windows),
  _Platform('linux', 'Linux', Icons.dvr_outlined),
  _Platform('web', 'Web', Icons.public),
];

/// Asks which platforms a new app targets. Returns the selected flutter platform
/// ids (e.g. `['ios','android']`), or null if cancelled. The folder is then
/// scaffolded for exactly those platforms, so the app is runnable from the
/// start — no separate "Make runnable" step. Mobile is pre-selected.
Future<List<String>?> pickPlatforms(BuildContext context,
    {String? projectName}) {
  return showDialog<List<String>>(
    context: context,
    builder: (ctx) => _PlatformPickerDialog(projectName: projectName),
  );
}

class _PlatformPickerDialog extends StatefulWidget {
  const _PlatformPickerDialog({this.projectName});
  final String? projectName;

  @override
  State<_PlatformPickerDialog> createState() => _PlatformPickerDialogState();
}

class _PlatformPickerDialogState extends State<_PlatformPickerDialog> {
  // Sensible default: mobile.
  final Set<String> _selected = {'ios', 'android'};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141416),
      title: Text(widget.projectName == null
          ? 'Which platforms is this app for?'
          : 'Platforms for ${widget.projectName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'The Forge will set the app up to run on these — you can add more '
            'later with flutter.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 8),
          for (final pl in _platforms)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selected.contains(pl.id),
              onChanged: (v) => setState(() {
                (v ?? false) ? _selected.add(pl.id) : _selected.remove(pl.id);
              }),
              secondary: Icon(pl.icon, size: 20),
              title: Text(pl.label, style: const TextStyle(fontSize: 14)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: const Text('Create app'),
        ),
      ],
    );
  }
}
