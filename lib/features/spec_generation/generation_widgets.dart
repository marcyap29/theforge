import 'dart:async';

import 'package:flutter/material.dart';

// ── Phase Bar ─────────────────────────────────────────────────────────────────

/// A compact phase bar for generation screens. Interview is always done when
/// these screens are shown. [currentStep] is 'spec' or 'worksheet'.
/// [isDone] marks the current step as complete (green check).
class GenerationPhaseBar extends StatefulWidget {
  const GenerationPhaseBar({
    super.key,
    required this.currentStep,
    required this.isDone,
  });

  final String currentStep;
  final bool isDone;

  @override
  State<GenerationPhaseBar> createState() => _GenerationPhaseBarState();
}

class _GenerationPhaseBarState extends State<GenerationPhaseBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseOpacity = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSpec = widget.currentStep == 'spec';
    final specDone = widget.isDone || !isSpec;
    final worksheetDone = !isSpec && widget.isDone;
    final specCurrent = isSpec && !widget.isDone;
    final worksheetCurrent = !isSpec && !widget.isDone;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F10),
        border:
            Border(bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhaseDot(
              label: 'Interview',
              isDone: true,
              isCurrent: false,
              pulseOpacity: _pulseOpacity),
          const _PhaseConnector(done: true),
          _PhaseDot(
              label: 'Spec',
              isDone: specDone,
              isCurrent: specCurrent,
              pulseOpacity: _pulseOpacity),
          _PhaseConnector(done: specDone),
          _PhaseDot(
              label: 'Worksheet',
              isDone: worksheetDone,
              isCurrent: worksheetCurrent,
              pulseOpacity: _pulseOpacity),
          _PhaseConnector(done: worksheetDone),
          _PhaseDot(
              label: 'Ready',
              isDone: worksheetDone,
              isCurrent: false,
              pulseOpacity: _pulseOpacity),
        ],
      ),
    );
  }
}

class _PhaseDot extends StatelessWidget {
  const _PhaseDot({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.pulseOpacity,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final Animation<double> pulseOpacity;

  @override
  Widget build(BuildContext context) {
    Widget dot;
    Color labelColor;

    if (isDone) {
      dot = const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20);
      labelColor = const Color(0xFF22C55E);
    } else if (isCurrent) {
      dot = FadeTransition(
        opacity: pulseOpacity,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8A04C),
            ),
            child: Center(
              child: Icon(Icons.circle, color: Color(0xFF0F0F10), size: 8),
            ),
          ),
        ),
      );
      labelColor = const Color(0xFFE8A04C);
    } else {
      dot = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF3D4452), width: 1.5),
        ),
      );
      labelColor = const Color(0xFF4B5563);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'Menlo',
            letterSpacing: 0.4,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

class _PhaseConnector extends StatelessWidget {
  const _PhaseConnector({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 19),
        child: Container(
          height: 1.5,
          color: done ? const Color(0xFF22C55E) : const Color(0xFF2C2C2E),
        ),
      ),
    );
  }
}

// ── Artifact Info Card ────────────────────────────────────────────────────────

class ArtifactInfoCard extends StatelessWidget {
  const ArtifactInfoCard({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined,
                  size: 12, color: Color(0xFFE8A04C)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: Color(0xFFE5E5E7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'Menlo',
              height: 1.4,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tip Rotator ───────────────────────────────────────────────────────────────

class TipRotator extends StatefulWidget {
  const TipRotator({super.key, required this.tips});
  final List<String> tips;

  @override
  State<TipRotator> createState() => _TipRotatorState();
}

class _TipRotatorState extends State<TipRotator> {
  int _idx = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _idx = (_idx + 1) % widget.tips.length);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey(_idx),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline,
                size: 14, color: Color(0xFFE8A04C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.tips[_idx],
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Menlo',
                  height: 1.5,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tip Content ───────────────────────────────────────────────────────────────

const specGenTips = <String>[
  'Your Locked Spec is immutable. If scope changes after this, run a v2 interview — never edit the spec directly.',
  'The /goal text is ready to paste into Claude Code. It translates your Completion Criteria into a checkable executor harness.',
  'Every Accepted Decision records what was considered and why it was rejected. Your executor won\'t re-litigate settled questions.',
  'Open Flags are conscious deferrals. The executor picks the recommended default — or you can override before the run starts.',
  'Your Bullet Handoff is the v2 resume point. Every deferred feature lands there as a v2 seed, not lost, not built.',
  'The Handoff Package JSON is what The Forge MCP server reads to route your project to the right executor agent.',
  'Hard Constraints in your spec are non-negotiables. Write them tightly — a vague constraint is an invitation to drift.',
];

const worksheetTips = <String>[
  'Complete every step before starting the executor run. A missing environment variable will halt the build mid-flight.',
  'Free tier limits are listed for every service. V1 ships at zero cost on most stacks.',
  'The Environment Variables table is exactly what you paste into your executor harness. One copy, zero guesswork.',
  'Screenshot API keys as you generate them — most consoles only show them once.',
  'Once the worksheet is complete, your executor can run uninterrupted from spec to working app.',
  'External services that aren\'t core to your V1 demo were stripped by the funnel. Your worksheet is lean by design.',
];
