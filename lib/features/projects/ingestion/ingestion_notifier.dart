import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../providers/providers.dart';
import 'ingestion_engine.dart';
import 'reference_doc.dart';

class IngestionState {
  final List<ReferenceDoc> docs;
  final bool isParsing;
  final String? error;

  const IngestionState({
    required this.docs,
    required this.isParsing,
    this.error,
  });

  IngestionState copyWith({
    List<ReferenceDoc>? docs,
    bool? isParsing,
    String? error,
    bool clearError = false,
  }) {
    return IngestionState(
      docs: docs ?? this.docs,
      isParsing: isParsing ?? this.isParsing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// Stable cross-process fingerprint: content length + sampled char codes.
// Avoids re-running the LLM extraction when a document hasn't changed.
// String.hashCode is isolate-local; this uses arithmetic on codeUnits instead.
String _contentFingerprint(String content) {
  if (content.isEmpty) return '0:0';
  const samples = 16;
  var sum = content.length;
  for (var i = 0; i < samples; i++) {
    final idx = (content.length * i) ~/ samples;
    sum = sum * 31 + content.codeUnitAt(idx);
  }
  return '${content.length}:${sum.toUnsigned(32).toRadixString(16)}';
}

class IngestionNotifier extends Notifier<IngestionState> {
  @override
  IngestionState build() {
    return const IngestionState(docs: [], isParsing: false);
  }

  Future<void> loadDocs(String projectPath) async {
    final repo = ref.read(projectFileRepositoryProvider);
    final files = await repo.listReferenceDocs(projectPath);
    final docs = <ReferenceDoc>[];
    for (final file in files) {
      final name = p.basenameWithoutExtension(file.path);
      final ext = p.extension(file.path).replaceFirst('.', '');
      final content = await file.readAsString();
      final words = content.split(RegExp(r'\s+')).length;
      docs.add(ReferenceDoc(
        id: file.path,
        title: name,
        format: ext,
        filePath: file.path,
        wordCount: words,
      ));
    }
    state = state.copyWith(docs: docs);
  }

  Future<void> addDoc(String projectPath, String sourcePath) async {
    final repo = ref.read(projectFileRepositoryProvider);
    final llmService = ref.read(llmServiceProvider);
    final docTitle = p.basenameWithoutExtension(sourcePath);
    final format = p.extension(sourcePath).replaceFirst('.', '');

    state = state.copyWith(isParsing: true, clearError: true);

    try {
      final dest = await repo.copyReferenceDoc(projectPath, sourcePath);
      final rawText = await dest.readAsString();
      final wordCount = rawText.split(RegExp(r'\s+')).length;

      final fingerprint = _contentFingerprint(rawText);
      final fingerprintFile = File('${dest.path}.fp');
      final factsFile = File('${dest.path}.facts.md');

      final unchanged = fingerprintFile.existsSync() &&
          factsFile.existsSync() &&
          await fingerprintFile.readAsString() == fingerprint;

      if (!unchanged) {
        final prompt = buildIngestionPrompt(docTitle, rawText);
        final llmResult = await llmService.complete(
          systemPrompt: prompt,
          userPrompt: 'Extract structured reference context from the document above.',
          temperature: 0.2,
          role: LlmRole.architect,
          maxTokens: 2048,
        );
        final facts = parseIngestedFacts(llmResult);
        await factsFile.writeAsString(facts.toMarkdown(docTitle));
        await fingerprintFile.writeAsString(fingerprint);
      }

      await _rebuildContext(repo, projectPath);

      final newDoc = ReferenceDoc(
        id: dest.path,
        title: docTitle,
        format: format,
        filePath: dest.path,
        wordCount: wordCount,
      );
      final updatedDocs = [...state.docs, newDoc];
      state = state.copyWith(docs: updatedDocs, isParsing: false);
    } catch (e) {
      state = state.copyWith(isParsing: false, error: e.toString());
    }
  }

  Future<void> removeDoc(String projectPath, String docId) async {
    final repo = ref.read(projectFileRepositoryProvider);
    try {
      final docFile = File(docId);
      if (docFile.existsSync()) await docFile.delete();
      final factsFile = File('$docId.facts.md');
      if (factsFile.existsSync()) await factsFile.delete();
      await _rebuildContext(repo, projectPath);
      final updatedDocs = state.docs.where((d) => d.id != docId).toList();
      state = state.copyWith(docs: updatedDocs);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _rebuildContext(
      ProjectFileRepository repo, String projectPath) async {
    final ingestedDir = Directory(
        p.join(projectPath, ProjectFileRepository.forgeDirName, 'ingested'));
    final factsFiles = ingestedDir
        .listSync()
        .whereType<File>()
        .where((f) => p.extension(f.path) == '.md' && f.path.endsWith('.facts.md'))
        .toList();

    if (factsFiles.isEmpty) {
      await repo.writeIngestedSummary(projectPath,
          '# Reference Context\n\n_No reference documents added yet._\n');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('# Reference Context');
    buffer.writeln();
    for (final file in factsFiles) {
      final content = await file.readAsString();
      buffer.writeln(content);
      buffer.writeln('---');
      buffer.writeln();
    }
    await repo.writeIngestedSummary(projectPath, buffer.toString());
  }
}

final ingestionNotifierProvider =
    NotifierProvider<IngestionNotifier, IngestionState>(
  IngestionNotifier.new,
);
