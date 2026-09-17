import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
import '../../../services/diag_log.dart';
import '../providers/tracker_providers.dart';
import '../scan/feature_scan.dart';

/// "How to build this" — scale-aware, LLM-generated advice for a single feature:
/// scope (feature vs epic), feasibility (can Build-with-AI do it?), recommended
/// approach + libraries, effort, risks, and a suggested breakdown. Generated
/// on-demand from the current repo; not cached (it's a deliberate question).
class BuildAdviceScreen extends ConsumerStatefulWidget {
  const BuildAdviceScreen({
    super.key,
    required this.project,
    required this.repoPath,
    required this.feature,
  });

  final Project project;
  final String? repoPath;
  final Feature feature;

  @override
  ConsumerState<BuildAdviceScreen> createState() => _BuildAdviceScreenState();
}

class _BuildAdviceScreenState extends ConsumerState<BuildAdviceScreen> {
  String? _markdown;
  bool _generating = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final all =
          ref.read(featureListProvider(widget.project.id)).valueOrNull ??
              const <Feature>[];
      final md = await ref.read(featureScannerProvider).adviseBuild(
            projectPath: widget.project.path,
            repoPath: widget.repoPath,
            feature: widget.feature,
            allFeatures: all,
          );
      if (!mounted) return;
      setState(() => _markdown = md);
    } catch (e, st) {
      await DiagLog.error('feature.advise', e, st);
      if (!mounted) return;
      setState(() => _error = e is FeatureScanException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('How to build — ${widget.feature.title}',
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_markdown != null && !_generating)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _markdown!));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Advice copied')));
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 16),
              label: Text(_generating ? 'Thinking…' : 'Regenerate'),
            ),
          ),
        ],
      ),
      body: _error != null
          ? _errorView()
          : _generating && _markdown == null
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Reading the repo and thinking through the approach…',
                      style: TextStyle(color: Color(0xFF9CA3AF))),
                ]))
              : Markdown(
                  data: _markdown ?? '',
                  selectable: true,
                  padding: const EdgeInsets.all(20),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                        fontSize: 13.5, height: 1.5, color: Color(0xFFE5E5E7)),
                    h1: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE5E5E7)),
                    h2: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8A04C)),
                    listBullet: const TextStyle(
                        fontSize: 13.5, color: Color(0xFFE5E5E7)),
                    strong: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFFF3C77B)),
                  ),
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 30, color: Color(0xFFE57373)),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE5E5E7), fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try again'),
            ),
          ]),
        ),
      );
}
