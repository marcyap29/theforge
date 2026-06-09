import 'package:flutter/foundation.dart';

@immutable
class ReferenceDoc {
  final String id;
  final String title;
  final String format;
  final String filePath;
  final int wordCount;

  const ReferenceDoc({
    required this.id,
    required this.title,
    required this.format,
    required this.filePath,
    required this.wordCount,
  });
}

class IngestedFacts {
  final String definitions;
  final String equations;
  final String constraints;
  final String rawSummary;

  const IngestedFacts({
    required this.definitions,
    required this.equations,
    required this.constraints,
    required this.rawSummary,
  });

  String toMarkdown(String docTitle) {
    final buffer = StringBuffer();
    buffer.writeln('### $docTitle');
    buffer.writeln();
    if (definitions.isNotEmpty) {
      buffer.writeln('**Definitions:**');
      buffer.writeln(definitions);
      buffer.writeln();
    }
    if (equations.isNotEmpty) {
      buffer.writeln('**Equations / Formulas:**');
      buffer.writeln(equations);
      buffer.writeln();
    }
    if (constraints.isNotEmpty) {
      buffer.writeln('**Constraints / Requirements:**');
      buffer.writeln(constraints);
      buffer.writeln();
    }
    if (rawSummary.isNotEmpty) {
      buffer.writeln('**Summary:**');
      buffer.writeln(rawSummary);
      buffer.writeln();
    }
    return buffer.toString();
  }
}
