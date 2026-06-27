import 'package:flutter/foundation.dart';

enum ComplianceStatus { verified, uncertain, failed, skipToLlm }

class ChecklistItem {
  final String id;
  final String requirement;
  final List<String> expectedFiles;
  final List<String> expectedKeywords;
  final bool autoVerifiable;
  final String verificationNote;

  const ChecklistItem({
    required this.id,
    required this.requirement,
    required this.expectedFiles,
    required this.expectedKeywords,
    required this.autoVerifiable,
    required this.verificationNote,
  });

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'] as String,
        requirement: j['requirement'] as String,
        expectedFiles: (j['expectedFiles'] as List<dynamic>?)?.cast<String>() ?? [],
        expectedKeywords: (j['expectedKeywords'] as List<dynamic>?)?.cast<String>() ?? [],
        autoVerifiable: j['autoVerifiable'] as bool? ?? true,
        verificationNote: j['verificationNote'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChecklistItem) return false;
    return id == other.id &&
        requirement == other.requirement &&
        listEquals(expectedFiles, other.expectedFiles) &&
        listEquals(expectedKeywords, other.expectedKeywords) &&
        autoVerifiable == other.autoVerifiable &&
        verificationNote == other.verificationNote;
  }

  @override
  int get hashCode => Object.hash(
        id,
        requirement,
        expectedFiles,
        expectedKeywords,
        autoVerifiable,
        verificationNote,
      );
}

class ComponentCompliance {
  final ChecklistItem item;
  final ComplianceStatus status;
  final List<String> evidence;
  final String? reason;

  const ComponentCompliance({
    required this.item,
    required this.status,
    required this.evidence,
    this.reason,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComponentCompliance) return false;
    return item == other.item &&
        status == other.status &&
        listEquals(evidence, other.evidence) &&
        reason == other.reason;
  }

  @override
  int get hashCode => Object.hash(
        item,
        status,
        evidence,
        reason,
      );
}

class SpecComplianceResult {
  final String priorSpecVersion;
  final String checkedAt;
  final String? checkedCommit;
  final bool ranGitCheck;
  final List<ComponentCompliance> verified;
  final List<ComponentCompliance> uncertain;
  final List<ComponentCompliance> failed;
  final List<ComponentCompliance> skipToLlm;

  const SpecComplianceResult({
    required this.priorSpecVersion,
    required this.checkedAt,
    this.checkedCommit,
    required this.ranGitCheck,
    required this.verified,
    required this.uncertain,
    required this.failed,
    required this.skipToLlm,
  });

  int get total => verified.length + uncertain.length + failed.length + skipToLlm.length;
  int get gapCount => uncertain.length + failed.length + skipToLlm.length;
  bool get passedAutoCheck => failed.isEmpty && uncertain.isEmpty;

  String toComplianceContext() {
    final buf = StringBuffer();
    buf.writeln('V1 BUILD COMPLIANCE CHECK (auto-generated, structural only):');
    for (final c in verified) {
      buf.writeln('✅ ${c.item.requirement}');
      if (c.evidence.isNotEmpty) buf.writeln('   Files: ${c.evidence.take(3).join(', ')}');
    }
    for (final c in uncertain) {
      buf.writeln('⚠️  ${c.item.requirement} — uncertain (${c.reason ?? ''})');
    }
    for (final c in failed) {
      buf.writeln('❌ ${c.item.requirement} — no evidence found');
    }
    for (final c in skipToLlm) {
      buf.writeln('➡️  ${c.item.requirement} — requires LLM/manual check');
      if (c.item.verificationNote.isNotEmpty) buf.writeln('   Note: ${c.item.verificationNote}');
    }
    return buf.toString().trim();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SpecComplianceResult) return false;
    return priorSpecVersion == other.priorSpecVersion &&
        checkedAt == other.checkedAt &&
        checkedCommit == other.checkedCommit &&
        ranGitCheck == other.ranGitCheck &&
        listEquals(verified, other.verified) &&
        listEquals(uncertain, other.uncertain) &&
        listEquals(failed, other.failed) &&
        listEquals(skipToLlm, other.skipToLlm);
  }

  @override
  int get hashCode => Object.hash(
        priorSpecVersion,
        checkedAt,
        checkedCommit,
        ranGitCheck,
        verified,
        uncertain,
        failed,
        skipToLlm,
      );
}