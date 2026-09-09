import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interview/state/interview_dimension.dart';
import '../interview/state/interview_state.dart';
import '../spec_generation/spec_generation_screen.dart';

/// Compressed confirm step: the LLM-extracted spec state, editable on one
/// screen, before it feeds the existing spec/worksheet/handoff generator.
class ImportConfirmScreen extends ConsumerStatefulWidget {
  const ImportConfirmScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
    required this.extracted,
  });

  final String projectPath;
  final String projectName;
  final Map<String, dynamic> extracted;

  @override
  ConsumerState<ImportConfirmScreen> createState() =>
      _ImportConfirmScreenState();
}

class _ImportConfirmScreenState extends ConsumerState<ImportConfirmScreen> {
  final _c = <String, TextEditingController>{};

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
    for (final (key, _) in _singleLine) {
      _c[key] = TextEditingController(text: _asString(widget.extracted[key]));
    }
    for (final (key, _) in _multiLine) {
      _c[key] = TextEditingController(text: _asLines(widget.extracted[key]));
    }
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

  void _generate() {
    // Start from the interview's empty template so every expected key exists,
    // then overlay the confirmed values.
    final base = InterviewState.empty(
        widget.projectPath, widget.projectName, buildDimensions);
    final merged = <String, dynamic>{
      ...base.extracted,
      for (final (key, _) in _singleLine) key: _text(key),
      for (final (key, _) in _multiLine) key: _lines(key),
      // Pass through fields we don't edit here.
      'userStories': widget.extracted['userStories'] ?? <String>[],
      'externalServices':
          widget.extracted['externalServices'] ?? <Map<String, dynamic>>[],
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
    final services = (widget.extracted['externalServices'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('Review — ${widget.projectName}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const Text(
            'The LLM drafted this from your import. Edit anything, then generate '
            'the spec, worksheet, and handoff.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
          const SizedBox(height: 16),
          for (final (key, label) in _singleLine) ...[
            _field(key, label),
            const SizedBox(height: 12),
          ],
          for (final (key, label) in _multiLine) ...[
            _field(key, label, maxLines: 4),
            const SizedBox(height: 12),
          ],
          if (services.isNotEmpty) ...[
            const Text('External services',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in services)
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

  Widget _field(String key, String label, {int maxLines = 1}) {
    return TextField(
      controller: _c[key],
      maxLines: maxLines,
      style: const TextStyle(
          fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0F0F10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
        ),
      ),
    );
  }
}
