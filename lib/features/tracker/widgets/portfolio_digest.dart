import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/forge_theme.dart';
import '../../../core/widgets/hearth_dial.dart';
import '../../projects/providers/providers.dart';
import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';

// ============================================================================
// 1. The digest model + provider
// ============================================================================

/// One project's line in the digest.
class ProjectDelta {
  const ProjectDelta({
    required this.entry,
    required this.movedCount,
    required this.newlyShipped,
    required this.blockedCount,
    required this.lastActivity,
  });

  final PortfolioEntry entry;

  /// Features touched since this project was last opened.
  final int movedCount;

  /// Of those, the ones now marked shipped — the "looks finished, confirm?"
  /// bucket.
  final int newlyShipped;

  final int blockedCount;

  /// Most recent `updatedAt` across the project's features, or null if none.
  final DateTime? lastActivity;

  bool get isQuiet => movedCount == 0;

  String get project => entry.project.name;
}

/// Everything the home screen needs above the project grid.
class PortfolioDigest {
  const PortfolioDigest({required this.deltas, required this.since});

  final List<ProjectDelta> deltas;

  /// Oldest "last opened" across the projects that moved. Null on a first
  /// visit, when nothing has a baseline yet.
  final DateTime? since;

  List<ProjectDelta> get moved => deltas.where((d) => !d.isQuiet).toList();
  List<ProjectDelta> get quiet => deltas.where((d) => d.isQuiet).toList();

  int get totalMoved => moved.fold(0, (n, d) => n + d.movedCount);
  int get totalNewlyShipped => moved.fold(0, (n, d) => n + d.newlyShipped);
  int get projectsMoved => moved.length;

  bool get isEmpty => deltas.isEmpty;
  bool get nothingHappened => totalMoved == 0;

  /// Portfolio-wide completion, for the dial in the header.
  double get progress {
    var total = 0, done = 0;
    for (final d in deltas) {
      total += d.entry.totalCount;
      done += d.entry.shippedCount;
    }
    return total == 0 ? 0 : done / total;
  }
}

/// The digest, built entirely from data the app already stores:
/// `Projects.lastOpened` as the baseline and `Features.updatedAt` as the
/// signal. No git, no LLM, no API key. Git commit counts can enrich this
/// later for projects that have a folder linked, but nothing here needs them.
final portfolioDigestProvider = FutureProvider<PortfolioDigest>((ref) async {
  final entries = await ref.watch(portfolioProvider.future);

  final deltas = <ProjectDelta>[];
  DateTime? oldestBaseline;

  for (final entry in entries) {
    final baseline = entry.project.lastOpened ?? 0;
    var moved = 0;
    var shipped = 0;
    var latest = 0;

    for (final f in entry.features) {
      if (f.updatedAt > latest) latest = f.updatedAt;
      if (baseline == 0 || f.updatedAt <= baseline) continue;
      moved++;
      if (FeatureStatus.fromWire(f.status) == FeatureStatus.shipped) shipped++;
    }

    if (moved > 0 && baseline > 0) {
      final b = DateTime.fromMillisecondsSinceEpoch(baseline);
      if (oldestBaseline == null || b.isBefore(oldestBaseline)) {
        oldestBaseline = b;
      }
    }

    deltas.add(ProjectDelta(
      entry: entry,
      movedCount: moved,
      newlyShipped: shipped,
      blockedCount: entry.blockedCount,
      lastActivity:
          latest == 0 ? null : DateTime.fromMillisecondsSinceEpoch(latest),
    ));
  }

  // Loudest first: most movement, then most recent activity.
  deltas.sort((a, b) {
    if (a.movedCount != b.movedCount) {
      return b.movedCount.compareTo(a.movedCount);
    }
    final at = a.lastActivity?.millisecondsSinceEpoch ?? 0;
    final bt = b.lastActivity?.millisecondsSinceEpoch ?? 0;
    return bt.compareTo(at);
  });

  return PortfolioDigest(deltas: deltas, since: oldestBaseline);
});

/// Stamps `lastOpened = now` on every project. Call this ONCE, after the
/// digest has been read and shown, or the digest resets itself before the
/// user has seen it.
Future<void> markPortfolioSeen(WidgetRef ref) async {
  final db = ref.read(forgeDatabaseProvider);
  final entries = await ref.read(portfolioProvider.future);
  final now = DateTime.now().millisecondsSinceEpoch;
  for (final e in entries) {
    await db.updateLastOpened(e.project.id, now);
  }
}

// ============================================================================
// 2. The widget
// ============================================================================

/// The block that sits at the top of the home screen, above the project grid.
///
/// This is the change that turns the dashboard from a filing cabinet into a
/// project manager: it answers "what happened while I was away" before the
/// user has to go looking for it.
class PortfolioDigestPanel extends ConsumerWidget {
  const PortfolioDigestPanel({
    super.key,
    required this.onCatchUp,
    this.onOpenProject,
  });

  /// Runs the existing check-in flow. Wire to `checkin_service`.
  final VoidCallback onCatchUp;

