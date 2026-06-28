import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/watch/alert_engine.dart';
import '../../services/watch/alert_log_notifier.dart';
import '../../services/watch/failure_signal_engine.dart';
import '../../services/watch/usage_provider.dart';
import 'alert_log_screen.dart';
import 'engineer_detail_screen.dart';
import 'watch_data_notifier.dart';
import 'workspace_health_screen.dart';

class WatchDashboardScreen extends ConsumerWidget {
  const WatchDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(watchDataProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Watch Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.read(watchDataProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Alerts',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AlertLogScreen(),
              ),
            ),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8A04C)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _buildBody(context, ref, data),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, WatchData data) {
    final totalSpend = data.usage.fold<double>(0, (s, u) => s + u.totalCostUSD30d);
    final activeAlerts =
        ref.watch(alertLogProvider).valueOrNull ?? const <AlertEntry>[];
    final activeCount = activeAlerts.where((a) => !a.dismissed).length;
    final criticalCount = activeAlerts
        .where((a) => !a.dismissed && a.severity == SignalSeverity.critical)
        .length;
    final sortedUsage = [...data.usage]
      ..sort((a, b) => b.totalCostUSD30d.compareTo(a.totalCostUSD30d));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WorkspaceStrip(
          totalSpend: totalSpend,
          activeAlerts: activeCount,
          gitConnected: data.hasGitHubConfig,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => WorkspaceHealthScreen(
                status: data.signalResult.workspaceStatus,
                workspaceSignals: data.workspaceSignals,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (criticalCount > 0)
          _CriticalAlertBanner(
            count: criticalCount,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AlertLogScreen(),
              ),
            ),
          ),
        const SizedBox(height: 16),
        const _SectionHeader('ENGINEERS'),
        const SizedBox(height: 8),
        if (sortedUsage.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No engineer data yet.',
                style: TextStyle(color: Color(0xFF6B7280), fontFamily: 'Menlo'),
              ),
            ),
          )
        else
          ...sortedUsage.map((u) => _EngineerCard(
                usage: u,
                passRate: _passRateFor(data, u.engineerHandle),
                firstSignal: data.signalsFor(u.engineerHandle).firstOrNull,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        EngineerDetailScreen(engineerHandle: u.engineerHandle),
                  ),
                ),
              )),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => WorkspaceHealthScreen(
                status: data.signalResult.workspaceStatus,
                workspaceSignals: data.workspaceSignals,
              ),
            ),
          ),
          child: const Text('VIEW WORKSPACE HEALTH →'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pushNamed('/watch/briefing'),
          child: const Text('WEEKLY BRIEFING →'),
        ),
      ],
    );
  }
}

double _passRateFor(WatchData data, String handle) {
  final c = data.correlations
      .where((c) => c.engineerHandle == handle)
      .firstOrNull;
  if (c == null) return 0;
  return c.overallPassRate30d;
}

class _WorkspaceStrip extends StatelessWidget {
  const _WorkspaceStrip({
    required this.totalSpend,
    required this.activeAlerts,
    required this.gitConnected,
    required this.onTap,
  });

  final double totalSpend;
  final int activeAlerts;
  final bool gitConnected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // macOS Flutter desktop requires Material ancestor for InkWell ink effect
    // (BUG-UI-001 — Scaffold-level Material is insufficient on macOS).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${totalSpend.toStringAsFixed(0)} / 30d',
                  style: const TextStyle(
                    color: Color(0xFFE8A04C),
                    fontSize: 18,
                    fontFamily: 'Menlo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeAlerts active alert${activeAlerts == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontFamily: 'Menlo',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  gitConnected ? Icons.check_circle : Icons.cloud_off,
                  color: gitConnected
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF6B7280),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  gitConnected ? 'Git connected' : 'Git not configured',
                  style: TextStyle(
                    color: gitConnected
                        ? const Color(0xFF22C55E)
                        : const Color(0xFF6B7280),
                    fontSize: 11,
                    fontFamily: 'Menlo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _CriticalAlertBanner extends StatelessWidget {
  const _CriticalAlertBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x33EF4444),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFEF4444)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning, color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$count critical alert${count == 1 ? '' : 's'} — tap to view',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontFamily: 'Menlo',
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFEF4444), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
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

class _EngineerCard extends StatelessWidget {
  const _EngineerCard({
    required this.usage,
    required this.passRate,
    required this.firstSignal,
    required this.onTap,
  });

  final EngineerUsage usage;
  final double passRate;
  final FailureSignal? firstSignal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDemo = usage.providerName == 'demo';
    final passColor = passRate > 0.7
        ? const Color(0xFF22C55E)
        : passRate > 0.3
            ? const Color(0xFFE8A04C)
            : const Color(0xFFEF4444);
    final signalColor = firstSignal == null
        ? null
        : firstSignal!.severity == SignalSeverity.critical
            ? const Color(0xFFEF4444)
            : firstSignal!.severity == SignalSeverity.warning
                ? const Color(0xFFE8A04C)
                : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          usage.engineerHandle,
                          style: const TextStyle(
                            color: Color(0xFFE5E5E7),
                            fontSize: 14,
                            fontFamily: 'Menlo',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDemo
                                ? const Color(0x339CA3AF)
                                : const Color(0x33E8A04C),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            usage.providerName,
                            style: TextStyle(
                              color: isDemo
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFFE8A04C),
                              fontSize: 9,
                              fontFamily: 'Menlo',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (firstSignal != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        firstSignal!.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: signalColor,
                          fontSize: 11,
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${usage.totalCostUSD30d.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFE5E5E7),
                      fontSize: 16,
                      fontFamily: 'Menlo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CI: ${(passRate * 100).toStringAsFixed(0)}% pass',
                    style: TextStyle(
                      color: passColor,
                      fontSize: 11,
                      fontFamily: 'Menlo',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}