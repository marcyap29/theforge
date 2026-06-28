import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/watch/failure_signal_engine.dart';
import '../../services/watch/project_status_aggregator.dart';

class WorkspaceHealthScreen extends ConsumerWidget {
  const WorkspaceHealthScreen({
    super.key,
    required this.status,
    required this.workspaceSignals,
  });

  final WorkspaceStatus status;
  final List<FailureSignal> workspaceSignals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Workspace Health'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _VelocityCard(status: status),
          const SizedBox(height: 16),
          _LastCommitRow(status: status),
          const SizedBox(height: 16),
          _CIStatsRow(status: status),
          const SizedBox(height: 16),
          const _SectionLabel('WORKSPACE SIGNALS'),
          const SizedBox(height: 8),
          if (workspaceSignals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No workspace alerts',
                style: TextStyle(color: Color(0xFF6B7280), fontFamily: 'Menlo'),
              ),
            )
          else
            ...workspaceSignals.map((s) => _SignalRow(signal: s)),
        ],
      ),
    );
  }
}

class _VelocityCard extends StatelessWidget {
  const _VelocityCard({required this.status});
  final WorkspaceStatus status;

  @override
  Widget build(BuildContext context) {
    final trendLabel = switch (status.velocityTrend) {
      VelocityTrend.improving => 'IMPROVING',
      VelocityTrend.stable => 'STABLE',
      VelocityTrend.declining => 'DECLINING',
      VelocityTrend.stalled => 'STALLED',
    };
    final trendColor = switch (status.velocityTrend) {
      VelocityTrend.improving => const Color(0xFF22C55E),
      VelocityTrend.stable => const Color(0xFFE5E5E7),
      VelocityTrend.declining => const Color(0xFFE8A04C),
      VelocityTrend.stalled => const Color(0xFFEF4444),
    };
    final changeColor = status.commitChangePercent >= 0
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
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
          Text(
            trendLabel,
            style: TextStyle(
              color: trendColor,
              fontSize: 22,
              fontFamily: 'Menlo',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat('Commits 7d', '${status.commitsLast7d}'),
              _Stat('Prior 7d', '${status.commitsPrior7d}'),
              _Stat(
                'Change',
                '${status.commitChangePercent >= 0 ? '+' : ''}${status.commitChangePercent.toStringAsFixed(0)}%',
                color: changeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color ?? const Color(0xFFE5E5E7),
            fontSize: 14,
            fontFamily: 'Menlo',
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 10,
            fontFamily: 'Menlo',
          ),
        ),
      ],
    );
  }
}

class _LastCommitRow extends StatelessWidget {
  const _LastCommitRow({required this.status});
  final WorkspaceStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.lastCommitAt == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: const Text(
          'No commits recorded',
          style: TextStyle(color: Color(0xFF6B7280), fontFamily: 'Menlo', fontSize: 12),
        ),
      );
    }
    final dateStr = _formatDate(status.lastCommitAt!);
    final stalledStr = status.stalledDays >= 999
        ? 'never'
        : '${status.stalledDays}d ago';
    final text = 'Last commit: $dateStr ($stalledStr)';
    final color = status.isStalled ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontFamily: 'Menlo', fontSize: 12),
      ),
    );
  }
}

class _CIStatsRow extends StatelessWidget {
  const _CIStatsRow({required this.status});
  final WorkspaceStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('Total CI runs', '${status.totalCIRuns30d}'),
          _Stat(
            'Pass rate',
            '${(status.ciPassRate30d * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 11,
        fontFamily: 'Menlo',
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});
  final FailureSignal signal;

  @override
  Widget build(BuildContext context) {
    final iconData = signal.severity == SignalSeverity.critical
        ? Icons.error
        : signal.severity == SignalSeverity.warning
            ? Icons.warning_amber
            : Icons.info_outline;
    final iconColor = signal.severity == SignalSeverity.critical
        ? const Color(0xFFEF4444)
        : signal.severity == SignalSeverity.warning
            ? const Color(0xFFE8A04C)
            : const Color(0xFF6B7280);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _labelFor(signal.type),
                  style: const TextStyle(
                    color: Color(0xFFE5E5E7),
                    fontSize: 12,
                    fontFamily: 'Menlo',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signal.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontFamily: 'Menlo',
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

String _labelFor(SignalType type) {
  switch (type) {
    case SignalType.highTokenToFailRatio:
      return 'High token-to-fail ratio';
    case SignalType.loopDetected:
      return 'Loop detected';
    case SignalType.churnDetected:
      return 'Churn detected';
    case SignalType.spendThreshold:
      return 'Spend threshold';
    case SignalType.runawayDay:
      return 'Runaway day';
    case SignalType.stalledWorkspace:
      return 'Stalled workspace';
    case SignalType.specDriftExceeded:
      return 'Spec drift';
  }
}

String _formatDate(DateTime d) {
  final y = d.year.toString();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}