  final void Function(PortfolioEntry entry)? onOpenProject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(portfolioDigestProvider);

    return async.when(
      loading: () => const SizedBox(height: 132),
      error: (e, _) => _DigestShell(
        eyebrow: 'COULDN\'T READ YOUR PROJECTS',
        headline: 'Something went wrong loading your projects.',
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton(
            onPressed: () => ref.invalidate(portfolioDigestProvider),
            child: const Text('TRY AGAIN'),
          ),
        ),
      ),
      data: (digest) {
        if (digest.isEmpty) return const SizedBox.shrink();

        return _DigestShell(
          eyebrow: _eyebrow(digest),
          headline: _headline(digest),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Divider(height: 1, color: ForgeColors.hairline),
              for (final d in digest.deltas)
                _DigestRow(
                  delta: d,
                  onTap: onOpenProject == null
                      ? null
                      : () => onOpenProject!(d.entry),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton(
                    onPressed: onCatchUp,
                    child: const Text('CATCH ME UP'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await markPortfolioSeen(ref);
                      ref.invalidate(portfolioProvider);
                      ref.invalidate(portfolioDigestProvider);
                    },
                    child: const Text('NOT NOW'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _eyebrow(PortfolioDigest d) {
    if (d.since == null) return 'YOUR PROJECTS';
    return 'SINCE ${_relative(d.since!).toUpperCase()}';
  }

  String _headline(PortfolioDigest d) {
    if (d.nothingHappened) {
      final n = d.deltas.length;
      return 'Nothing has moved. $n project${n == 1 ? '' : 's'} tracked.';
    }
    final u = d.totalMoved;
    final p = d.projectsMoved;
    final base = '$u update${u == 1 ? '' : 's'} across '
        '$p project${p == 1 ? '' : 's'}.';
    if (d.totalNewlyShipped == 0) return base;
    final s = d.totalNewlyShipped;
    return '$base ${s == 1 ? 'One feature looks' : '$s features look'} finished.';
  }
}

class _DigestShell extends StatelessWidget {
  const _DigestShell({
    required this.eyebrow,
    required this.headline,
    required this.child,
  });

  final String eyebrow;
  final String headline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: t.labelSmall),
        const SizedBox(height: 10),
        Text(headline, style: t.headlineSmall),
        child,
      ],
    );
  }
}

class _DigestRow extends StatelessWidget {
  const _DigestRow({required this.delta, this.onTap});

  final ProjectDelta delta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final Color dot;
    if (delta.blockedCount > 0) {
      dot = ForgeColors.rustLit;
    } else if (delta.isQuiet) {
      dot = ForgeColors.steelDim;
    } else {
      dot = ForgeColors.ember;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: ForgeColors.hairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 118,
              child: Text(
                delta.project,
                style: t.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _detail(delta),
                style: t.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              delta.lastActivity == null
                  ? '—'
                  : _relative(delta.lastActivity!),
              style: t.labelMedium?.copyWith(color: ForgeColors.steelDim),
            ),
          ],
        ),
      ),
    );
  }

  String _detail(ProjectDelta d) {
    if (d.isQuiet) {
      if (d.lastActivity == null) return 'Nothing tracked yet.';
      return 'Quiet since ${_relative(d.lastActivity!)}.';
    }
    final parts = <String>['${d.movedCount} update${d.movedCount == 1 ? '' : 's'}.'];
    if (d.newlyShipped > 0) {
      parts.add(d.newlyShipped == 1
          ? 'One looks done, waiting on you to confirm.'
          : '${d.newlyShipped} look done, waiting on you to confirm.');
    }
    if (d.blockedCount > 0) {
      parts.add('${d.blockedCount} stuck.');
    }
    if (parts.length == 1) parts.add('Nothing needs confirming.');
    return parts.join(' ');
  }
}

/// Plain-language relative time. Deliberately vague past a week — an exact
/// timestamp implies a precision the underlying data doesn't have.
String _relative(DateTime when) {
  final d = DateTime.now().difference(when);
  if (d.inMinutes < 2) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays == 1) return 'yesterday';
  if (d.inDays < 14) return '${d.inDays}d ago';
  if (d.inDays < 60) return '${(d.inDays / 7).round()} weeks ago';
  return '${(d.inDays / 30).round()} months ago';
}

// ============================================================================
// 3. Header used by the home screen
// ============================================================================

/// The app's own header row, under the macOS title bar. Carries the dial at
/// the portfolio's real completion, so the mark doubles as a state readout.
class ForgeAppHeader extends ConsumerWidget {
  const ForgeAppHeader({super.key, this.trailing});

  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(portfolioDigestProvider).valueOrNull?.progress ?? 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ForgeColors.hairline)),
      ),
      child: Row(
        children: [
          HearthDial(size: 22, progress: progress, showBloom: false),
          const SizedBox(width: 9),
          Text(
            'THE FORGE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ForgeColors.ivory,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.1,
                ),
          ),
          const Spacer(),
          ...?trailing,
        ],
      ),
    );
  }
}
