import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/filesystem/project_file_repository.dart';
import 'import_confirm_screen.dart';
import 'import_service.dart';

/// Import a description / document / transcript (and optionally the linked repo)
/// and generate the full deliverable set in one shot — an alternative to the
/// interactive interview.
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
  bool _includeRepo = false;
  bool _busy = false;
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
      _source.text = _source.text.isEmpty ? content : '${_source.text}$header$content';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read file: $e')));
      }
    }
  }

  bool get _canGenerate =>
      !_busy && (_source.text.trim().isNotEmpty || _includeRepo);

  Future<void> _generate() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final service = ref.read(importServiceProvider);
      var source = _source.text.trim();
      if (_includeRepo && _repoPath != null) {
        source = '$source\n\n${await service.repoDigest(_repoPath!)}';
      }
      final extracted = await service.extract(source);
      if (!mounted) return;
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => ImportConfirmScreen(
          projectPath: widget.projectPath,
          projectName: widget.projectName,
          extracted: extracted,
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
            const Text(
              'Paste a description, product brief, or chat transcript — or import '
              'a .md/.txt file. The Forge will draft a spec you can review, then '
              'generate the same docs an interview would.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            const SizedBox(height: 12),
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
                if (_repoPath != null)
                  Row(
                    children: [
                      Checkbox(
                        value: _includeRepo,
                        activeColor: const Color(0xFFE8A04C),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _includeRepo = v ?? false),
                      ),
                      Text('Include repo (${p.basename(_repoPath!)})',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: _canGenerate ? _generate : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A04C),
                  foregroundColor: const Color(0xFF0F0F10),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_busy ? 'Reading…' : 'Draft spec from import'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
