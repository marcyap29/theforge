import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tracker/widgets/active_model_chip.dart';
import '../models/run_session.dart';
import '../providers/implementation_notifier.dart';
import '../widgets/diff_view.dart';

/// The "Build with AI" window: the user watches The Forge implement one feature
/// — a live activity console, inline approval of proposed edits/commands, and a
/// step timeline. Pops `true` if the user marks the feature shipped.
class ImplementationScreen extends ConsumerStatefulWidget {
  const ImplementationScreen({super.key, required this.brief});

  final ImplBrief brief;

  @override
  ConsumerState<ImplementationScreen> createState() =>
      _ImplementationScreenState();
}

class _ImplementationScreenState extends ConsumerState<ImplementationScreen> {
  final _scroll = ScrollController();
  Timer? _ticker;

  /// Start-line indices of internal-thinking blocks the user has collapsed.
  final Set<int> _collapsedThinking = {};

  String get _featureId => widget.brief.featureId;

  @override
  void initState() {
    super.initState();
    // start() is idempotent (guards on idle), so re-entering an in-flight or
    // finished run re-attaches rather than restarting.
    Future.microtask(
      () => ref.read(implRunProvider(_featureId).notifier).start(widget.brief),
    );
    // Tick once a second so the header's elapsed time advances.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// True when the view is already at (or very near) the bottom — used so we
  /// only "stick" to new output when the user hasn't scrolled up to read.
  bool get _isAtBottom {
    if (!_scroll.hasClients) return true;
    return _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120;
  }

  /// Start-line indices of each consecutive internal-thinking block.
  static List<int> _thinkingStarts(List<ConsoleLine> lines) {
    final starts = <int>[];
    var i = 0;
    while (i < lines.length) {
      if (lines[i].kind == ConsoleLineKind.thinking) {
        starts.add(i);
        while (i < lines.length && lines[i].kind == ConsoleLineKind.thinking) {
          i++;
        }
      } else {
        i++;
      }
    }
    return starts;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(implRunProvider(_featureId));
    final notifier = ref.read(implRunProvider(_featureId).notifier);

    // Follow new output (including live in-place reasoning updates) only when
    // the user is already at the bottom — so scrolling up to read the thought
    // process isn't interrupted.
    ref.listen(implRunProvider(_featureId), (prev, next) {
      if (!identical(prev?.console, next.console) && _isAtBottom) _autoScroll();
      // Tidy up when the run finishes successfully: fold the internal thinking.
      if (prev?.phase != RunPhase.done && next.phase == RunPhase.done) {
        final starts = _thinkingStarts(next.console);
        if (starts.isNotEmpty) {
          setState(() => _collapsedThinking.addAll(starts));
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        title: Text(
          'Build: ${widget.brief.featureTitle}',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: ActiveModelChip(),
          ),
          if (state.startedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
              child: Text(
                _fmt(state.elapsed(DateTime.now())),
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  color: Color(0xFF8A8A8E),
                ),
              ),
            ),
          _PhaseChip(phase: state.phase),
          const SizedBox(width: 8),
          if (!state.phase.isTerminal && state.phase != RunPhase.idle)
            TextButton.icon(
              onPressed: notifier.stop,
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('Stop'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF453A),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: _Console(
                    lines: state.console,
                    controller: _scroll,
                    running: !state.phase.isTerminal,
                    collapsed: _collapsedThinking,
                    onToggleBlock: (i) => setState(() {
                      _collapsedThinking.contains(i)
                          ? _collapsedThinking.remove(i)
                          : _collapsedThinking.add(i);
                    }),
                  ),
                ),
                if (state.phase == RunPhase.awaitingApproval &&
                    state.plan != null)
                  _ApprovalPanel(
                    state: state,
                    onToggleEdit: notifier.toggleEdit,
                    onToggleCommand: notifier.toggleCommand,
                    onApply: notifier.applyAndRun,
                    onRevise: notifier.revise,
                    onEditContent: notifier.editProposedContent,
                    onEditCommand: notifier.editProposedCommand,
                  ),
                if (state.phase == RunPhase.done)
                  _DoneBar(
                    alreadyShipped: state.featureShipped,
                    canFix: state.canFix,
                    onShip: () {
                      notifier.markFeatureShipped();
                      Navigator.of(context).pop(true);
                    },
                    onFix: notifier.fix,
                    onClose: () =>
                        Navigator.of(context).pop(state.featureShipped),
                  ),
                if (state.phase == RunPhase.failed ||
                    state.phase == RunPhase.stopped)
                  _FailedBar(
                    error: state.error,
                    stopped: state.phase == RunPhase.stopped,
                    onRetry: () {
                      notifier.reset();
                      Future.microtask(() => notifier.start(widget.brief));
                    },
                    onClose: () => Navigator.of(context).pop(false),
                  ),
              ],
            ),
          ),
          Container(width: 1, color: const Color(0xFF1C1C1E)),
          SizedBox(
            width: 260,
            child: _Timeline(state: state, onUndo: notifier.undo),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase});
  final RunPhase phase;

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      RunPhase.done => const Color(0xFF81C784),
      RunPhase.failed => const Color(0xFFFF453A),
      RunPhase.stopped => const Color(0xFF9E9E9E),
      _ => const Color(0xFFE8A04C),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (phase.isBusy)
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 6),
          Text(phase.label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

/// One rendered console item: either a normal line, or a collapsible block of
/// consecutive internal-thinking lines.
class _ConsoleItem {
  _ConsoleItem.line(this.line, this.startIndex) : think = null;
  _ConsoleItem.think(this.think, this.startIndex) : line = null;
  final ConsoleLine? line;
  final List<ConsoleLine>? think;
  final int startIndex;
  bool get isThinking => think != null;
}

class _Console extends StatelessWidget {
  const _Console({
    required this.lines,
    required this.controller,
    required this.running,
    required this.collapsed,
    required this.onToggleBlock,
  });

  final List<ConsoleLine> lines;
  final ScrollController controller;
  final bool running;
  final Set<int> collapsed;
  final ValueChanged<int> onToggleBlock;

  static const _streamed = {
    ConsoleLineKind.stdout,
    ConsoleLineKind.stderr,
    ConsoleLineKind.thinking,
    ConsoleLineKind.presentation,
  };

  /// Groups consecutive internal-thinking lines into a single collapsible item.
  List<_ConsoleItem> _items() {
    final items = <_ConsoleItem>[];
    var i = 0;
    while (i < lines.length) {
      if (lines[i].kind == ConsoleLineKind.thinking) {
        final start = i;
        final group = <ConsoleLine>[];
        while (i < lines.length && lines[i].kind == ConsoleLineKind.thinking) {
          group.add(lines[i]);
          i++;
        }
        items.add(_ConsoleItem.think(group, start));
      } else {
        items.add(_ConsoleItem.line(lines[i], i));
        i++;
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      interactive: true,
      child: ListView.builder(
        controller: controller,
        primary: false,
        padding: const EdgeInsets.fromLTRB(14, 12, 22, 12),
        itemCount: items.length,
        itemBuilder: (_, idx) {
          final item = items[idx];
          if (item.isThinking) {
            return _ThinkingBlock(
              lines: item.think!,
              collapsed: collapsed.contains(item.startIndex),
              // The trailing block while a run is going is the one streaming.
              active: running && idx == items.length - 1,
              onToggle: () => onToggleBlock(item.startIndex),
            );
          }
          return _lineWidget(item.line!);
        },
      ),
    );
  }

  static Widget _lineWidget(ConsoleLine l) {
    final showTs = !_streamed.contains(l.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          children: [
            if (showTs)
              TextSpan(
                text: '${l.timestamp}  ',
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  color: Color(0xFF4B5563),
                ),
              ),
            TextSpan(
              text: l.text,
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12.5,
                height: 1.4,
                color: l.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A collapsible block of the model's internal chain-of-thought.
class _ThinkingBlock extends StatelessWidget {
  const _ThinkingBlock({
    required this.lines,
    required this.collapsed,
    required this.active,
    required this.onToggle,
  });

  final List<ConsoleLine> lines;
  final bool collapsed;
  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    const dim = Color(0xFF7C8598);
    final count = lines.where((l) => l.text.trim().isNotEmpty).length;
    final label = active
        ? 'Thinking…'
        : 'Internal thinking · $count line${count == 1 ? '' : 's'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      collapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 16,
                      color: dim,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 12,
                        color: dim,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 9,
                        height: 9,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: dim,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in lines)
                    Text(
                      l.text,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ApprovalPanel extends StatefulWidget {
  const _ApprovalPanel({
    required this.state,
    required this.onToggleEdit,
    required this.onToggleCommand,
    required this.onApply,
    required this.onRevise,
    required this.onEditContent,
    required this.onEditCommand,
  });

  final ImplRunState state;
  final ValueChanged<int> onToggleEdit;
  final ValueChanged<int> onToggleCommand;
  final VoidCallback onApply;
  final ValueChanged<String> onRevise;
  final void Function(int index, String content) onEditContent;
  final void Function(int index, String raw, String human) onEditCommand;

  @override
  State<_ApprovalPanel> createState() => _ApprovalPanelState();
}

class _ApprovalPanelState extends State<_ApprovalPanel> {
  final _revise = TextEditingController();

  @override
  void dispose() {
    _revise.dispose();
    super.dispose();
  }

  void _submitRevise() {
    final text = _revise.text.trim();
    if (text.isEmpty) return;
    widget.onRevise(text);
    _revise.clear();
  }

  /// Opens a full editor on a proposed file so the user can hand-tweak the
  /// content before applying.
  Future<void> _editContent(int index) async {
    final edit = widget.state.plan!.edits[index];
    final controller = TextEditingController(text: edit.newContent);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F0F10),
        insetPadding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                child: Row(children: [
                  const Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFFE8A04C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Edit ${edit.path}',
                        style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 13,
                            color: Color(0xFFE5E5E7))),
                  ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFFE5E5E7)),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF0A0A0B),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2C2C2E)),
                      ),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Spacer(),
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(controller.text),
                    child: const Text('Save changes'),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != null) widget.onEditContent(index, saved);
  }

