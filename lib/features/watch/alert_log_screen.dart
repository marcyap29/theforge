import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/watch/alert_engine.dart';
import '../../services/watch/alert_log_notifier.dart';
import '../../services/watch/failure_signal_engine.dart';

class AlertLogScreen extends ConsumerWidget {
  const AlertLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(alertLogProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Alert Log'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(alertLogProvider.notifier).clearDismissed(),
            child: const Text('Clear Dismissed'),
          ),
        ],
      ),
      body: logAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE8A04C)),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (log) => _buildBody(context, ref, log),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, List<AlertEntry> log) {
    if (log.isEmpty) {
      return const Center(
        child: Text(
          'No alerts',
          style: TextStyle(color: Color(0xFF6B7280), fontFamily: 'Menlo'),
        ),
      );
    }
    final active = log.where((e) => !e.dismissed).toList();
    final dismissed = log.where((e) => e.dismissed).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...active.map((e) => _AlertRow(
              entry: e,
              onDismiss: () => ref
                  .read(alertLogProvider.notifier)
                  .dismissAlert(e.id),
            )),
        if (dismissed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              '— ${dismissed.length} dismissed —',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 11,
                fontFamily: 'Menlo',
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...dismissed.map((e) => _AlertRow(entry: e)),
        ],
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.entry, this.onDismiss});
  final AlertEntry entry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final iconData = entry.severity == SignalSeverity.critical
        ? Icons.error
        : entry.severity == SignalSeverity.warning
            ? Icons.warning_amber
            : Icons.info_outline;
    final iconColor = entry.severity == SignalSeverity.critical
        ? const Color(0xFFEF4444)
        : entry.severity == SignalSeverity.warning
            ? const Color(0xFFE8A04C)
            : const Color(0xFF6B7280);
    final dateStr = _formatTimestamp(entry.createdAt);
    return Opacity(
      opacity: entry.dismissed ? 0.4 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconData, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x339CA3AF),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          entry.engineerHandle,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10,
                            fontFamily: 'Menlo',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFE5E5E7),
                      fontSize: 12,
                      fontFamily: 'Menlo',
                      decoration:
                          entry.dismissed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
            if (!entry.dismissed && onDismiss != null)
              TextButton(
                onPressed: onDismiss,
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '$m/$day $h:$min';
}