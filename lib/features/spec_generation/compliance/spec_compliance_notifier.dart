import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';
import 'spec_compliance_models.dart';

class SpecComplianceNotifier extends AutoDisposeFamilyAsyncNotifier<SpecComplianceResult?, ({String projectPath, String projectName, String priorSpecVersion})> {
  @override
  SpecComplianceResult? build(({String projectPath, String projectName, String priorSpecVersion}) args) {
    // Return null to trigger check when needed
    return null;
  }

  Future<SpecComplianceResult> check(({String projectPath, String projectName, String priorSpecVersion}) args) async {
    final projectPath = args.projectPath;
    final projectName = args.projectName;
    final priorSpecVersion = args.priorSpecVersion;

    // Try to read cached verification result first
    final cached = await _readCachedResult(projectPath, projectName, priorSpecVersion);
    if (cached != null) {
      final projectConfig = await ProjectFileRepository.readProjectConfig(projectPath);
      final repoPath = projectConfig['repoPath'] as String?;
      if (repoPath != null) {
        final currentHead = await ProjectFileRepository.getGitHead(repoPath);
        if (cached.checkedCommit == currentHead) {
          return cached;
        }
      }
    }

    // Read the handoff package to get the checklist
    final handoff = await ProjectFileRepository.readHandoffPackage(projectPath, projectName, priorSpecVersion);
    
    if (handoff == null) {
      return SpecComplianceResult(
        priorSpecVersion: priorSpecVersion,
        checkedAt: DateTime.now().toIso8601String(),
        checkedCommit: null,
        ranGitCheck: false,
        verified: const [],
        uncertain: const [],
        failed: const [],
        skipToLlm: const [],
      );
    }
    
    final checklistRaw = handoff['verificationChecklist'] as List<dynamic>? ?? [];
    if (checklistRaw.isEmpty) {
      return SpecComplianceResult(
        priorSpecVersion: priorSpecVersion,
        checkedAt: DateTime.now().toIso8601String(),
        checkedCommit: null,
        ranGitCheck: false,
        verified: const [],
        uncertain: const [],
        failed: const [],
        skipToLlm: const [],
      );
    }
    
    // Parse checklist items
    final checklist = checklistRaw
        .whereType<Map<String, dynamic>>()
        .map((j) => ChecklistItem.fromJson(j))
        .toList();
    
    final lockedAt = handoff['lockedAt'] as String?;
    
    if (lockedAt == null) {
      return SpecComplianceResult(
        priorSpecVersion: priorSpecVersion,
        checkedAt: DateTime.now().toIso8601String(),
        checkedCommit: null,
        ranGitCheck: false,
        verified: const [],
        uncertain: const [],
        failed: const [],
        skipToLlm: const [],
      );
    }
    
    // Get project configuration
    final projectConfig = await ProjectFileRepository.readProjectConfig(projectPath);
    final repoPath = projectConfig['repoPath'] as String?;

    // Get changed files from git if repo path is available
    Set<String> changedFiles = {};
    String? currentHead;

    if (repoPath != null) {
      changedFiles = await ProjectFileRepository.getGitChangedFiles(repoPath, since: lockedAt);
      currentHead = await ProjectFileRepository.getGitHead(repoPath);
    }

    // Get commit messages for keyword matching
    List<String> allCommitMessages = [];
    if (repoPath != null) {
      allCommitMessages = await ProjectFileRepository.getGitCommitMessages(repoPath, since: lockedAt);
    }
    
    final allCommitText = allCommitMessages.join(' ').toLowerCase();
    
    final results = <ComponentCompliance>[];
    
    for (final item in checklist) {
      if (!item.autoVerifiable) {
        results.add(ComponentCompliance(
          item: item,
          status: ComplianceStatus.skipToLlm,
          evidence: [],
          reason: null,
        ));
        continue;
      }
      
      // Check for file matches
      final matchedFiles = <String>[];
      final missingFiles = <String>[];
      
      for (final expectedFile in item.expectedFiles) {
        if (changedFiles.contains(expectedFile)) {
          final file = File(p.join(repoPath!, expectedFile));
          if (file.existsSync()) {
            matchedFiles.add(expectedFile);
          } else {
            missingFiles.add(expectedFile);
          }
        } else {
          missingFiles.add(expectedFile);
        }
      }
      
      if (missingFiles.isEmpty) {
        // All files exist and were changed
        results.add(ComponentCompliance(
          item: item,
          status: ComplianceStatus.verified,
          evidence: matchedFiles,
          reason: 'full_file_match',
        ));
      } else if (matchedFiles.isNotEmpty) {
        // Partial match - some files were changed and exist
        results.add(ComponentCompliance(
          item: item,
          status: ComplianceStatus.uncertain,
          evidence: matchedFiles,
          reason: 'partial_file_match',
        ));
      } else {
        // No file matches, check for keywords in commit messages
        final keywordsHit = <String>[];
        for (final keyword in item.expectedKeywords) {
          if (allCommitText.contains(keyword.toLowerCase())) {
            keywordsHit.add(keyword);
          }
        }
        
        if (keywordsHit.isNotEmpty) {
          // Keyword matches found
          results.add(ComponentCompliance(
            item: item,
            status: ComplianceStatus.uncertain,
            evidence: keywordsHit,
            reason: 'keyword_only',
          ));
        } else {
          // No matches found at all
          results.add(ComponentCompliance(
            item: item,
            status: ComplianceStatus.failed,
            evidence: [],
            reason: null,
          ));
        }
      }
    }
    
    // Group results
    final verified = results.where((r) => r.status == ComplianceStatus.verified).toList();
    final uncertain = results.where((r) => r.status == ComplianceStatus.uncertain).toList();
    final failed = results.where((r) => r.status == ComplianceStatus.failed).toList();
    final skipToLlm = results.where((r) => r.status == ComplianceStatus.skipToLlm).toList();
    
    final result = SpecComplianceResult(
      priorSpecVersion: priorSpecVersion,
      checkedAt: DateTime.now().toIso8601String(),
      checkedCommit: currentHead,
      ranGitCheck: repoPath != null,
      verified: verified,
      uncertain: uncertain,
      failed: failed,
      skipToLlm: skipToLlm,
    );
    
    // Write to cache
    await ProjectFileRepository.writeVerificationResult(projectPath, projectName, priorSpecVersion, result.toJson());

    state = AsyncData(result);
    return result;
  }
  
