import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
import '../../../services/diag_log.dart';
import '../scan/feature_scan.dart';

/// "Security Check" — an on-demand security review of the whole app/repo: a
/// deterministic secret pre-scan + LLM audit (secrets, permissions, deps,
/// unsafe patterns, fix-first). Read-only; generated from the current repo.
class SecurityCheckScreen extends ConsumerStatefulWidget {
  const SecurityCheckScreen({
    super.key,
    required this.project,
    required this.repoPath,
  });

  final Project project;
  final String? repoPath;

  @override
  ConsumerState<SecurityCheckScreen> createState() =>
      _SecurityCheckScreenState();
}

class _SecurityCheckScreenState extends ConsumerState<SecurityCheckScreen> {
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
      final md = await ref.read(featureScannerProvider).securityCheck(
            projectPath: widget.project.path,
            repoPath: widget.repoPath,
          );
      if (!mounted) return;
      setState(() => _markdown = md);
    } catch (e, st) {
      await DiagLog.error('security.check', e, st);
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
        title: Text('Security Check — ${widget.project.name}',
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_markdown != null && !_generating)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _markdown!));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report copied')));
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
              label: Text(_generating ? 'Scanning…' : 'Re-scan'),
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
                  Text('Scanning the repo for secrets and reviewing security…',
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
                        color: Color(0xFFE57373)),
                    listBullet: const TextStyle(
                        fontSize: 13.5, color: Color(0xFFE5E5E7)),
                    strong: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFFF3C77B)),
                    code: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 12,
                        backgroundColor: Color(0xFF1E1E22)),
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
