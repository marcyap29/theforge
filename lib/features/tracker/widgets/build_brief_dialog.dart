import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../services/inspector_service.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';

/// Shows a pre-build clarification dialog for [feature]. Returns the generated
/// build brief if the user proceeds, null if they cancel or skip.
Future<String?> showBuildBriefDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Feature feature,
  required String projectPath,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BuildBriefDialog(
      feature: feature,
      projectPath: projectPath,
      ref: ref,
    ),
  );
}

enum _BriefStage { idle, generating, done }

class _BuildBriefDialog extends StatefulWidget {
  const _BuildBriefDialog({
    required this.feature,
    required this.projectPath,
    required this.ref,
  });

  final Feature feature;
  final String projectPath;
  final WidgetRef ref;

  @override
  State<_BuildBriefDialog> createState() => _BuildBriefDialogState();
}

class _BuildBriefDialogState extends State<_BuildBriefDialog> {
  _BriefStage _stage = _BriefStage.idle;
  final _notesController = TextEditingController();
  String _brief = '';
  InspectorVerdict? _verdict;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _stage = _BriefStage.generating;
      _verdict = null;
    });

    final llm = widget.ref.read(llmServiceProvider);
    final extra = _notesController.text.trim();

    const system = '''
You write concise, actionable build briefs for AI coding sessions.

A good brief (1-3 paragraphs):
- States the exact user-visible outcome when done
- Names the main components or screens to create/edit
- Calls out what it should NOT do (scope boundary)
- Fits in a single AI build session

Return ONLY the brief text — no headers, no JSON, no preamble.
''';

    final userPrompt = '''
Feature: ${widget.feature.title}
${widget.feature.description != null ? 'Description: ${widget.feature.description}' : ''}
${extra.isNotEmpty ? '\nAdditional context from developer:\n$extra' : ''}

Write the build brief.
''';

    try {
      final briefText = await llm.complete(
        systemPrompt: system,
        userPrompt: userPrompt,
        temperature: 0.3,
        role: LlmRole.architect,
        maxTokens: 500,
        think: false,
      );
      setState(() {
        _brief = briefText.trim();
        _stage = _BriefStage.done;
      });

      // Inspector runs concurrently — badge appears when it resolves.
      _runInspector(briefText.trim());
    } catch (e) {
      setState(() => _stage = _BriefStage.idle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate brief: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _runInspector(String brief) async {
    final llm = widget.ref.read(llmServiceProvider);
    final example = await ProjectFileRepository.readExample(
        widget.projectPath, 'build_brief');
    final service = InspectorService(llm);
    final verdict = await service.inspectBrief(
      featureTitle: widget.feature.title,
      brief: brief,
      exampleBrief: example,
    );
    if (mounted) setState(() => _verdict = verdict);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF141416),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      title: const Text(
        'Before you build',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.feature.title,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE8A04C),
                    fontWeight: FontWeight.w500),
              ),
              if (widget.feature.description != null &&
                  widget.feature.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.feature.description!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8A8A8E)),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Anything to add or clarify before the build? (optional)',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 3,
                enabled: _stage == _BriefStage.idle,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Use existing AuthService, match Settings screen style',
                  hintStyle: const TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
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
                      horizontal: 10, vertical: 8),
                ),
              ),
              if (_stage == _BriefStage.idle) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_fix_high_outlined, size: 15),
                    label: const Text('Generate brief'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCFCFD2),
                      side: const BorderSide(color: Color(0xFF3C3C3E)),
                    ),
                  ),
                ),
              ],
              if (_stage == _BriefStage.generating) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Writing brief…',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9CA3AF))),
                    ],
                  ),
                ),
              ],
              if (_stage == _BriefStage.done) ...[
                const SizedBox(height: 16),
                _BriefBlock(
                  brief: _brief,
                  verdict: _verdict,
                  onChanged: (v) => setState(() => _brief = v),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        // Skip returns '' (empty) — caller proceeds without a brief.
        // Cancel returns null — caller aborts the build.
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Skip brief'),
        ),
        FilledButton(
          onPressed: _stage == _BriefStage.done
              ? () => Navigator.pop(context, _brief)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE8A04C),
            foregroundColor: const Color(0xFF0F0F10),
          ),
          child: const Text('Build with this brief'),
        ),
      ],
    );
  }
}

class _BriefBlock extends StatefulWidget {
  const _BriefBlock({
    required this.brief,
    required this.verdict,
    required this.onChanged,
  });

  final String brief;
  final InspectorVerdict? verdict;
  final ValueChanged<String> onChanged;

  @override
  State<_BriefBlock> createState() => _BriefBlockState();
}

class _BriefBlockState extends State<_BriefBlock> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.brief)
      ..selection = TextSelection.collapsed(offset: widget.brief.length);
  }

  @override
  void didUpdateWidget(_BriefBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.brief != oldWidget.brief && widget.brief != _controller.text) {
      _controller.text = widget.brief;
      _controller.selection =
          TextSelection.collapsed(offset: widget.brief.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Build brief',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF)),
            ),
            const Spacer(),
            _InspectorBadge(verdict: widget.verdict),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: SingleChildScrollView(
            child: TextField(
              controller: _controller,
              maxLines: null,
              style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  color: Color(0xFFE5E5E7)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ),
        if (widget.verdict != null &&
            !widget.verdict!.passes &&
            widget.verdict!.concern != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2008),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE8A04C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.verdict!.concern!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFE8A04C)),
                  ),
                  if (widget.verdict!.suggestion != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Suggestion: ${widget.verdict!.suggestion}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _InspectorBadge extends StatelessWidget {
  const _InspectorBadge({required this.verdict});
  final InspectorVerdict? verdict;

  @override
  Widget build(BuildContext context) {
    if (verdict == null) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
        SizedBox(width: 6),
        Text('Inspecting…',
            style: TextStyle(fontSize: 11, color: Color(0xFF8A8A8E))),
      ]);
    }
    if (verdict!.passes) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF34D399)),
        SizedBox(width: 4),
        Text('Looks good',
            style: TextStyle(fontSize: 11, color: Color(0xFF34D399))),
      ]);
    }
    return const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.warning_amber_outlined, size: 13, color: Color(0xFFE8A04C)),
      SizedBox(width: 4),
      Text('Review brief',
          style: TextStyle(fontSize: 11, color: Color(0xFFE8A04C))),
    ]);
  }
}
