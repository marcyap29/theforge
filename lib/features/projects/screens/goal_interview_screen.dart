import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../../../services/ingest_service.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../../tracker/models/tracker_enums.dart';
import '../../tracker/providers/tracker_providers.dart';

/// Five-question project goal interview run immediately after a new project is
/// created. Answers drive an AI call that proposes 4-8 seed features; the user
/// checks/unchecks them before they land on the board.
class GoalInterviewScreen extends ConsumerStatefulWidget {
  const GoalInterviewScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.projectPath,
  });

  final String projectId;
  final String projectName;
  final String projectPath;

  @override
  ConsumerState<GoalInterviewScreen> createState() =>
      _GoalInterviewScreenState();
}

enum _Stage { filling, generating, reviewing, saving }

class _ProposedFeature {
  _ProposedFeature({required this.title, required this.description});
  final String title;
  final String description;
  bool selected = true;
}

class _GoalInterviewScreenState
    extends ConsumerState<GoalInterviewScreen> {
  _Stage _stage = _Stage.filling;
  String? _errorMessage;

  final _q1 = TextEditingController(); // What does this app do?
  final _q2 = TextEditingController(); // Who is the first user?
  final _q3 = TextEditingController(); // Simplest demo?
  final _q4 = TextEditingController(); // Out of scope?
  final _q5 = TextEditingController(); // Hard constraints?

  List<_ProposedFeature> _proposed = [];
  List<String> _pickedFiles = [];

  @override
  void dispose() {
    _q1.dispose();
    _q2.dispose();
    _q3.dispose();
    _q4.dispose();
    _q5.dispose();
    super.dispose();
  }

  bool get _allAnswered =>
      _q1.text.trim().isNotEmpty &&
      _q2.text.trim().isNotEmpty &&
      _q3.text.trim().isNotEmpty &&
      _q4.text.trim().isNotEmpty &&
      _q5.text.trim().isNotEmpty;

  Future<void> _generate() async {
    setState(() {
      _stage = _Stage.generating;
      _errorMessage = null;
    });
    try {
      final llm = ref.read(llmServiceProvider);

      // Ingest any picked files first — extracts context into reference_context.md
      // and makes that context available to all future builds as well.
      String referenceBlock = '';
      if (_pickedFiles.isNotEmpty) {
        final ingestResult = await IngestService(llm).ingestFiles(
          filePaths: _pickedFiles,
          projectPath: widget.projectPath,
        );
        if (ingestResult.hasProcessed) {
          // Read back the freshly written context so we can include it in
          // this prompt directly (not just persisted for later).
          try {
            final repo = ProjectFileRepository();
            final ctx = await repo.readIngestedSummary(widget.projectPath);
            if (ctx != null && ctx.isNotEmpty) {
              referenceBlock =
                  '\nReference material extracted from attached files:\n$ctx\n';
            }
          } catch (_) {}
        }
      }

      const system = '''
You help set up new software projects by proposing seed features for the first version.

Propose 4-8 small, buildable features based on the project context.

Each feature must:
- Be completable in a single AI build session (one screen or capability)
- Describe a user-visible result, not an internal mechanism
- Be concrete (not "improve UI" — instead "Add dark mode toggle in Settings")

Return ONLY valid JSON, no prose:
{"features": [{"title": "...", "description": "..."}]}
Order from most to least critical.
''';
      final userPrompt = '''
Project: ${widget.projectName}

Q1 – What does this app do in one sentence?
${_q1.text.trim()}

Q2 – Who is the first person to use it?
${_q2.text.trim()}

Q3 – Describe the simplest demo that proves it works.
${_q3.text.trim()}

Q4 – What is explicitly out of scope for the first version?
${_q4.text.trim()}

Q5 – Any hard constraints? (platforms, integrations, existing code)
${_q5.text.trim()}
$referenceBlock''';
      final raw = await llm.complete(
        systemPrompt: system,
        userPrompt: userPrompt,
        temperature: 0.3,
        role: LlmRole.architect,
        maxTokens: 1200,
        think: false,
        jsonMode: true,
      );
      final json = jsonDecode(_stripFences(raw)) as Map<String, dynamic>;
      final list = (json['features'] as List?) ?? [];
      setState(() {
        _proposed = list.map((e) {
          final m = e as Map<String, dynamic>;
          return _ProposedFeature(
            title: (m['title'] as String?) ?? '',
            description: (m['description'] as String?) ?? '',
          );
        }).where((f) => f.title.isNotEmpty).toList();
        _stage = _Stage.reviewing;
      });
    } catch (e) {
      setState(() {
        _stage = _Stage.filling;
        _errorMessage = 'Could not generate features: $e';
      });
    }
  }

  Future<void> _save() async {
    final selected = _proposed.where((f) => f.selected).toList();
    if (selected.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _stage = _Stage.saving);
    final notifier =
        ref.read(featureListProvider(widget.projectId).notifier);
    for (final f in selected) {
      await notifier.addFeature(
        title: f.title,
        description: f.description.isEmpty ? null : f.description,
        status: FeatureStatus.planned,
        source: 'goal_interview',
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'png', 'jpg', 'jpeg', 'heic', 'gif', 'webp',
        'txt', 'md', 'markdown',
      ],
    );
    if (result == null) return;
    final paths =
        result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    setState(() {
      _pickedFiles = [
        ..._pickedFiles,
        ...paths.where((path) => !_pickedFiles.contains(path)),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set up ${widget.projectName}'),
        actions: [
          if (_stage == _Stage.filling)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
        ],
      ),
      body: switch (_stage) {
        _Stage.filling => _buildForm(),
        _Stage.generating => _buildGenerating(),
        _Stage.reviewing => _buildReview(),
        _Stage.saving => _buildGenerating(),
      },
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Answer 5 quick questions to seed your feature board with the right first things to build.',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
            ),
          ),
        _Question(
          number: 1,
          label: 'What does this app do in one sentence?',
          hint: 'e.g. Tracks daily habits with streaks and reminders',
          controller: _q1,
        ),
        _Question(
          number: 2,
          label: 'Who is the first person to use it?',
          hint: 'e.g. A freelancer managing multiple clients',
          controller: _q2,
        ),
        _Question(
          number: 3,
          label: 'Describe the simplest demo that proves it works.',
          hint: 'e.g. User adds a habit, checks it off, sees their streak',
          controller: _q3,
          maxLines: 3,
        ),
        _Question(
          number: 4,
          label: 'What is explicitly out of scope for this first version?',
          hint: 'e.g. No social features, no sync across devices',
          controller: _q4,
        ),
        _Question(
          number: 5,
          label: 'Any hard constraints?',
          hint: 'e.g. iOS only, must use existing Firebase project',
          controller: _q5,
        ),
        const SizedBox(height: 20),
        const Text(
          'Reference files (optional)',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE5E5E7)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Screenshots, mockups, or docs the AI should use as context.',
          style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 8),
        if (_pickedFiles.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final path in _pickedFiles)
                Chip(
                  label: Text(
                    p.basename(path),
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFFE5E5E7)),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () =>
                      setState(() => _pickedFiles.remove(path)),
                  backgroundColor: const Color(0xFF1C1C1E),
                  side:
                      const BorderSide(color: Color(0xFF3C3C3E)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickFiles,
          icon: const Icon(Icons.attach_file_outlined, size: 15),
          label: Text(_pickedFiles.isEmpty ? 'Attach files' : 'Add more files'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFCFCFD2),
            side: const BorderSide(color: Color(0xFF3C3C3E)),
          ),
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: Listenable.merge([_q1, _q2, _q3, _q4, _q5]),
          builder: (context, _) => SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: _allAnswered ? _generate : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8A04C),
                foregroundColor: const Color(0xFF0F0F10),
                disabledBackgroundColor: const Color(0xFF2C2C2E),
              ),
              child: const Text(
                'Generate Features →',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerating() {
    final label = _pickedFiles.isNotEmpty && _stage == _Stage.generating
        ? 'Processing files & proposing features…'
        : _stage == _Stage.saving
            ? 'Saving features…'
            : 'Proposing features…';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    final selected = _proposed.where((f) => f.selected).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Select the features to add to your board:',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  for (final f in _proposed) {
                    f.selected = true;
                  }
                }),
                child: const Text('All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _proposed.length,
            itemBuilder: (_, i) {
              final f = _proposed[i];
              return CheckboxListTile(
                value: f.selected,
                onChanged: (v) => setState(() => f.selected = v ?? false),
                title: Text(
                  f.title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                subtitle: f.description.isEmpty
                    ? null
                    : Text(
                        f.description,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF)),
                      ),
                activeColor: const Color(0xFFE8A04C),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Row(
            children: [
              TextButton(
                onPressed: () =>
                    setState(() => _stage = _Stage.filling),
                child: const Text('Back'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: selected > 0 ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A04C),
                  foregroundColor: const Color(0xFF0F0F10),
                ),
                child: Text(
                  'Add $selected feature${selected == 1 ? '' : 's'} →',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Strips markdown code fences that some models wrap JSON in despite jsonMode.
/// e.g. ```json\n{...}\n``` → {...}
String _stripFences(String raw) {
  final t = raw.trim();
  if (!t.startsWith('`')) return t;
  final firstNewline = t.indexOf('\n');
  if (firstNewline == -1) return t;
  final inner = t.substring(firstNewline + 1).trimRight();
  return inner.endsWith('```') ? inner.substring(0, inner.length - 3).trim() : inner;
}

class _Question extends StatelessWidget {
  const _Question({
    required this.number,
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  final int number;
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '$number. $label',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFE5E5E7),
              ),
            ),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  color: Color(0xFF6B7280)),
              filled: true,
              fillColor: const Color(0xFF0F0F10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFF2C2C2E)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFF2C2C2E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide:
                    const BorderSide(color: Color(0xFFE8A04C)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
