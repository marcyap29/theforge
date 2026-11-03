import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../projects/providers/providers.dart';
import '../data/prompt_generator.dart';
import '../providers/prompt_providers.dart';

const _uuid = Uuid();

class PromptScreen extends ConsumerStatefulWidget {
  const PromptScreen({
    super.key,
    required this.project,
    required this.feature,
    this.repoPath,
  });

  final Project project;
  final Feature feature;
  final String? repoPath;

  @override
  ConsumerState<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends ConsumerState<PromptScreen> {
  int _phase = 0; // 0 = queued, 1-3 = generating, 4 = done, -1 = error
  String _label = 'Starting…';
  PromptGeneratorResult? _result;
  String? _error;
  String? _savedRecordId;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _phase = 0;
      _label = 'Starting…';
      _result = null;
      _error = null;
      _savedRecordId = null;
      _copied = false;
    });

    final generator = ref.read(promptGeneratorProvider);
    try {
      final result = await generator.generate(
        feature: widget.feature,
        projectPath: widget.project.path,
        projectName: widget.project.name,
        repoPath: widget.repoPath,
        onProgress: (phase, label) {
          if (mounted) setState(() { _phase = phase; _label = label; });
        },
      );
      await _saveResult(result);
    } catch (e) {
      if (mounted) setState(() { _phase = -1; _error = e.toString(); });
    }
  }

  Future<void> _saveResult(PromptGeneratorResult result) async {
    final dt = DateTime.now();
    final ts = '${dt.year.toString().padLeft(4, '0')}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}'
        '_${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';

    String promptPath;
    try {
      promptPath = await ProjectFileRepository.writePrompt(
        projectPath: widget.project.path,
        featureId: widget.feature.id,
        timestamp: ts,
        content: result.prompt,
      );
    } catch (_) {
      promptPath = 'prompts/${widget.feature.id}/$ts.md';
    }

    final recordId = _uuid.v4();
    final now = dt.millisecondsSinceEpoch;
    final db = ref.read(forgeDatabaseProvider);
    await db.insertPromptRecord(PromptRecordsCompanion(
      id: Value(recordId),
      featureId: Value(widget.feature.id),
      projectId: Value(widget.feature.projectId),
      createdAt: Value(now),
      promptPath: Value(promptPath),
    ));

    ref.invalidate(promptHistoryProvider((
      projectId: widget.feature.projectId,
      featureId: widget.feature.id,
    )));

    if (mounted) {
      setState(() {
        _phase = 4;
        _result = result;
        _savedRecordId = recordId;
      });
    }
  }

  Future<void> _copyPrompt() async {
    if (_result == null) return;
    await Clipboard.setData(ClipboardData(text: _result!.prompt));
    if (!mounted) return;
    setState(() => _copied = true);
    if (_savedRecordId != null) {
      await ref.read(forgeDatabaseProvider).updatePromptStatus(_savedRecordId!, 'copied');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prompt copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.feature.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Prompt'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PromptTab(
              phase: _phase,
              label: _label,
              result: _result,
              error: _error,
              copied: _copied,
              onCopy: _copyPrompt,
              onRetry: _generate,
            ),
            _HistoryTab(
              projectId: widget.feature.projectId,
              featureId: widget.feature.id,
              projectPath: widget.project.path,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Prompt Tab ───────────────────────────────────────────────────────────────

class _PromptTab extends StatelessWidget {
  const _PromptTab({
    required this.phase,
    required this.label,
    required this.result,
    required this.error,
    required this.copied,
    required this.onCopy,
    required this.onRetry,
  });

  final int phase;
  final String label;
  final PromptGeneratorResult? result;
  final String? error;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (phase == -1) {
      return _ErrorView(error: error ?? 'Unknown error', onRetry: onRetry);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StepList(phase: phase, label: label),
        if (phase == 4 && result != null) ...[
          const SizedBox(height: 24),
          _PromptDisplay(prompt: result!.prompt, copied: copied, onCopy: onCopy),
        ],
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.phase, required this.label});

  final int phase;
  final String label;

  static const _steps = [
    'Analyzing impact',
    'Writing acceptance criteria',
    'Writing Claude Code prompt',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _StepRow(
              label: _steps[i],
              stepIndex: i + 1,
              currentPhase: phase,
            ),
          ],
          if (phase > 0 && phase < 4) ...[
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
        ],
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
      leading = const Icon(Icons.check_circle, size: 18, color: Color(0xFF22C55E));
    } else if (isActive) {
      leading = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFF59E0B),
        ),
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

class _PromptDisplay extends StatelessWidget {
  const _PromptDisplay({
    required this.prompt,
    required this.copied,
    required this.onCopy,
  });

  final String prompt;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CLAUDE CODE PROMPT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Color(0xFF9CA3AF),
              ),
            ),
            FilledButton.icon(
              onPressed: onCopy,
              icon: Icon(
                copied ? Icons.check : Icons.copy,
                size: 14,
              ),
              label: Text(copied ? 'Copied!' : 'Copy prompt'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: SelectableText(
            prompt,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Menlo',
              color: Color(0xFFE5E5E7),
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

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
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            const Text(
              'Generation failed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
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

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({
    required this.projectId,
    required this.featureId,
    required this.projectPath,
  });

  final String projectId;
  final String featureId;
  final String projectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(
      promptHistoryProvider((projectId: projectId, featureId: featureId)),
    );

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load history: $e')),
      data: (records) {
        if (records.isEmpty) {
          return const Center(
            child: Text(
              'No saved prompts yet.',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = records[i];
            final dt =
                DateTime.fromMillisecondsSinceEpoch(r.createdAt).toLocal();
            final label =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            return _HistoryTile(
              label: label,
              status: r.status,
              onTap: () => _viewPrompt(context, r, label),
            );
          },
        );
      },
    );
  }

  Future<void> _viewPrompt(
      BuildContext context, PromptRecord record, String label) async {
    final content =
        await ProjectFileRepository.readPromptByPath(projectPath, record.promptPath);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        content ??
                            '(File not found at ${record.promptPath})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Menlo',
                          color: Color(0xFFE5E5E7),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (content != null) {
                        Clipboard.setData(ClipboardData(text: content));
                      }
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copy & close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.label,
    required this.status,
    required this.onTap,
  });

  final String label;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7)),
              ),
            ),
            if (status == 'copied')
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 13, color: Color(0xFF22C55E)),
                  SizedBox(width: 4),
                  Text('copied',
                      style:
                          TextStyle(fontSize: 11, color: Color(0xFF22C55E))),
                ],
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}
