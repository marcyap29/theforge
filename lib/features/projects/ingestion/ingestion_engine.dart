import 'reference_doc.dart';

const _extractionPrompt = '''
You are a technical document analyst. Extract structured reference context
from the provided document. Be precise and verbatim — quote definitions
exactly as written. Do not interpret or infer.

Output exactly four sections with these headers:

## Definitions
[List every definition found. Format: "**Term:** Definition text." If none, write "(none)".]

## Equations
[List every equation, formula, or mathematical expression. Preserve original notation. If none, write "(none)".]

## Constraints
[List every constraint, requirement, rule, or boundary condition. If none, write "(none)".]

## Summary
[A single paragraph summarizing what this document provides as reference context.
Focus on what a developer or architect would need to know from it.]
''';

String buildIngestionPrompt(String docTitle, String rawText) {
  return 'DOCUMENT: $docTitle\n\n$rawText\n\n$_extractionPrompt';
}

IngestedFacts parseIngestedFacts(String raw) {
  String extractSection(String header) {
    final start = raw.indexOf('## $header');
    if (start < 0) return '';
    final bodyStart = start + header.length + 3;
    final nextHeader = raw.indexOf('\n## ', bodyStart);
    final end = nextHeader < 0 ? raw.length : nextHeader;
    return raw.substring(bodyStart, end).trim();
  }

  return IngestedFacts(
    definitions: extractSection('Definitions'),
    equations: extractSection('Equations'),
    constraints: extractSection('Constraints'),
    rawSummary: extractSection('Summary'),
  );
}
