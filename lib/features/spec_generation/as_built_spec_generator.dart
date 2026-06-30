import '../projects/models/pull_ingestion_summary.dart';

String buildAsBuiltSpecPrompt(
    IngestionSummary summary, List<Map<String, dynamic>> interviewLog) {
  final transcript = interviewLog.map((t) {
    final isUser = t['isUser'] as bool? ?? false;
    final text = t['text'] as String? ?? '';
    return '${isUser ? "ENGINEER" : "FORGE"}: $text';
  }).join('\n\n');

  return 'INGESTION SUMMARY:\n'
      '${summary.toMarkdown()}\n\n'
      'PULL INTERVIEW TRANSCRIPT:\n'
      '$transcript\n\n'
      '$_asBuiltSpecStructure';
}

const _asBuiltSpecStructure = '''
Produce an as-built spec in this exact 10-section format. Use the section headers verbatim.

## 1. Goal Statement
[The single primary goal of this system, derived from the interview]

## 2. Hard Constraints
[Non-negotiable constraints visible in code or confirmed in interview]

## 3. Component Map
[Table: Component | Single Responsibility — derived from ingestion summary]

## 4. Interface Contracts
[Key interfaces and their method signatures, from ingestion summary]

## 5. Completion Criteria
[Observable, verifiable behaviours this codebase delivers]

## 6. Static Content Specs
[Constants, configs, hardcoded values — if applicable, else "(none)"]

## 7. Out-of-Scope List
[What this codebase explicitly does NOT do — from interview]

## 8. Accepted Decisions
[Architectural decisions visible in code + rationale from interview.
As-built note: rejected alternatives not documented unless engineer stated them]

## 9. Open Flags
[Unknowns not resolved by ingestion or interview]

## 10. v2 Architecture Notes
[Future directions mentioned in interview — if none, "(none captured)"]
''';
