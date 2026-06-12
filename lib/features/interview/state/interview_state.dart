import 'package:flutter/foundation.dart';

import 'interview_dimension.dart';

enum DimensionState { unknown, partial, resolved }

@immutable
class InterviewTurn {
  final String role;
  final String content;
  final DateTime timestamp;

  const InterviewTurn({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  bool get isUser => role == 'user';
  bool get isInterviewer => role == 'interviewer';
}

@immutable
class ConflictItem {
  final String id;
  final String dimensionALabel;
  final String dimensionBLabel;
  final String description;
  final String recommendation;

  const ConflictItem({
    required this.id,
    required this.dimensionALabel,
    required this.dimensionBLabel,
    required this.description,
    required this.recommendation,
  });
}

@immutable
class InterviewState {
  final String projectPath;
  final String projectName;
  final List<DimensionDef> dimensions;
  final Map<String, DimensionState> confidenceMap;
  final List<InterviewTurn> turns;
  final List<ConflictItem> openConflicts;
  final bool specGenEnabled;
  final bool isLoading;
  final bool llmUnavailable;
  final String currentLayer;
  final Map<String, dynamic> extracted;
  final bool parseDegraded;

  const InterviewState({
    required this.projectPath,
    required this.projectName,
    required this.dimensions,
    required this.confidenceMap,
    required this.turns,
    required this.openConflicts,
    required this.specGenEnabled,
    required this.isLoading,
    required this.currentLayer,
    required this.extracted,
    this.llmUnavailable = false,
    this.parseDegraded = false,
  });

  factory InterviewState.empty(
    String projectPath,
    String projectName,
    List<DimensionDef> dimensions,
  ) {
    final isBuild = dimensions == buildDimensions;
    return InterviewState(
      projectPath: projectPath,
      projectName: projectName,
      dimensions: dimensions,
      confidenceMap: {
        for (final d in dimensions) d.id: DimensionState.unknown,
      },
      turns: const [],
      openConflicts: const [],
      specGenEnabled: false,
      isLoading: false,
      currentLayer: isBuild ? 'L1' : '',
      extracted: const <String, dynamic>{
        'outcome': null,
        'primaryUser': null,
        'capabilities': <String>[],
        'chosenCapability': null,
        'demoScript': <String>[],
        'v2Seeds': <String>[],
        'platform': null,
        'identityModel': null,
        'inputModel': null,
        'outputModel': null,
        'externalServices': <Map<String, dynamic>>[],
      },
      parseDegraded: false,
    );
  }

  InterviewState copyWith({
    String? projectPath,
    String? projectName,
    List<DimensionDef>? dimensions,
    Map<String, DimensionState>? confidenceMap,
    List<InterviewTurn>? turns,
    List<ConflictItem>? openConflicts,
    bool? specGenEnabled,
    bool? isLoading,
    bool? llmUnavailable,
    String? currentLayer,
    Map<String, dynamic>? extracted,
    bool? parseDegraded,
  }) {
    return InterviewState(
      projectPath: projectPath ?? this.projectPath,
      projectName: projectName ?? this.projectName,
      dimensions: dimensions ?? this.dimensions,
      confidenceMap: confidenceMap ?? this.confidenceMap,
      turns: turns ?? this.turns,
      openConflicts: openConflicts ?? this.openConflicts,
      specGenEnabled: specGenEnabled ?? this.specGenEnabled,
      isLoading: isLoading ?? this.isLoading,
      llmUnavailable: llmUnavailable ?? this.llmUnavailable,
      currentLayer: currentLayer ?? this.currentLayer,
      extracted: extracted ?? this.extracted,
      parseDegraded: parseDegraded ?? this.parseDegraded,
    );
  }
}
