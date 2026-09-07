import 'package:flutter/material.dart';

/// Lifecycle status of a tracked [Feature]. Stored as the enum name string in
/// the drift DB and the JSON mirror.
enum FeatureStatus {
  idea,
  planned,
  inProgress,
  blocked,
  shipped,
  archived;

  /// The string persisted to the DB / JSON. Uses snake_case for the multi-word
  /// value so it reads cleanly in stored files.
  String get wire => switch (this) {
        FeatureStatus.inProgress => 'in_progress',
        _ => name,
      };

  static FeatureStatus fromWire(String? value) {
    switch (value) {
      case 'idea':
        return FeatureStatus.idea;
      case 'planned':
        return FeatureStatus.planned;
      case 'in_progress':
      case 'inProgress':
        return FeatureStatus.inProgress;
      case 'blocked':
        return FeatureStatus.blocked;
      case 'shipped':
        return FeatureStatus.shipped;
      case 'archived':
        return FeatureStatus.archived;
      default:
        return FeatureStatus.planned;
    }
  }

  String get label => switch (this) {
        FeatureStatus.idea => 'Idea',
        FeatureStatus.planned => 'Planned',
        FeatureStatus.inProgress => 'In Progress',
        FeatureStatus.blocked => 'Blocked',
        FeatureStatus.shipped => 'Shipped',
        FeatureStatus.archived => 'Archived',
      };

  Color get color => switch (this) {
        FeatureStatus.idea => const Color(0xFF9E9E9E),
        FeatureStatus.planned => const Color(0xFF64B5F6),
        FeatureStatus.inProgress => const Color(0xFFFFB74D),
        FeatureStatus.blocked => const Color(0xFFE57373),
        FeatureStatus.shipped => const Color(0xFF81C784),
        FeatureStatus.archived => const Color(0xFF616161),
      };

  bool get isActive =>
      this != FeatureStatus.shipped && this != FeatureStatus.archived;

  /// Display / board column ordering.
  static const List<FeatureStatus> board = [
    FeatureStatus.idea,
    FeatureStatus.planned,
    FeatureStatus.inProgress,
    FeatureStatus.blocked,
    FeatureStatus.shipped,
    FeatureStatus.archived,
  ];
}

/// Overall status of a project in the portfolio.
enum ProjectStatus {
  active,
  paused,
  shipped,
  archived;

  String get wire => name;

  static ProjectStatus fromWire(String? value) {
    switch (value) {
      case 'active':
        return ProjectStatus.active;
      case 'paused':
        return ProjectStatus.paused;
      case 'shipped':
        return ProjectStatus.shipped;
      case 'archived':
        return ProjectStatus.archived;
      default:
        return ProjectStatus.active;
    }
  }

  String get label => switch (this) {
        ProjectStatus.active => 'Active',
        ProjectStatus.paused => 'Paused',
        ProjectStatus.shipped => 'Shipped',
        ProjectStatus.archived => 'Archived',
      };

  Color get color => switch (this) {
        ProjectStatus.active => const Color(0xFF81C784),
        ProjectStatus.paused => const Color(0xFFFFB74D),
        ProjectStatus.shipped => const Color(0xFF64B5F6),
        ProjectStatus.archived => const Color(0xFF616161),
      };

  static const List<ProjectStatus> all = [
    ProjectStatus.active,
    ProjectStatus.paused,
    ProjectStatus.shipped,
    ProjectStatus.archived,
  ];
}
