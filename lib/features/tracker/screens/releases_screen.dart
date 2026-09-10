import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../models/tracker_enums.dart';
import '../providers/tracker_providers.dart';
import '../releases/release_providers.dart';
import '../widgets/status_chip.dart';

/// Groups a project's features by target version and lets the user cut a
/// release: generate notes from that version's shipped features, prepend them
/// to the linked repo's CHANGELOG.md, and optionally git-tag the repo.
class ReleasesScreen extends ConsumerStatefulWidget {
  const ReleasesScreen({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<ReleasesScreen> createState() => _ReleasesScreenState();
}

class _ReleasesScreenState extends ConsumerState<ReleasesScreen> {
  Project get project => widget.project;
  String? _repoPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final config = await ProjectFileRepository.readProjectConfig(project.path);
      if (mounted) setState(() => _repoPath = config['repoPath'] as String?);
    });
  }

  @override
  Widget build(BuildContext context) {
    final featuresAsync = ref.watch(featureListProvider(project.id));
    final releasesAsync = ref.watch(releaseListProvider(project.id));

    return Scaffold(
      appBar: AppBar(title: Text('Releases — ${project.name}')),
      body: featuresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (features) {
          final releases = releasesAsync.valueOrNull ?? const <Release>[];
          final byVersion = groupFeaturesByVersion(features);
          final versions = byVersion.keys.toList()
            ..sort((a, b) {
              if (a == 'Unversioned') return 1;
              if (b == 'Unversioned') return -1;
              return b.compareTo(a);
            });
          if (versions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No features yet. Add features with a target version to plan '
                  'releases.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_repoPath == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'No repo linked — cutting a release records notes only '
                    '(no CHANGELOG or git tag).',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE8A04C)),
                  ),
                ),
              for (final v in versions)
                _VersionSection(
                  version: v,
                  features: byVersion[v]!,
                  release: _releaseFor(releases, v),
                  canCut: v != 'Unversioned' && !_busy,
                  onCut: (tag) => _cut(v, features, tag),
                ),
            ],
          );
        },
      ),
    );
  }

  Release? _releaseFor(List<Release> releases, String version) {
    for (final r in releases) {
      if (r.version == version) return r;
    }
    return null;
  }

  Future<void> _cut(String version, List<Feature> features, bool tag) async {
    setState(() => _busy = true);
    try {
      await ref.read(releaseListProvider(project.id).notifier).cutVersion(
            version: version,
            allFeatures: features,
            projectName: project.name,
            repoPath: _repoPath,
            projectPath: project.path,
            tagRepo: tag,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cut release $version')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Cut failed: $e'),
              backgroundColor: const Color(0xFF3F0A0A)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _VersionSection extends StatelessWidget {
  const _VersionSection({
    required this.version,
    required this.features,
    required this.release,
    required this.canCut,
    required this.onCut,
  });

  final String version;
  final List<Feature> features;
  final Release? release;
  final bool canCut;
  final ValueChanged<bool> onCut;

  @override
  Widget build(BuildContext context) {
    final shipped = features
        .where((f) => FeatureStatus.fromWire(f.status) == FeatureStatus.shipped)
        .length;
    final released = release?.status == 'released';
    return Card(
      color: const Color(0xFF141416),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(version,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE5E5E7))),
                const SizedBox(width: 10),
                if (released)
                  const StatusChip(
                      label: 'Released', color: Color(0xFF81C784), dense: true)
                else
                  StatusChip(
                      label: '$shipped/${features.length} shipped',
                      color: const Color(0xFF64B5F6),
                      dense: true),
                const Spacer(),
                if (release?.gitTag != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('tag ${release!.gitTag}',
                        style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 11,
                            color: Color(0xFF6B7280))),
                  ),
                if (canCut)
                  _CutButton(released: released, onCut: onCut),
              ],
            ),
            const SizedBox(height: 8),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(Icons.circle,
                      size: 9, color: FeatureStatus.fromWire(f.status).color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f.title,
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFFCFCFD2))),
                  ),
                  Text(FeatureStatus.fromWire(f.status).label,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _CutButton extends StatelessWidget {
  const _CutButton({required this.released, required this.onCut});
  final bool released;
  final ValueChanged<bool> onCut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      onSelected: onCut,
      itemBuilder: (_) => const [
        PopupMenuItem(value: false, child: Text('Cut release')),
        PopupMenuItem(value: true, child: Text('Cut release + git tag')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE8A04C).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.rocket_launch_outlined,
              size: 14, color: Color(0xFFE8A04C)),
          const SizedBox(width: 6),
          Text(released ? 'Re-cut' : 'Cut release',
              style: const TextStyle(fontSize: 12, color: Color(0xFFE8A04C))),
        ]),
      ),
    );
  }
}
