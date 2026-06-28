import 'package:flutter/foundation.dart';

import '../../../data/filesystem/project_file_repository.dart';

@immutable
class DimensionDef {
  final String id;
  final String label;
  final String question;
  const DimensionDef({
    required this.id,
    required this.label,
    required this.question,
  });
}

const buildDimensions = <DimensionDef>[
  DimensionDef(
    id: 'corePurpose',
    label: 'Core purpose',
    question: 'What is the single primary job this product does?',
  ),
  DimensionDef(
    id: 'primaryUser',
    label: 'Primary user',
    question: 'Who is this built for first?',
  ),
  DimensionDef(
    id: 'identityModel',
    label: 'Identity model',
    question: 'Are accounts required, optional, or none?',
  ),
  DimensionDef(
    id: 'inputModel',
    label: 'Input model',
    question: 'What does the user interact with?',
  ),
  DimensionDef(
    id: 'outputModel',
    label: 'Output model',
    question: 'What does the product produce?',
  ),
  DimensionDef(
    id: 'platform',
    label: 'Platform',
    question: 'What does it run on?',
  ),
  DimensionDef(
    id: 'scopeBoundary',
    label: 'Scope boundary',
    question: 'What is explicitly out of scope for v1?',
  ),
  DimensionDef(
    id: 'externalServices',
    label: 'External services',
    question: 'What third-party APIs or services does it touch?',
  ),
];

const auditDimensions = <DimensionDef>[
  DimensionDef(
    id: 'projectGoal',
    label: 'Project goal',
    question: 'What is this project actually trying to do, stated plainly?',
  ),
  DimensionDef(
    id: 'currentBuildState',
    label: 'Current build state',
    question: 'What is shipped, in progress, and not started?',
  ),
  DimensionDef(
    id: 'featureOwnership',
    label: 'Feature ownership',
    question: 'Which engineer or sub-team owns each feature or component?',
  ),
  DimensionDef(
    id: 'activeBlockers',
    label: 'Active blockers',
    question: 'What is currently stuck, and for how long?',
  ),
  DimensionDef(
    id: 'blockerBlastRadius',
    label: 'Blocker blast radius',
    question: 'Which teams or features are blocked downstream of each blocker?',
  ),
  DimensionDef(
    id: 'decisionDebt',
    label: 'Decision debt',
    question: 'What architectural decisions were made without documentation?',
  ),
  DimensionDef(
    id: 'technicalDebt',
    label: 'Technical debt',
    question:
        'What known shortcuts or deferred fixes exist, and who knows about them?',
  ),
  DimensionDef(
    id: 'aiAndTokenUsage',
    label: 'AI & token usage',
    question:
        'Which engineers are using AI agents, on what tasks, and at what spend?',
  ),
];

List<DimensionDef> dimensionsFor(ProjectMode mode) {
  switch (mode) {
    case ProjectMode.build:
      return buildDimensions;
    case ProjectMode.audit:
      return auditDimensions;
    case ProjectMode.reverse:
      // Reverse Mode doesn't use the Build/Audit interview flow
      // This is a fallback - Reverse Mode projects should use codebase ingestion first
      return auditDimensions;
  }
}

@immutable
class LayerDef {
  final String id;
  final String label;
  final String purpose;
  const LayerDef({
    required this.id,
    required this.label,
    required this.purpose,
  });
}

const buildLayers = <LayerDef>[
  LayerDef(
    id: 'L1',
    label: 'Outcome',
    purpose:
        'The one thing this app does for its user that nothing they use today does.',
  ),
  LayerDef(
    id: 'L2',
    label: 'Decomposition',
    purpose: '3 to 5 capabilities required to deliver the outcome.',
  ),
  LayerDef(
    id: 'L3',
    label: 'PoC Reduction',
    purpose:
        'One capability chosen as the proof; a 3 to 5 step demo script bounds V1.',
  ),
  LayerDef(
    id: 'L4',
    label: 'Critical Path',
    purpose:
        'Platform, identity, IO, services deduced from the demo; blockers stripped.',
  ),
];
