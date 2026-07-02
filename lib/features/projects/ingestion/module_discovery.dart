import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/pull_ingestion_summary.dart';

class ModuleDiscoveryResult {
  final IngestionTier tier;
  final List<String> moduleNames;

  const ModuleDiscoveryResult({required this.tier, required this.moduleNames});

  factory ModuleDiscoveryResult.single() =>
      const ModuleDiscoveryResult(tier: IngestionTier.single, moduleNames: []);
}

class ModuleDiscovery {
  static const int fileCountFloor = 40;
  static const int minDartFilesPerModule = 3;
  // Matches a heading whose text is a known module-listing keyword.
  static final RegExp _moduleSectionRe = RegExp(
    r'^(#{1,3})\s+(?:modules?|features?|packages?|project\s+structure|architecture|layout)\s*$',
    caseSensitive: false,
    multiLine: true,
  );

  // Matches sub-headings (##/###) or list items (- / *) within a section.
  static final RegExp _sectionItemRe = RegExp(
    r'^(?:#{2,4}\s+|[-*]\s+(?:\*\*)?)([\w][\w\s/.-]{1,40})(?:\*\*)?',
    multiLine: true,
  );

  /// Returns a discovery result without throwing.
  ///
  /// Single-module repos (fewer than `fileCountFloor` files) get
  /// `IngestionTier.single` with an empty module list.
  ///
  /// Larger repos are scored against two deterministic signals:
  ///   1. Module headings in `ARCHITECTURE.md` / `README.md`.
  ///   2. Folder structure under `lib/` (subdirs with ≥3 .dart files).
  ///
  /// If either signal surfaces ≥1 module name, the repo is classified as
  /// module-aware.
  Future<ModuleDiscoveryResult> discover({
    required String repoPath,
    required int fileCount,
    int fileCountFloor = fileCountFloor,
  }) async {
    if (fileCount < fileCountFloor) {
      return ModuleDiscoveryResult.single();
    }

    final docModules = await _parseModulesFromDocs(repoPath);
    final folderModules = _detectModulesFromFolders(repoPath);

    final allNames = <String>{...docModules, ...folderModules};
    if (allNames.isEmpty) {
      return ModuleDiscoveryResult.single();
    }

    return ModuleDiscoveryResult(
      tier: IngestionTier.moduleAware,
      moduleNames: allNames.toList()..sort(),
    );
  }

  /// Reads `ARCHITECTURE.md` and `README.md` looking for a section
  /// explicitly named "Modules", "Features", "Packages", etc., then
  /// extracts only the sub-headings and list items inside that section.
  /// Returns `[]` when no such section exists. No LLM call.
  Future<List<String>> _parseModulesFromDocs(String repoPath) async {
    final candidates = [
      p.join(repoPath, 'ARCHITECTURE.md'),
      p.join(repoPath, 'README.md'),
    ];

    final found = <String>{};
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final content = await file.readAsString();

        final sectionMatch = _moduleSectionRe.firstMatch(content);
        if (sectionMatch == null) continue;

        // Count # chars to know the level of the matched heading.
        final headingLevel = sectionMatch.group(1)!.length;

        // Slice out the content after this heading until the next heading
        // at the same or higher level (i.e. <= headingLevel # chars).
        final afterSection = content.substring(sectionMatch.end);
        final nextSameLevel = RegExp(
          '^#{1,$headingLevel}\\s',
          multiLine: true,
        ).firstMatch(afterSection);

        final sectionContent = nextSameLevel != null
            ? afterSection.substring(0, nextSameLevel.start)
            : afterSection;

        for (final match in _sectionItemRe.allMatches(sectionContent)) {
          final raw = match.group(1)?.trim() ?? '';
          if (raw.length >= 2) found.add(_cleanModuleName(raw));
        }
      } catch (_) {
        // Skip unreadable files silently.
      }
    }
    return found.toList();
  }

  /// Pure folder walk — counts `.dart` files per immediate subdirectory
  /// of `lib/`. Modules with fewer than [minDartFilesPerModule] dart files
  /// are skipped. No LLM call.
  List<String> _detectModulesFromFolders(String repoPath) {
    final libDir = Directory(p.join(repoPath, 'lib'));
    if (!libDir.existsSync()) return [];

    final modules = <String>[];
    for (final entity in libDir.listSync()) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;

      int dartCount;
      try {
        dartCount = entity
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .length;
      } catch (_) {
        continue;
      }
      if (dartCount < minDartFilesPerModule) continue;

      modules.add(_cleanModuleName(name));
    }
    return modules;
  }

  /// Strips common noise from a heading/folder name so it works as a
  /// module identifier. Lowercased, no punctuation, no spaces.
  String _cleanModuleName(String raw) {
    return raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }
}
