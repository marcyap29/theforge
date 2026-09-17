import 'package:flutter/material.dart';

import '../../data/local_db/forge_database.dart';
import 'run_controller.dart';

/// Runs a project's app on a chosen device and shows it running — a live
/// screenshot mirror of the simulator/emulator plus the `flutter run` console,
/// with hot reload / restart / stop. This is the "see how it looks when tested"
/// window: macOS can't embed Apple's Simulator, so the mirror is a live frame
/// refreshed on each reload (native fidelity — camera/AR work in the real
/// simulator/emulator, unlike a web preview).
class RunPreviewScreen extends StatefulWidget {
  const RunPreviewScreen({
    super.key,
    required this.project,
    required this.repoPath,
  });

  final Project project;
  final String repoPath;

  @override
  State<RunPreviewScreen> createState() => _RunPreviewScreenState();
}

class _RunPreviewScreenState extends State<RunPreviewScreen> {
  late final RunController _c = RunController(widget.repoPath);
  List<RunDevice>? _devices;
  bool _loadingDevices = true;
  RunDevice? _selected;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() => _loadingDevices = true);
    final list = await RunController.listDevices();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _loadingDevices = false;
      _selected ??= list.isNotEmpty ? list.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Run & Preview — ${widget.project.name}')),
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Column(
          children: [
            _controlBar(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _previewPane()),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 4, child: _consolePane()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBar() {
    final running = _c.state == RunState.running;
    final canCapture =
        running && _c.device?.screenshotKind != ScreenshotKind.none;
    return Material(
      color: const Color(0xFF141416),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(child: _deviceDropdown()),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh device list',
              onPressed: _loadingDevices ? null : _loadDevices,
            ),
            const SizedBox(width: 8),
            if (_c.isBusy)
              _barButton(
                icon: Icons.stop_circle_outlined,
                label: switch (_c.state) {
                  RunState.booting => 'Booting…',
                  RunState.starting => 'Starting…',
                  RunState.stopping => 'Stopping…',
                  _ => 'Stop',
                },
                color: const Color(0xFFE57373),
                onTap: _c.state == RunState.running ? _c.stop : null,
              )
            else
              _barButton(
                icon: Icons.play_arrow_rounded,
                label: 'Run',
                color: const Color(0xFF81C784),
                onTap: _selected == null ? null : () => _c.start(_selected!),
              ),
            const SizedBox(width: 6),
            _barButton(
              icon: Icons.bolt,
              label: 'Hot reload',
              color: const Color(0xFF64B5F6),
              onTap: running ? _c.hotReload : null,
            ),
            const SizedBox(width: 6),
            _barButton(
              icon: Icons.restart_alt,
              label: 'Restart',
              color: const Color(0xFF64B5F6),
              onTap: running ? _c.hotRestart : null,
            ),
            const SizedBox(width: 6),
            _barButton(
              icon: Icons.photo_camera_outlined,
              label: 'Refresh view',
              color: const Color(0xFF9E9E9E),
              onTap: canCapture ? _c.capturePreview : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _deviceDropdown() {
    if (_loadingDevices) {
      return const Row(children: [
        SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 10),
        Text('Finding devices…',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      ]);
    }
    final devices = _devices ?? const <RunDevice>[];
    if (devices.isEmpty) {
      return const Text(
        'No devices found. Open a simulator/emulator (or install Xcode / '
        'Android Studio), then Refresh.',
        style: TextStyle(color: Color(0xFFE8A04C), fontSize: 12.5),
      );
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<RunDevice>(
        value: _selected,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E22),
        style: const TextStyle(color: Color(0xFFE5E5E7), fontSize: 13),
        items: [
          for (final d in devices)
            DropdownMenuItem(
              value: d,
              child: Text(d.menuLabel, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _c.isBusy ? null : (d) => setState(() => _selected = d),
      ),
    );
  }

  Widget _barButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, color: color)),
          ]),
        ),
      ),
    );
  }

  Widget _previewPane() {
    Widget child;
    if (_c.preview != null) {
      child = InteractiveViewer(
        maxScale: 4,
        child: Image.memory(_c.preview!, gaplessPlayback: true),
      );
    } else if (_c.state == RunState.booting) {
      child = const _Hint(
        icon: Icons.hourglass_top,
        text: 'Booting the simulator/emulator…',
      );
    } else if (_c.state == RunState.starting) {
      child = const _Hint(
        icon: Icons.hourglass_top,
        text: 'Building and launching… first run can take a minute.',
      );
    } else if (_c.previewNote != null) {
      child = _Hint(icon: Icons.open_in_new, text: _c.previewNote!);
    } else {
      child = const _Hint(
        icon: Icons.smartphone,
        text: 'Pick a device and press Run to see the app here.',
      );
    }
    return Container(
      color: const Color(0xFF0B0B0D),
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _consolePane() {
    return Container(
      color: const Color(0xF0101012),
      child: _c.lines.isEmpty
          ? const _Hint(icon: Icons.terminal, text: 'Console output appears here.')
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _c.lines.length,
              itemBuilder: (context, i) {
                final line = _c.lines[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: SelectableText(
                    line.text,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11.5,
                      height: 1.35,
                      color: line.isError
                          ? const Color(0xFFE57373)
                          : const Color(0xFFCFCFD2),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: const Color(0xFF4B5563)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
