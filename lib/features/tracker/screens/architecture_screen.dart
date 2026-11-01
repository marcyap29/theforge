import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../providers/architecture_providers.dart';
import '../providers/tracker_providers.dart';

class ArchitectureScreen extends ConsumerStatefulWidget {
  const ArchitectureScreen({
    super.key,
    required this.project,
    this.repoPath,
  });

  final Project project;
  final String? repoPath;

  @override
  ConsumerState<ArchitectureScreen> createState() => _ArchitectureScreenState();
}

class _ArchitectureScreenState extends ConsumerState<ArchitectureScreen> {
  int _phase = 0; // 0 = idle/loading cache, 1-3 = generating, 4 = done, -1 = error
  String _label = 'Loading…';
  String? _diagram;
  Map<String, List<String>> _componentMap = {};
  String? _error;
  bool _showComponentMap = false;
  bool _isWebViewReady = false;

  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _onWebViewReady(),
      ));
    _loadOrGenerate();
  }

  Future<void> _loadOrGenerate() async {
    setState(() { _phase = 0; _label = 'Loading cached diagram…'; });
    final cached =
        await ProjectFileRepository.readArchitectureDiagram(widget.project.path);
    if (cached != null && cached.isNotEmpty) {
      final mapData = await ProjectFileRepository.readComponentMap(
          widget.project.path);
      final componentMap = _parseComponentMap(mapData);
      if (mounted) {
        setState(() {
          _diagram = cached;
          _componentMap = componentMap;
          _phase = 4;
        });
        _loadWebView(cached);
      }
    } else {
      await _generate();
    }
  }

  Future<void> _generate() async {
    setState(() {
      _phase = 0;
      _label = 'Starting…';
      _error = null;
      _isWebViewReady = false;
    });

    final featuresAsync =
        ref.read(featureListProvider(widget.project.id));
    final features = featuresAsync.valueOrNull ?? [];

    final analyst = ref.read(architectureAnalystProvider);
    try {
      final result = await analyst.analyze(
        features: features,
        projectPath: widget.project.path,
        repoPath: widget.repoPath,
        onProgress: (phase, label) {
          if (mounted) setState(() { _phase = phase; _label = label; });
        },
      );

      // Save to disk
      await ProjectFileRepository.writeArchitectureDiagram(
          widget.project.path, result.diagram);
      await ProjectFileRepository.writeComponentMap(widget.project.path, {
        'components': result.componentMap
            .map((k, v) => MapEntry(k, v)),
      });

      if (mounted) {
        setState(() {
          _phase = 4;
          _diagram = result.diagram;
          _componentMap = result.componentMap;
        });
        _loadWebView(result.diagram);
      }
    } catch (e) {
      if (mounted) setState(() { _phase = -1; _error = e.toString(); });
    }
  }

  void _loadWebView(String diagramSource) {
    setState(() => _isWebViewReady = false);
    _webController.loadFlutterAsset('assets/mermaid_viewer.html').then((_) {
      // renderMermaid is called in _onWebViewReady after page loads
    });
    // Store for use in _onWebViewReady
    _pendingDiagram = diagramSource;
  }

  String? _pendingDiagram;

  Future<void> _onWebViewReady() async {
    if (!mounted) return;
    setState(() => _isWebViewReady = true);
    final src = _pendingDiagram ?? _diagram;
    if (src != null) {
      await _renderDiagram(src);
    }
  }

  Future<void> _renderDiagram(String source) async {
    // Escape backticks and backslashes for JS template literal injection
    final escaped =
        source.replaceAll(r'\', r'\\').replaceAll('`', r'\`').replaceAll('\$', r'\$');
    await _webController.runJavaScript(
        'if (window.renderMermaid) window.renderMermaid(`$escaped`);');
  }

  Future<void> _copySource() async {
    if (_diagram == null) return;
    await Clipboard.setData(ClipboardData(text: _diagram!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Diagram source copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Map<String, List<String>> _parseComponentMap(Map<String, dynamic>? raw) {
    if (raw == null) return {};
    final components = raw['components'] as Map<String, dynamic>?;
    if (components == null) return {};
    return components.map((k, v) => MapEntry(
          k,
          (v as List).map((e) => e.toString()).toList(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(widget.project.name,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            const Text('· Architecture',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8E))),
          ],
        ),
        actions: [
          if (_phase == 4 && _diagram != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 20),
              tooltip: 'Copy diagram source (.mmd)',
              onPressed: _copySource,
            ),
            IconButton(
              icon: Icon(
                _showComponentMap
                    ? Icons.account_tree
                    : Icons.account_tree_outlined,
                size: 20,
              ),
              tooltip: 'Component map',
              onPressed: () =>
                  setState(() => _showComponentMap = !_showComponentMap),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Regenerate',
            onPressed: (_phase >= 1 && _phase <= 3) ? null : _generate,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_phase == -1) {
      return _ErrorView(error: _error ?? 'Unknown error', onRetry: _generate);
    }

    if (_phase > 0 && _phase < 4) {
      return _GeneratingView(phase: _phase, label: _label);
    }

    return Row(
      children: [
        // Main diagram pane
        Expanded(
          child: _phase == 0
              ? const Center(child: CircularProgressIndicator())
              : _diagram != null
                  ? Stack(
                      children: [
                        WebViewWidget(controller: _webController),
                        if (!_isWebViewReady)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : const Center(
                      child: Text('No diagram yet — tap Regenerate.',
                          style: TextStyle(color: Color(0xFF9CA3AF)))),
        ),
        // Component map side panel
        if (_showComponentMap && _componentMap.isNotEmpty)
          _ComponentMapPanel(
            componentMap: _componentMap,
            onClose: () => setState(() => _showComponentMap = false),
          ),
      ],
    );
  }
}

// ─── Progress view ────────────────────────────────────────────────────────────

class _GeneratingView extends StatelessWidget {
  const _GeneratingView({required this.phase, required this.label});

  final int phase;
  final String label;

  static const _steps = [
    'Reading codebase',
    'Generating architecture diagram',
    'Mapping components',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GENERATING ARCHITECTURE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < _steps.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _StepRow(
                  label: _steps[i],
                  stepIndex: i + 1,
                  currentPhase: phase,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.stepIndex,
    required this.currentPhase,
  });

  final String label;
  final int stepIndex;
  final int currentPhase;

  @override
  Widget build(BuildContext context) {
    final isDone = currentPhase == 4 || stepIndex < currentPhase;
    final isActive = stepIndex == currentPhase;

    Widget leading;
    if (isDone) {
      leading =
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF22C55E));
    } else if (isActive) {
      leading = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Color(0xFFF59E0B)),
      );
    } else {
      leading = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3F3F46), width: 2),
        ),
      );
    }

    return Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDone
                  ? const Color(0xFFE5E5E7)
                  : isActive
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Component map panel ──────────────────────────────────────────────────────

class _ComponentMapPanel extends StatelessWidget {
  const _ComponentMapPanel({
    required this.componentMap,
    required this.onClose,
  });

  final Map<String, List<String>> componentMap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xFF111113),
        border: Border(left: BorderSide(color: Color(0xFF2C2C2E))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'COMPONENT MAP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2C2C2E)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final entry in componentMap.entries) ...[
                  _ComponentEntry(
                      name: entry.key, files: entry.value),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentEntry extends StatefulWidget {
  const _ComponentEntry({required this.name, required this.files});

  final String name;
  final List<String> files;

  @override
  State<_ComponentEntry> createState() => _ComponentEntryState();
}

class _ComponentEntryState extends State<_ComponentEntry> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE5E5E7)),
                    ),
                  ),
                  Text(
                    '${widget.files.length}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding:
                  const EdgeInsets.only(left: 10, right: 10, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.files
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            f,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'Menlo',
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text('Generation failed',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
