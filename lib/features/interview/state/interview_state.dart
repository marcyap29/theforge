import 'package:flutter/foundation.dart';

enum ConfidenceDimension {
  corePurpose,
  primaryUser,
  identityModel,
  inputModel,
  outputModel,
  platform,
  scopeBoundary,
  externalServices,
}

enum DimensionState { unknown, partial, resolved }

extension ConfidenceDimensionLabel on ConfidenceDimension {
  String get label {
    switch (this) {
      case ConfidenceDimension.corePurpose:
        return 'Core purpose';
      case ConfidenceDimension.primaryUser:
        return 'Primary user';
      case ConfidenceDimension.identityModel:
        return 'Identity model';
      case ConfidenceDimension.inputModel:
        return 'Input model';
      case ConfidenceDimension.outputModel:
        return 'Output model';
      case ConfidenceDimension.platform:
        return 'Platform';
      case ConfidenceDimension.scopeBoundary:
        return 'Scope boundary';
      case ConfidenceDimension.externalServices:
        return 'External services';
    }
  }

  String get question {
    switch (this) {
      case ConfidenceDimension.corePurpose:
        return 'What is the single primary job this product does?';
      case ConfidenceDimension.primaryUser:
        return 'Who is this built for first?';
      case ConfidenceDimension.identityModel:
        return 'Are accounts required, optional, or none?';
      case ConfidenceDimension.inputModel:
        return 'What does the user interact with?';
      case ConfidenceDimension.outputModel:
        return 'What does the product produce?';
      case ConfidenceDimension.platform:
        return 'What does it run on?';
      case ConfidenceDimension.scopeBoundary:
        return 'What is explicitly out of scope for v1?';
      case ConfidenceDimension.externalServices:
        return 'What third-party APIs or services does it touch?';
    }
  }
}

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
  final ConfidenceDimension dimensionA;
  final ConfidenceDimension dimensionB;
  final String description;
  final String recommendation;

  const ConflictItem({
    required this.id,
    required this.dimensionA,
    required this.dimensionB,
    required this.description,
    required this.recommendation,
  });
}

@immutable
class InterviewState {
  final String projectPath;
  final String projectName;
  final Map<ConfidenceDimension, DimensionState> confidenceMap;
  final List<InterviewTurn> turns;
  final List<ConflictItem> openConflicts;
  final bool specGenEnabled;
  final bool isLoading;

  const InterviewState({
    required this.projectPath,
    required this.projectName,
    required this.confidenceMap,
    required this.turns,
    required this.openConflicts,
    required this.specGenEnabled,
    required this.isLoading,
  });

  factory InterviewState.empty(String projectPath, String projectName) {
    final map = <ConfidenceDimension, DimensionState>{
      for (final d in ConfidenceDimension.values) d: DimensionState.unknown,
    };
    return InterviewState(
      projectPath: projectPath,
      projectName: projectName,
      confidenceMap: map,
      turns: const [],
      openConflicts: const [],
      specGenEnabled: false,
      isLoading: false,
    );
  }

  InterviewState copyWith({
    String? projectPath,
    String? projectName,
    Map<ConfidenceDimension, DimensionState>? confidenceMap,
    List<InterviewTurn>? turns,
    List<ConflictItem>? openConflicts,
    bool? specGenEnabled,
    bool? isLoading,
  }) {
    return InterviewState(
      projectPath: projectPath ?? this.projectPath,
      projectName: projectName ?? this.projectName,
      confidenceMap: confidenceMap ?? this.confidenceMap,
      turns: turns ?? this.turns,
      openConflicts: openConflicts ?? this.openConflicts,
      specGenEnabled: specGenEnabled ?? this.specGenEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