  /// Hand-edit a proposed command's text before it runs.
  Future<void> _editCommand(int index) async {
    final cmd = widget.state.plan!.commands[index];
    final rawC = TextEditingController(text: cmd.raw);
    final humanC = TextEditingController(text: cmd.human);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141416),
        title: const Text('Edit command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: rawC,
              autofocus: true,
              style: const TextStyle(
                  fontFamily: 'Menlo', fontSize: 12.5, color: Color(0xFFE5E5E7)),
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: 'e.g. flutter test test/foo_test.dart',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: humanC,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFE5E5E7)),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved == true) {
      widget.onEditCommand(index, rawC.text, humanC.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final plan = state.plan!;
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F10),
        border: Border(top: BorderSide(color: Color(0xFF1C1C1E))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              'Review the plan — approve, skip, or edit each step, or tell the '
              'AI what to change.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (var i = 0; i < plan.edits.length; i++)
                  _EditCard(
                    edit: plan.edits[i],
                    skipped: state.skippedEdits.contains(i),
                    onToggle: () => widget.onToggleEdit(i),
                    onEdit: () => _editContent(i),
                  ),
                for (var i = 0; i < plan.commands.length; i++)
                  _CommandCard(
                    command: plan.commands[i],
                    skipped: state.skippedCommands.contains(i),
                    onToggle: () => widget.onToggleCommand(i),
                    onEdit: () => _editCommand(i),
                  ),
              ],
            ),
          ),
          // Steer the AI: type an instruction and it re-plans.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _revise,
                  onSubmitted: (_) => _submitRevise(),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFE5E5E7)),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Tell the AI what to change…',
                    hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5),
                    filled: true,
                    fillColor: Color(0xFF0A0A0B),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2C2C2E)),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _submitRevise,
                icon: const Icon(Icons.autorenew, size: 16),
                label: const Text('Revise'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '${state.approvedEditCount} edit(s), '
                  '${state.approvedCommandCount} command(s) approved',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: widget.onApply,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Apply & Run'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({
    required this.edit,
    required this.skipped,
    required this.onToggle,
    this.onEdit,
  });
  final ProposedEdit edit;
  final bool skipped;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141416),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          edit.isNewFile ? Icons.note_add_outlined : Icons.edit_outlined,
          size: 18,
          color: skipped ? const Color(0xFF6B7280) : const Color(0xFFE8A04C),
        ),
        title: Text(
          edit.path,
          style: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 12.5,
            decoration: skipped ? TextDecoration.lineThrough : null,
            color: skipped ? const Color(0xFF6B7280) : const Color(0xFFE5E5E7),
          ),
        ),
        subtitle: edit.rationale.isEmpty
            ? null
            : Text(
                edit.rationale,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
        trailing: _SkipToggle(skipped: skipped, onToggle: onToggle),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (onEdit != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('Edit content'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE8A04C),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          DiffView(oldText: edit.oldContent, newText: edit.newContent),
        ],
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.command,
    required this.skipped,
    required this.onToggle,
    this.onEdit,
  });
  final ProposedCommand command;
  final bool skipped;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141416),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.terminal,
          size: 18,
          color: skipped ? const Color(0xFF6B7280) : const Color(0xFF64B5F6),
        ),
        title: Text(
          command.human,
          style: TextStyle(
            fontSize: 12.5,
            decoration: skipped ? TextDecoration.lineThrough : null,
            color: skipped ? const Color(0xFF6B7280) : const Color(0xFFE5E5E7),
          ),
        ),
        subtitle: Text(
          '\$ ${command.raw}',
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 11.5,
            color: Color(0xFF9CA3AF),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_note, size: 16),
                color: const Color(0xFFE8A04C),
                tooltip: 'Edit command',
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
            _SkipToggle(skipped: skipped, onToggle: onToggle),
          ],
        ),
      ),
    );
  }
}

