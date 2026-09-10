import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  String get _featureId => widget.brief.featureId;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(implRunProvider(_featureId).notifier).start(widget.brief));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(implRunProvider(_featureId));
    final notifier = ref.read(implRunProvider(_featureId).notifier);

    ref.listen(implRunProvider(_featureId), (prev, next) {
      if ((prev?.console.length ?? 0) != next.console.length) _autoScroll();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      appBar: AppBar(
        title: Text('Build: ${widget.brief.featureTitle}',
            style: const TextStyle(fontSize: 15)),
        actions: [
          _PhaseChip(phase: state.phase),
          const SizedBox(width: 8),
          if (!state.phase.isTerminal && state.phase != RunPhase.idle)
            TextButton.icon(
              onPressed: notifier.stop,
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('Stop'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF453A)),
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
                Expanded(child: _Console(lines: state.console, controller: _scroll)),
                if (state.phase == RunPhase.awaitingApproval && state.plan != null)
                  _ApprovalPanel(
                    state: state,
                    onToggleEdit: notifier.toggleEdit,
                    onToggleCommand: notifier.toggleCommand,
                    onApply: notifier.applyAndRun,
                  ),
                if (state.phase == RunPhase.done)
                  _DoneBar(
                    alreadyShipped: state.featureShipped,
                    onShip: () {
                      notifier.markFeatureShipped();
                      Navigator.of(context).pop(true);
                    },
                    onClose: () => Navigator.of(context).pop(state.featureShipped),
                  ),
                if (state.phase == RunPhase.failed)
                  _FailedBar(
                    error: state.error,
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
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
      ]),
    );
  }
}

class _Console extends StatelessWidget {
  const _Console({required this.lines, required this.controller});
  final List<ConsoleLine> lines;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      itemCount: lines.length,
      itemBuilder: (_, i) {
        final l = lines[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: RichText(
            text: TextSpan(children: [
              TextSpan(
                text: '${l.timestamp}  ',
                style: const TextStyle(
                    fontFamily: 'Menlo', fontSize: 11, color: Color(0xFF4B5563)),
              ),
              TextSpan(
                text: l.text,
                style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12.5,
                    height: 1.4,
                    color: l.color),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _ApprovalPanel extends StatelessWidget {
  const _ApprovalPanel({
    required this.state,
    required this.onToggleEdit,
    required this.onToggleCommand,
    required this.onApply,
  });

  final ImplRunState state;
  final ValueChanged<int> onToggleEdit;
  final ValueChanged<int> onToggleCommand;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    return Container(
      constraints: const BoxConstraints(maxHeight: 380),
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
              'Review the plan — approve or skip each step, then apply.',
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
                    onToggle: () => onToggleEdit(i),
                  ),
                for (var i = 0; i < plan.commands.length; i++)
                  _CommandCard(
                    command: plan.commands[i],
                    skipped: state.skippedCommands.contains(i),
                    onToggle: () => onToggleCommand(i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '${state.approvedEditCount} edit(s), '
                  '${state.approvedCommandCount} command(s) approved',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onApply,
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
  const _EditCard(
      {required this.edit, required this.skipped, required this.onToggle});
  final ProposedEdit edit;
  final bool skipped;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141416),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(edit.isNewFile ? Icons.note_add_outlined : Icons.edit_outlined,
            size: 18, color: skipped ? const Color(0xFF6B7280) : const Color(0xFFE8A04C)),
        title: Text(edit.path,
            style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12.5,
                decoration: skipped ? TextDecoration.lineThrough : null,
                color: skipped ? const Color(0xFF6B7280) : const Color(0xFFE5E5E7))),
        subtitle: edit.rationale.isEmpty
            ? null
            : Text(edit.rationale,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
        trailing: _SkipToggle(skipped: skipped, onToggle: onToggle),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [DiffView(oldText: edit.oldContent, newText: edit.newContent)],
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard(
      {required this.command, required this.skipped, required this.onToggle});
  final ProposedCommand command;
  final bool skipped;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141416),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.terminal,
            size: 18,
            color: skipped ? const Color(0xFF6B7280) : const Color(0xFF64B5F6)),
        title: Text(command.human,
            style: TextStyle(
                fontSize: 12.5,
                decoration: skipped ? TextDecoration.lineThrough : null,
                color: skipped ? const Color(0xFF6B7280) : const Color(0xFFE5E5E7))),
        subtitle: Text('\$ ${command.raw}',
            style: const TextStyle(
                fontFamily: 'Menlo', fontSize: 11.5, color: Color(0xFF9CA3AF))),
        trailing: _SkipToggle(skipped: skipped, onToggle: onToggle),
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
      child: Text(skipped ? 'Skipped' : 'Approved',
          style: TextStyle(
              fontSize: 12,
              color: skipped ? const Color(0xFF6B7280) : const Color(0xFF81C784))),
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
        const Text('STEPS',
            style: TextStyle(
                fontSize: 11, letterSpacing: 1, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        for (var i = 0; i < _steps.length; i++)
          _stepRow(_steps[i].$1, i),
        if (state.appliedEditPaths.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('APPLIED EDITS',
              style: TextStyle(
                  fontSize: 11, letterSpacing: 1, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          for (final path in state.appliedEditPaths)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(
                  child: Text(path,
                      style: const TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 11,
                          color: Color(0xFF9CA3AF)),
                      overflow: TextOverflow.ellipsis),
                ),
                InkWell(
                  onTap: () => onUndo(path),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Text('undo',
                        style: TextStyle(fontSize: 11, color: Color(0xFFE8A04C))),
                  ),
                ),
              ]),
            ),
        ],
        if (state.verifications.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('VERIFY  ${state.verifications.where((v) => v.passed).length}/'
              '${state.verifications.length}',
              style: const TextStyle(
                  fontSize: 11, letterSpacing: 1, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          for (final v in state.verifications)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(v.passed ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 13,
                    color: v.passed
                        ? const Color(0xFF81C784)
                        : const Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(v.requirement,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF))),
                ),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _stepRow(String label, int index) {
    final done = _phaseOrder > index + 1 ||
        (state.phase.isTerminal && state.phase == RunPhase.done);
    final active = _phaseOrder == index + 1 && !state.phase.isTerminal;
    final color = done
        ? const Color(0xFF81C784)
        : active
            ? const Color(0xFFE8A04C)
            : const Color(0xFF4B5563);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(
            done
                ? Icons.check_circle
                : active
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
            size: 15,
            color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: color)),
      ]),
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar(
      {required this.alreadyShipped, required this.onShip, required this.onClose});
  final bool alreadyShipped;
  final VoidCallback onShip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0x2281C784),
        border: Border(top: BorderSide(color: Color(0xFF1C1C1E))),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline,
            size: 18, color: Color(0xFF81C784)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Run complete. Mark this feature as shipped?',
              style: TextStyle(fontSize: 13, color: Color(0xFFE5E5E7))),
        ),
        TextButton(onPressed: onClose, child: const Text('Close')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onShip,
          icon: const Icon(Icons.local_shipping_outlined, size: 16),
          label: const Text('Mark shipped'),
        ),
      ]),
    );
  }
}

class _FailedBar extends StatelessWidget {
  const _FailedBar({required this.error, required this.onClose});
  final String? error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0x22FF453A),
        border: Border(top: BorderSide(color: Color(0xFF1C1C1E))),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, size: 18, color: Color(0xFFFF453A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(error ?? 'The run failed.',
              style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7))),
        ),
        TextButton(onPressed: onClose, child: const Text('Close')),
      ]),
    );
  }
}
