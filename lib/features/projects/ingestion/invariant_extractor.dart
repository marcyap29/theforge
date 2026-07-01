import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../models/pull_ingestion_summary.dart';

enum InvariantConfidence { high, medium, low }

@immutable
class ExtractedInvariant {
  final String rule;
  final List<String> appliesTo;
  final String enforcement;
  final String violationConsequence;
  final String sourceRef;
  final InvariantConfidence confidence;

  const ExtractedInvariant({
    required this.rule,
    required this.appliesTo,
    required this.enforcement,
    required this.violationConsequence,
    required this.sourceRef,
    required this.confidence,
  });

  factory ExtractedInvariant.fromJson(Map<String, dynamic> json) {
    final appliesToRaw = json['appliesTo'];
    final appliesTo = appliesToRaw is List<dynamic>
        ? appliesToRaw.whereType<String>().toList()
        : <String>[];

    final confidenceStr = json['confidence'] as String? ?? 'low';
    final confidence = InvariantConfidence.values.firstWhere(
      (e) => e.name == confidenceStr,
      orElse: () => InvariantConfidence.low,
    );

    return ExtractedInvariant(
      rule: json['rule'] as String? ?? '',
      appliesTo: appliesTo,
      enforcement: json['enforcement'] as String? ?? '',
      violationConsequence: json['violationConsequence'] as String? ?? '',
      sourceRef: json['sourceRef'] as String? ?? '',
      confidence: confidence,
    );
  }

  Map<String, dynamic> toJson() => {
      'rule': rule,
      'appliesTo': appliesTo,
      'enforcement': enforcement,
      'violationConsequence': violationConsequence,
      'sourceRef': sourceRef,
      'confidence': confidence.name,
    };

  String toMarkdown() {
    final appliesToStr = appliesTo.isEmpty ? 'unknown' : appliesTo.join(', ');
    return '- **$rule** [${confidence.name}]\n'
        '  Applies to: $appliesToStr\n'
        '  Enforcement: $enforcement\n'
        '  If violated: $violationConsequence\n'
        '  Source: $sourceRef\n';
  }
}

const _invariantSystemPrompt =
    'You are a senior software architect analyzing an existing codebase. '
    'Identify cross-cutting invariants — rules that apply across multiple '
    'components and would cause bugs or system failures if broken. '
    'Output a JSON array only. No prose, no code fences, no explanation. '
    'Each element: {"rule":"string","appliesTo":["string"],"enforcement":"string",'
    '"violationConsequence":"string","sourceRef":"string",'
    '"confidence":"high"|"medium"|"low"}. '
    'Maximum 10 invariants. Only include rules that span 2+ components. '
    'Single-component rules are out of scope.';

String _buildExtractionPrompt(
  String referenceContext,
  List<ComponentInfo> components,
) {
  final componentList = components
      .where((c) => c.name.isNotEmpty)
      .map((c) => '- ${c.name}: ${c.responsibilities}')
      .join('\n');

  return 'INGESTION SUMMARY:\n$referenceContext\n\n'
      'COMPONENT LIST:\n$componentList\n\n'
      'Extract cross-cutting invariants from this codebase.';
}

List<ExtractedInvariant> _parseInvariants(String raw) {
  try {
    final cleaned = raw
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final decoded = jsonDecode(cleaned);
    if (decoded is! List<dynamic>) return const [];
    final result = <ExtractedInvariant>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        result.add(ExtractedInvariant.fromJson(item));
      }
    }
    return result;
  } catch (_) {
    return const [];
  }
}

class InvariantExtractor {
  final LlmService _service;

  InvariantExtractor(this._service);

  Future<List<ExtractedInvariant>> extract({
    required String referenceContext,
    required List<ComponentInfo> components,
  }) async {
    final prompt = _buildExtractionPrompt(referenceContext, components);
    final raw = await _service.complete(
      role: LlmRole.architect,
      systemPrompt: _invariantSystemPrompt,
      userPrompt: prompt,
      temperature: 0.2,
      maxTokens: 4096,
    );
    return _parseInvariants(raw);
  }
}
