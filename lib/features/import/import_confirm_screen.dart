import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interview/state/interview_dimension.dart';
import '../interview/state/interview_state.dart';
import '../spec_generation/spec_generation_screen.dart';
import 'import_service.dart';

/// Guided gap form: the LLM-extracted spec state, with the blanks it couldn't
/// fill highlighted (and its open questions listed). You complete the gaps —
/// optionally "Dig deeper" to scan code for more — then generate the docs.
class ImportConfirmScreen extends ConsumerStatefulWidget {
  const ImportConfirmScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
    required this.result,
    this.repoPath,
  });

  final String projectPath;
  final String projectName;
  final ImportResult result;
  final String? repoPath;

  @override
  ConsumerState<ImportConfirmScreen> createState() =>
      _ImportConfirmScreenState();
}

class _ImportConfirmScreenState extends ConsumerState<ImportConfirmScreen> {
  final _c = <String, TextEditingController>{};
  late List<String> _openQuestions;
  late List<dynamic> _services;
  late List<dynamic> _userStories;
  bool _digging = false;

  static const _singleLine = [
    ('outcome', 'Outcome — the one thing this product does'),
    ('primaryUser', 'Primary user'),
    ('chosenCapability', 'V1 capability (proves the concept)'),
    ('platform', 'Platform'),
    ('identityModel', 'Identity / auth model'),
    ('inputModel', 'Input model'),
    ('outputModel', 'Output model'),
  ];
  static const _multiLine = [
    ('capabilities', 'Capabilities (one per line)'),
    ('v1UserStories', 'V1 user stories (one per line)'),
    ('demoScript', 'Demo script — V1 flow (one per line)'),
    ('v2Seeds', 'Deferred to V2 (one per line)'),
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.result.extracted;
    for (final (key, _) in _singleLine) {
      final c = TextEditingController(text: _asString(ex[key]));
      c.addListener(() => setState(() {}));
      _c[key] = c;
    }
    for (final (key, _) in _multiLine) {
      final c = TextEditingController(text: _asLines(ex[key]));
      c.addListener(() => setState(() {}));
      _c[key] = c;
    }
    _openQuestions = List<String>.from(widget.result.openQuestions);
    _services = (ex['externalServices'] as List?) ?? const [];
    _userStories = (ex['userStories'] as List?) ?? const [];
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _asString(dynamic v) => v == null ? '' : v.toString();
  String _asLines(dynamic v) =>
      v is List ? v.map((e) => e.toString()).join('\n') : '';
  List<String> _lines(String key) => _c[key]!
      .text
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String? _text(String key) {
    final s = _c[key]!.text.trim();
    return s.isEmpty ? null : s;
  }

  int get _gapCount => _c.values.where((c) => c.text.trim().isEmpty).length;

  Future<void> _digDeeper() async {
    if (widget.repoPath == null) return;
    setState(() => _digging = true);
    try {
      final svc = ref.read(importServiceProvider);
      final digest = await svc.repoDigest(widget.repoPath!, deep: true);
      final res = await svc.extract(digest);
      // Fill only currently-empty fields; never overwrite the user's edits.
      for (final (key, _) in _singleLine) {
        if (_c[key]!.text.trim().isEmpty) {
          final v = res.extracted[key];
          if (v != null) _c[key]!.text = v.toString();
        }
      }
      for (final (key, _) in _multiLine) {
        if (_c[key]!.text.trim().isEmpty) {
          final v = res.extracted[key];
          if (v is List && v.isNotEmpty) {
            _c[key]!.text = v.map((e) => e.toString()).join('\n');
          }
        }
      }
      if (_services.isEmpty) {
        _services = (res.extracted['externalServices'] as List?) ?? const [];
      }
      _openQuestions = res.openQuestions;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Dig deeper failed: $e'),
          backgroundColor: const Color(0xFF3F0A0A),
        ));
      }
    } finally {
      if (mounted) setState(() => _digging = false);
    }
  }

  void _generate() {
    final base = InterviewState.empty(
        widget.projectPath, widget.projectName, buildDimensions);
    final merged = <String, dynamic>{
      ...base.extracted,
      for (final (key, _) in _singleLine) key: _text(key),
      for (final (key, _) in _multiLine) key: _lines(key),
      'userStories': _userStories,
      'externalServices': _services,
    };
    final state = base.copyWith(
      extracted: merged,
      confidenceMap: {
        for (final d in buildDimensions) d.id: DimensionState.resolved,
      },
      currentLayer: 'L4',
      specGenEnabled: true,
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => SpecGenerationScreen(interviewState: state),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gaps = _gapCount;
    return Scaffold(
      appBar: AppBar(
        title: Text('Review — ${widget.projectName}'),
        actions: [
          if (widget.repoPath != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: TextButton.icon(
                onPressed: _digging ? null : _digDeeper,
                icon: _digging
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.travel_explore, size: 16),
                label: Text(_digging ? 'Digging…' : 'Dig deeper'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _banner(gaps),
          if (_openQuestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _openQuestionsCard(),
          ],
          const SizedBox(height: 16),
          for (final (key, label) in _singleLine) ...[
            _field(key, label),
            const SizedBox(height: 12),
          ],
          for (final (key, label) in _multiLine) ...[
            _field(key, label, maxLines: 4),
            const SizedBox(height: 12),
          ],
          if (_services.isNotEmpty) ...[
            const Text('External services',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _services)
                  Chip(
                    label: Text(
                      s is Map ? (s['name']?.toString() ?? '?') : s.toString(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: const Color(0xFF1C1C1E),
                  ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generate,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate docs'),
      ),
    );
  }

  Widget _banner(int gaps) {
    final ok = gaps == 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? const Color(0x2281C784) : const Color(0x22E8A04C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.edit_note,
              size: 18,
              color: ok ? const Color(0xFF81C784) : const Color(0xFFE8A04C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ok
                  ? 'Everything was inferred — review and generate.'
                  : '$gaps field${gaps == 1 ? '' : 's'} need your input (highlighted below)'
                      '${widget.repoPath != null ? ' — or "Dig deeper" to scan the code.' : '.'}',
              style: const TextStyle(color: Color(0xFFE5E5E7), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _openQuestionsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The Forge couldn\'t determine:',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
          const SizedBox(height: 6),
          for (final q in _openQuestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $q',
                  style: const TextStyle(
                      color: Color(0xFFCFCFD2), fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  Widget _field(String key, String label, {int maxLines = 1}) {
    final isGap = _c[key]!.text.trim().isEmpty;
    final border = isGap ? const Color(0xFFE8A04C) : const Color(0xFF2C2C2E);
    return TextField(
      controller: _c[key],
      maxLines: maxLines,
      style: const TextStyle(
          fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
      decoration: InputDecoration(
        labelText: isGap ? '$label  — needs input' : label,
        labelStyle: TextStyle(
            color: isGap ? const Color(0xFFE8A04C) : const Color(0xFF9CA3AF)),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0F0F10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: border),
        ),
      ),
    );
  }
}
