import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../services/diag_log.dart';
import '../providers/tracker_providers.dart';
import '../scan/feature_scan.dart';

/// "What this app can do" — an LLM-generated, plain-language overview of the
/// project's CURRENT capabilities, analyzed from the live repo. Cached (shown
/// instantly) and re-generated on demand; flags itself stale when the repo has
/// new commits since the summary was made.
class CapabilitySummaryScreen extends ConsumerStatefulWidget {
  const CapabilitySummaryScreen({
    super.key,
    required this.project,
    required this.repoPath,
  });

  final Project project;
  final String? repoPath;

  @override
  ConsumerState<CapabilitySummaryScreen> createState() =>
      _CapabilitySummaryScreenState();
}

class _CapabilitySummaryScreenState
    extends ConsumerState<CapabilitySummaryScreen> {
  String? _markdown;
  String? _generatedAt;
  String? _cachedCommit;
  String? _headCommit;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached =
        await ProjectFileRepository.readCapabilitySummary(widget.project.path);
    final head = widget.repoPath == null
        ? null
        : await ProjectFileRepository.getGitHead(widget.repoPath!);
    if (!mounted) return;
    setState(() {
      _markdown = cached?['markdown'] as String?;
      _generatedAt = cached?['generatedAt'] as String?;
      _cachedCommit = cached?['commit'] as String?;
      _headCommit = head;
      _loading = false;
    });
    // Nothing cached yet → generate straight away so the screen isn't empty.
    if (_markdown == null && !_generating) _generate();
  }

  bool get _stale =>
      _headCommit != null &&
      _cachedCommit != null &&
      _headCommit != _cachedCommit;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final features =
          ref.read(featureListProvider(widget.project.id)).valueOrNull ??
              const <Feature>[];
      final md = await ref.read(featureScannerProvider).describeCapabilities(
            projectPath: widget.project.path,
            repoPath: widget.repoPath,
            features: features,
          );
      final head = widget.repoPath == null
          ? null
          : await ProjectFileRepository.getGitHead(widget.repoPath!);
      await ProjectFileRepository.writeCapabilitySummary(
        widget.project.path,
        markdown: md,
        commit: head,
      );
      if (!mounted) return;
      setState(() {
        _markdown = md;
        _cachedCommit = head;
        _headCommit = head;
        _generatedAt = DateTime.now().toIso8601String();
      });
    } catch (e, st) {
      await DiagLog.error('capability.describe', e, st);
      if (!mounted) return;
      setState(() => _error = e is FeatureScanException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String get _generatedLabel {
    final at = _generatedAt;
    if (at == null) return '';
    final dt = DateTime.tryParse(at);
    if (dt == null) return '';
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Generated ${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('What this app can do — ${widget.project.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_markdown == null ? Icons.auto_awesome : Icons.refresh,
                      size: 16),
              label: Text(_generating
                  ? 'Analyzing…'
                  : _markdown == null
                      ? 'Analyze'
                      : 'Refresh'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_stale && !_generating) _staleBar(),
                if (_error != null) _errorBar(),
                Expanded(child: _body()),
                if (_generatedLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_generatedLabel,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF6B7280))),
                  ),
              ],
            ),
    );
  }

  Widget _staleBar() => Material(
        color: const Color(0x22E8A04C),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(children: [
            const Icon(Icons.history, size: 18, color: Color(0xFFE8A04C)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'The repo has changed since this summary was generated.',
                style: TextStyle(color: Color(0xFFE5E5E7), fontSize: 12.5),
              ),
            ),
            TextButton(
              onPressed: _generate,
              child: const Text('Refresh',
                  style: TextStyle(color: Color(0xFFE8A04C))),
            ),
          ]),
        ),
      );

  Widget _errorBar() => Material(
        color: const Color(0x33E57373),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.error_outline, size: 18, color: Color(0xFFE57373)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFE5E5E7), fontSize: 12.5)),
            ),
          ]),
        ),
      );

  Widget _body() {
    if (_generating && _markdown == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Reading the repo and writing the overview…',
              style: TextStyle(color: Color(0xFF9CA3AF))),
        ]),
      );
    }
    if (_markdown == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No summary yet. Tap Analyze to have The Forge read the repo and '
            'describe what the app can currently do.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ),
      );
    }
    return Markdown(
      data: _markdown!,
      selectable: true,
      padding: const EdgeInsets.all(20),
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFFE5E5E7)),
        h1: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFE5E5E7)),
        h2: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE8A04C)),
        listBullet:
            const TextStyle(fontSize: 13.5, color: Color(0xFFE5E5E7)),
      ),
    );
  }
}