  /// Read cached result from file system
  Future<SpecComplianceResult?> _readCachedResult(
      String projectPath, String projectName, String priorSpecVersion) async {
    try {
      final cached = await ProjectFileRepository.readVerificationResult(projectPath, projectName, priorSpecVersion);
      if (cached != null) {
        return SpecComplianceResult(
          priorSpecVersion: cached['priorSpecVersion'] as String,
          checkedAt: cached['checkedAt'] as String,
          checkedCommit: cached['checkedCommit'] as String?,
          ranGitCheck: cached['ranGitCheck'] as bool,
          verified: (cached['verified'] as List<dynamic>? ?? [])
              .map((j) => ComponentCompliance(
                    item: ChecklistItem.fromJson((j as Map<String, dynamic>)['item']),
                    status: ComplianceStatus.values.byName((j['status'] as String)),
                    evidence: (j['evidence'] as List<dynamic>?)?.cast<String>() ?? [],
                    reason: j['reason'] as String?,
                  ))
              .toList(),
          uncertain: (cached['uncertain'] as List<dynamic>? ?? [])
              .map((j) => ComponentCompliance(
                    item: ChecklistItem.fromJson((j as Map<String, dynamic>)['item']),
                    status: ComplianceStatus.values.byName((j['status'] as String)),
                    evidence: (j['evidence'] as List<dynamic>?)?.cast<String>() ?? [],
                    reason: j['reason'] as String?,
                  ))
              .toList(),
          failed: (cached['failed'] as List<dynamic>? ?? [])
              .map((j) => ComponentCompliance(
                    item: ChecklistItem.fromJson((j as Map<String, dynamic>)['item']),
                    status: ComplianceStatus.values.byName((j['status'] as String)),
                    evidence: (j['evidence'] as List<dynamic>?)?.cast<String>() ?? [],
                    reason: j['reason'] as String?,
                  ))
              .toList(),
          skipToLlm: (cached['skipToLlm'] as List<dynamic>? ?? [])
              .map((j) => ComponentCompliance(
                    item: ChecklistItem.fromJson((j as Map<String, dynamic>)['item']),
                    status: ComplianceStatus.values.byName((j['status'] as String)),
                    evidence: (j['evidence'] as List<dynamic>?)?.cast<String>() ?? [],
                    reason: j['reason'] as String?,
                  ))
              .toList(),
        );
      }
    } catch (e) {
      // Return null on cache read error
    }
    
    return null;
  }
}

extension on SpecComplianceResult {
  Map<String, dynamic> toJson() {
    return {
      'priorSpecVersion': priorSpecVersion,
      'checkedAt': checkedAt,
      'checkedCommit': checkedCommit,
      'ranGitCheck': ranGitCheck,
      'verified': verified.map((r) => {
            'item': r.item.toJson(),
            'status': r.status.name,
            'evidence': r.evidence,
            'reason': r.reason,
          }).toList(),
      'uncertain': uncertain.map((r) => {
            'item': r.item.toJson(),
            'status': r.status.name,
            'evidence': r.evidence,
            'reason': r.reason,
          }).toList(),
      'failed': failed.map((r) => {
            'item': r.item.toJson(),
            'status': r.status.name,
            'evidence': r.evidence,
            'reason': r.reason,
          }).toList(),
      'skipToLlm': skipToLlm.map((r) => {
            'item': r.item.toJson(),
            'status': r.status.name,
            'evidence': r.evidence,
            'reason': r.reason,
          }).toList(),
    };
  }
}

extension on ChecklistItem {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requirement': requirement,
      'expectedFiles': expectedFiles,
      'expectedKeywords': expectedKeywords,
      'autoVerifiable': autoVerifiable,
      'verificationNote': verificationNote,
    };
  }
}

final specComplianceProvider = AsyncNotifierProvider.autoDispose.family<
    SpecComplianceNotifier, SpecComplianceResult?, ({String projectPath, String projectName, String priorSpecVersion})>(
  SpecComplianceNotifier.new,
);