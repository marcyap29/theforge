import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/filesystem/project_file_repository.dart';

class DonorIndexResult {
  const DonorIndexResult({
    required this.repoName,
    required this.fileCount,
    required this.totalChars,
  });
  final String repoName;
  final int fileCount;
  final int totalChars;
}

/// Scans a "donor" repo and extracts utility/model/service code into
/// Forge/ingested/donor_context.md so the executor can adapt real
/// implementations instead of hallucinating similar-looking code.
class DonorService {
  // Cap each file at this many lines — shows full logic for small files,
  // just the top of large ones (enough to see signatures and patterns).
  static const _maxFileLines = 180;

  // Total content cap — large repos produce too much for one prompt.
  static const _maxTotalChars = 48000;

  // Source code extensions to include.
  static const _codeExts = {
    '.dart', '.swift', '.kt', '.ts', '.tsx', '.js', '.jsx',
    '.py', '.rb', '.go', '.rs',
  };

  // Directory names to skip entirely.
  static const _skipDirs = {
    '.git', 'build', '.dart_tool', 'node_modules', '.build',
    'Pods', '__pycache__', '.gradle', 'DerivedData', 'xcuserdata',
  };

  // Path segments that suggest utility/service/model code — include first.
  static const _priority = {
    'services', 'service', 'models', 'model', 'data', 'repositories',
    'repository', 'utils', 'util', 'helpers', 'helper', 'core',
    'domain', 'providers', 'manager', 'managers',
  };

  // Path segments that suggest UI code — include last (may be cut by cap).
  static const _depriority = {
    'screens', 'screen', 'widgets', 'widget', 'views', 'view',
    'pages', 'page', 'components', 'component', 'ui',
  };

  static Future<DonorIndexResult> indexDonor({
    required String donorPath,
    required String projectPath,
  }) async {
    final dir = Directory(donorPath);
    if (!dir.existsSync()) {
      throw Exception('Donor path does not exist: $donorPath');
    }

    final repoName = p.basename(donorPath);
    final collected = <File>[];
    _walk(dir, collected);

    // Sort: utility/service/model files first, UI last.
    collected.sort((a, b) => _score(a.path).compareTo(_score(b.path)));

    final buf = StringBuffer()
      ..writeln('# Donor code — $repoName')
      ..writeln(
          '# Adapt these utilities for the current project. Do NOT copy '
          'import paths or package names — rewrite for this project\'s structure.')
      ..writeln();

    var fileCount = 0;
    var totalChars = 0;

    for (final file in collected) {
      if (totalChars >= _maxTotalChars) break;
      try {
        final raw = await file.readAsString();
        final lines = raw.split('\n');
        final body = lines.length > _maxFileLines
            ? '${lines.take(_maxFileLines).join('\n')}\n'
                '// … (${lines.length - _maxFileLines} more lines omitted)'
            : raw.trimRight();

        final rel = p.relative(file.path, from: donorPath);
        buf
          ..writeln('### $rel')
          ..writeln(body)
          ..writeln();

        totalChars += body.length;
        fileCount++;
      } catch (_) {
        // Unreadable file — skip silently.
      }
    }

    final content = buf.toString();
    await ProjectFileRepository.writeDonorContext(projectPath, content);
    await ProjectFileRepository.writeDonorMeta(projectPath, {
      'donorPath': donorPath,
      'repoName': repoName,
      'indexedAt': DateTime.now().toIso8601String(),
      'fileCount': fileCount,
    });

    return DonorIndexResult(
      repoName: repoName,
      fileCount: fileCount,
      totalChars: totalChars,
    );
  }

  static void _walk(Directory dir, List<File> out) {
    try {
      for (final e in dir.listSync()) {
        if (e is Directory) {
          if (_skipDirs.contains(p.basename(e.path))) continue;
          _walk(e, out);
        } else if (e is File) {
          final ext = p.extension(e.path).toLowerCase();
          if (!_codeExts.contains(ext)) continue;
          final base = p.basename(e.path);
          // Skip generated and test files.
          if (base.endsWith('.g.dart') ||
              base.endsWith('.freezed.dart') ||
              base.endsWith('.mocks.dart') ||
              base.endsWith('_test.dart') ||
              e.path.contains('/test/')) continue;
          out.add(e);
        }
      }
    } catch (_) {}
  }

  static int _score(String path) {
    final lower = path.toLowerCase();
    for (final seg in _depriority) {
      if (lower.contains('/$seg/') || lower.contains('/$seg.')) return 2;
    }
    for (final seg in _priority) {
      if (lower.contains('/$seg/') || lower.contains('/$seg.')) return 0;
    }
    return 1;
  }
}
