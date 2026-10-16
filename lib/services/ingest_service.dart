import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../data/filesystem/project_file_repository.dart';
import 'llm/llm_provider.dart';
import 'llm/llm_service.dart';

/// Summary of a completed ingest run.
class IngestResult {
  const IngestResult({
    required this.processed,
    required this.skipped,
    required this.errors,
  });

  final List<String> processed;
  final List<String> skipped;
  final List<String> errors;

  bool get hasProcessed => processed.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

/// Ingests user-supplied files into a project's reference context.
///
/// Images are sent to the Architect LLM for description (vision extraction).
/// Text and markdown files are read directly. All extracted content is
/// appended to Forge/ingested/reference_context.md which Build-with-AI
/// reads on every run. Original files are copied to Forge/ingested/source/.
class IngestService {
  const IngestService(this._llm);
  final LlmService _llm;

  static const _imageExts = {'.png', '.jpg', '.jpeg', '.heic', '.gif', '.webp'};
  static const _textExts = {'.txt', '.md', '.markdown'};

  static const _extractSystem = '''
You analyze image files attached to software project plans and describe their \
content for developers. Be specific and technical.

When the image shows a UI or app screen: describe the layout, visual components, \
interactions, and any functionality that would need to be implemented.
When the image shows a diagram or wireframe: describe the structure, flows, and \
design decisions.
When the image shows reference material or mockups: extract any requirements, \
constraints, or design language evident.

Write 2-5 paragraphs of plain text. No bullet lists, no headers.
''';

  Future<IngestResult> ingestFiles({
    required List<String> filePaths,
    required String projectPath,
  }) async {
    final processed = <String>[];
    final skipped = <String>[];
    final errors = <String>[];
    final blocks = <String>[];

    for (final path in filePaths) {
      final name = p.basename(path);
      final ext = p.extension(path).toLowerCase();

      try {
        if (_imageExts.contains(ext)) {
          final bytes = await File(path).readAsBytes();
          final mime = _mimeType(ext);
          final description = await _extractImage(bytes, mime, name);
          blocks.add('### $name\n\n$description');
          await _copyToSource(path, projectPath);
          processed.add(name);
        } else if (_textExts.contains(ext)) {
          final text = await File(path).readAsString();
          if (text.trim().isNotEmpty) {
            blocks.add('### $name\n\n${text.trim()}');
            await _copyToSource(path, projectPath);
            processed.add(name);
          } else {
            skipped.add(name);
          }
        } else {
          skipped.add(name);
        }
      } catch (e) {
        errors.add('$name: $e');
      }
    }

    if (blocks.isNotEmpty) {
      await ProjectFileRepository.appendReferenceContext(
        projectPath,
        blocks.join('\n\n'),
      );
    }

    return IngestResult(
        processed: processed, skipped: skipped, errors: errors);
  }

  Future<String> _extractImage(
      Uint8List bytes, String mimeType, String name) async {
    final encoded = base64Encode(bytes);
    return _llm.complete(
      systemPrompt: _extractSystem,
      userPrompt:
          'Describe this image ($name) for a software development context.',
      temperature: 0.1,
      role: LlmRole.architect,
      maxTokens: 800,
      think: false,
      images: [LlmImage(base64: encoded, mimeType: mimeType)],
    );
  }

  static String _mimeType(String ext) => switch (ext) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.gif' => 'image/gif',
        '.webp' => 'image/webp',
        '.heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  static Future<void> _copyToSource(
      String filePath, String projectPath) async {
    final dir = Directory(
        p.join(projectPath, ProjectFileRepository.forgeDirName, 'ingested', 'source'));
    await dir.create(recursive: true);
    final dest = p.join(dir.path, p.basename(filePath));
    if (!File(dest).existsSync()) {
      await File(filePath).copy(dest);
    }
  }
}
