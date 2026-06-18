import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/watch/ci_correlator.dart';
import '../../services/watch/failure_signal_engine.dart';
import '../../services/watch/git_activity_provider.dart';
import 'watch_data_notifier.dart';

class EngineerDetailScreen extends ConsumerWidget {
  const EngineerDetailScreen({super.key, required this.engineerHandle});
  final String engineerHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(watchDataProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(engineerHandle),
      ),
      body: dataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8A04C)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _buildBody(context, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WatchData data) {
    final usage = data.usage
        .where((u) => u.engineerHandle == engineerHandle)
        .firstOrNull;
    final correlation = data.correlations
        .where((c) => c.engineerHandle == engineerHandle)
        .firstOrNull;
    final signals = data.signalsFor(engineerHandle);

    if (usage == null) {
      return const Center(
        child: Text(
          'No data for this engineer.',
          style: TextStyle(color: Color(0xFF6B7280), fontFamily: 'Menlo'),
        ),
      );
    }

    final passRate = correlation?.overallPassRate30d ?? 0;
    final agentRate = correlation?.gitActivity.agentAttributionRate ?? 0;
    final prsMerged = correlation?.gitActivity.prsMerged ?? 0;
    final commits = correlation?.gitActivity.commits ?? const <GitCommit>[];
    final revertCount =
        commits.where((c) => c.message.toLowerCase().startsWith('revert')).length;
    final daily = correlation?.dailyCorrelations ?? const <DailyCorrelation>[];
    final sortedDaily = [...daily]..sort((a, b) => a.date.compareTo(b.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryRow(
          spend: usage.totalCostUSD30d,
          passRate: passRate,
          agentRate: agentRate,
          prsMerged: prsMerged,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('SPEND (30d)'),
        const SizedBox(height: 8),
        _SpendChart(daily: sortedDaily),
        const SizedBox(height: 16),
        const _SectionLabel('GIT ACTIVITY'),
        const SizedBox(height: 8),
        _GitStatsRow(
          commits: commits.length,
          reverts: revertCount,
          prsMerged: prsMerged,
          agentRate: agentRate,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('ACTIVE SIGNALS'),
        const SizedBox(height: 8),
        if (signals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No active signals',
              style: TextStyle(color: Color(0xFF6B7280), fontFamily: 'Menlo'),
            ),
          )
        else
          ...signals.map((s) => _SignalRow(signal: s)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.spend,
    required this.passRate,
    required this.agentRate,
    required this.prsMerged,
  });

  final double spend;
  final double passRate;
  final double agentRate;
  final int prsMerged;

  @override
  Widget build(BuildContext context) {
    final passColor = passRate > 0.7
        ? const Color(0xFF22C55E)
        : passRate > 0.3
            ? const Color(0xFFE8A04C)
            : const Color(0xFFEF4444);
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
          _Stat(label: '30d spend', value: '\$${spend.toStringAsFixed(0)}', color: const Color(0xFFE8A04C)),
          _Stat(label: 'CI pass', value: '${(passRate * 100).toStringAsFixed(0)}%', color: passColor),
          _Stat(label: 'AI', value: '${(agentRate * 100).toStringAsFixed(0)}%', color: const Color(0xFF9CA3AF)),
          _Stat(label: 'PRs', value: '$prsMerged', color: const Color(0xFF9CA3AF)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
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

class _SpendChart extends StatelessWidget {
  const _SpendChart({required this.daily});
  final List<DailyCorrelation> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: const Center(
          child: Text(
            'No data yet',
            style: TextStyle(color: Color(0xFF6B7280), fontFamily: 'Menlo'),
          ),
        ),
      );
    }
    return Container(
      height: 180,
      padding: const EdgeInsets.only(top: 8, right: 8, bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: BarChart(
        BarChartData(
          barGroups: daily.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final color = d.passRate > 0.7
                ? const Color(0xFF22C55E)
                : d.passRate > 0.3
                    ? const Color(0xFFE8A04C)
                    : const Color(0xFFEF4444);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: d.tokenSpend,
                  color: color,
                  width: 6,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 7,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < daily.length) {
                    final d = daily[idx].date;
                    return Text(
                      '${d.month}/${d.day}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF6B7280),
                        fontFamily: 'Menlo',
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '\$${value.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6B7280),
                    fontFamily: 'Menlo',
                  ),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) => const FlLine(
                color: Color(0xFF2C2C2E), strokeWidth: 0.5),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          backgroundColor: const Color(0xFF0F0F10),
        ),
      ),
    );
  }
}

class _GitStatsRow extends StatelessWidget {
  const _GitStatsRow({
    required this.commits,
    required this.reverts,
    required this.prsMerged,
    required this.agentRate,
  });

  final int commits;
  final int reverts;
  final int prsMerged;
  final double agentRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _GitChip(label: 'COMMITS', value: '$commits'),
        const SizedBox(width: 8),
        _GitChip(label: 'REVERTS', value: '$reverts'),
        const SizedBox(width: 8),
        _GitChip(label: 'PRs MERGED', value: '$prsMerged'),
        const SizedBox(width: 8),
        _GitChip(label: 'AI', value: '${(agentRate * 100).toStringAsFixed(0)}%'),
      ],
    );
  }
}

class _GitChip extends StatelessWidget {
  const _GitChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFE5E5E7),
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
                fontSize: 9,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ),
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
                  maxLines: 1,
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
  }
}