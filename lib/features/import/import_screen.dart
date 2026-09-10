import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/filesystem/project_file_repository.dart';
import 'import_confirm_screen.dart';
import 'import_service.dart';

/// Import a description / document / transcript, or point at an existing repo,
/// and generate the full deliverable set — an alternative to the interactive
/// interview. Repo analysis auto-fills what it can and surfaces the gaps.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  final String projectPath;
  final String projectName;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _source = TextEditingController();
  bool _busy = false;
  String _status = '';
  String? _repoPath;

  @override
  void initState() {
    super.initState();
    _source.addListener(() => setState(() {}));
    _loadRepoPath();
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  Future<void> _loadRepoPath() async {
    final config =
        await ProjectFileRepository.readProjectConfig(widget.projectPath);
    final rp = config['repoPath'] as String?;
    if (mounted && rp != null && rp.isNotEmpty) {
      setState(() => _repoPath = rp);
    }
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt'],
    );
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      final header = '\n\n--- ${p.basename(path)} ---\n';
      _source.text =
          _source.text.isEmpty ? content : '${_source.text}$header$content';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read file: $e')));
      }
    }
  }

  /// Pure-repo path: pick a folder, ingest it (docs + structure), and auto-fill.
  Future<void> _analyzeRepo() async {
    final messenger = ScaffoldMessenger.of(context);
    String? picked;
    try {
      picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select the repository to analyze',
        // Attach the panel to the window; an app-modal panel can fail to
        // present on macOS otherwise (looks like "nothing happened").
        lockParentWindow: true,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not open the folder picker: $e'),
        backgroundColor: const Color(0xFF3F0A0A),
      ));
      return;
    }
    if (picked == null) return;
    final repoPath = picked; // non-null; safe to capture in closures
    if (!mounted) return;
    final deep = await _chooseDepth();
    if (deep == null) return; // cancelled
    // Persist as the project's linked repo (also enables future check-ins).
    await ProjectFileRepository.writeProjectConfig(
        widget.projectPath, {'repoPath': repoPath});
    if (mounted) setState(() => _repoPath = repoPath);

    await _run(
      status: deep ? 'Deep scan — reading code…' : 'Analyzing repository…',
      buildSource: () async =>
          ref.read(importServiceProvider).repoSource(repoPath, deep: deep),
      repoPath: repoPath,
    );
  }

  /// Lets the user pick how thorough the repo scan is. Returns true for a deep
  /// scan, false for quick, null if cancelled.
  Future<bool?> _chooseDepth() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('How thorough?',
            style: TextStyle(color: Color(0xFFE5E5E7), fontSize: 16)),
        content: const Text(
          'Quick reads the README, docs, and file structure — fast.\n\n'
          'Deep also reads and analyzes the source code for higher fidelity '
          '(slower, more LLM calls). You can also "Dig deeper" later.',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quick scan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE8A04C),
              foregroundColor: const Color(0xFF0F0F10),
            ),
            child: const Text('Deep scan'),
          ),
        ],
      ),
    );
  }

  /// Text path: description / transcript, optionally augmented by the linked repo.
  Future<void> _generateFromText() async {
    await _run(
      status: 'Reading…',
      buildSource: () async => _source.text.trim(),
      repoPath: _repoPath,
    );
  }

  Future<void> _run({
    required String status,
    required Future<String> Function() buildSource,
    String? repoPath,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _status = status;
    });
    try {
      final source = await buildSource();
      final result = await ref.read(importServiceProvider).extract(source);
      if (!mounted) return;
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => ImportConfirmScreen(
          projectPath: widget.projectPath,
          projectName: widget.projectName,
          result: result,
          repoPath: repoPath,
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Import failed: $e'),
        backgroundColor: const Color(0xFF3F0A0A),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Import → Spec — ${widget.projectName}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repo path — the headline for onboarding an existing app.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x1AE8A04C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x55E8A04C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Onboard an existing repo',
                      style: TextStyle(
                          color: Color(0xFFE5E5E7),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    'Point at a repo. The Forge reads its docs + structure, '
                    'auto-fills the spec, and asks you only for what it can\'t '
                    'infer — then generates every doc.',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : _analyzeRepo,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE8A04C),
                      foregroundColor: const Color(0xFF0F0F10),
                    ),
                    icon: const Icon(Icons.radar, size: 18),
                    label: Text(_repoPath == null
                        ? 'Analyze a repo…'
                        : 'Analyze ${p.basename(_repoPath!)}…'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Or describe it / paste a doc or transcript',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _source,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                    fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
                decoration: InputDecoration(
                  hintText: 'Describe the app, or paste a transcript / doc…',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF0F0F10),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _importFile,
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Import file…'),
                ),
                const Spacer(),
                if (_busy)
                  Row(children: [
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text(_status,
                        style: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 12)),
                  ]),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: (_busy || _source.text.trim().isEmpty)
                    ? null
                    : _generateFromText,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: const Color(0xFFE5E5E7),
                ),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Draft spec from text'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