class _SkipToggle extends StatelessWidget {
  const _SkipToggle({required this.skipped, required this.onToggle});
  final bool skipped;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onToggle,
      child: Text(
        skipped ? 'Skipped' : 'Approved',
        style: TextStyle(
          fontSize: 12,
          color: skipped ? const Color(0xFF6B7280) : const Color(0xFF81C784),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.state, required this.onUndo});
  final ImplRunState state;
  final ValueChanged<String> onUndo;

  static const _steps = [
    ('Plan', [RunPhase.planning, RunPhase.awaitingApproval]),
    ('Edit', [RunPhase.applying]),
    ('Run', [RunPhase.running]),
    ('Verify', [RunPhase.verifying]),
  ];

  int get _phaseOrder => switch (state.phase) {
    RunPhase.idle || RunPhase.planning => 0,
    RunPhase.awaitingApproval => 1,
    RunPhase.applying => 2,
    RunPhase.running => 3,
    RunPhase.verifying => 4,
    _ => 5,
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'STEPS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _steps.length; i++) _stepRow(_steps[i].$1, i),
        if (state.appliedEditPaths.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'APPLIED EDITS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          for (final path in state.appliedEditPaths)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      path,
                      style: const TextStyle(
                        fontFamily: 'Menlo',
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => onUndo(path),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Text(
                        'undo',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFE8A04C),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (state.verifications.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'VERIFY  ${state.verifications.where((v) => v.passed).length}/'
            '${state.verifications.length}',
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          for (final v in state.verifications)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    v.passed ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 13,
                    color: v.passed
                        ? const Color(0xFF81C784)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      v.requirement,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _stepRow(String label, int index) {
    final done =
        _phaseOrder > index + 1 ||
        (state.phase.isTerminal && state.phase == RunPhase.done);
    final active = _phaseOrder == index + 1 && !state.phase.isTerminal;
    final color = done
        ? const Color(0xFF81C784)
        : active
        ? const Color(0xFFE8A04C)
        : const Color(0xFF4B5563);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle
                : active
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar({
    required this.alreadyShipped,
    required this.canFix,
    required this.onShip,
    required this.onFix,
    required this.onClose,
  });
  final bool alreadyShipped;
  final bool canFix;
  final VoidCallback onShip;
  final VoidCallback onFix;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final trouble = canFix;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: trouble ? const Color(0x22FF453A) : const Color(0x2281C784),
        border: const Border(top: BorderSide(color: Color(0xFF1C1C1E))),
      ),
      child: Row(
        children: [
          Icon(
            trouble ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: trouble ? const Color(0xFFFF453A) : const Color(0xFF81C784),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              trouble
                  ? 'Run finished with issues. Let the AI fix them?'
                  : 'Run complete. Mark this feature as shipped?',
              style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7)),
            ),
          ),
          if (trouble) ...[
            FilledButton.icon(
              onPressed: onFix,
              icon: const Icon(Icons.healing_outlined, size: 16),
              label: const Text('Fix it'),
            ),
            const SizedBox(width: 8),
          ],
          TextButton(onPressed: onClose, child: const Text('Close')),
          const SizedBox(width: 8),
          if (trouble)
            OutlinedButton.icon(
              onPressed: onShip,
              icon: const Icon(Icons.local_shipping_outlined, size: 16),
              label: const Text('Ship anyway'),
            )
          else
            FilledButton.icon(
              onPressed: onShip,
              icon: const Icon(Icons.local_shipping_outlined, size: 16),
              label: const Text('Mark shipped'),
            ),
        ],
      ),
    );
  }
}

class _FailedBar extends StatelessWidget {
  const _FailedBar({
    required this.error,
    required this.stopped,
    required this.onRetry,
    required this.onClose,
  });
  final String? error;
  final bool stopped;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = stopped ? const Color(0xFF9E9E9E) : const Color(0xFFFF453A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        border: const Border(top: BorderSide(color: Color(0xFF1C1C1E))),
      ),
      child: Row(
        children: [
          Icon(
            stopped ? Icons.stop_circle_outlined : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stopped ? 'Stopped.' : (error ?? 'The run failed.'),
              style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7)),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(width: 8),
          TextButton(onPressed: onClose, child: const Text('Close')),
        ],
      ),
    );
  }
}
