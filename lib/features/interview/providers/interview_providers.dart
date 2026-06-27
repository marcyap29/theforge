import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../state/interview_notifier.dart';
import '../state/interview_state.dart';

@immutable
class InterviewArgs {
  final String path;
  final String name;
  final ProjectMode mode;
  final String? priorSpecVersion;
  final String? complianceContext;

  const InterviewArgs({
    required this.path,
    required this.name,
    required this.mode,
    this.priorSpecVersion,
    this.complianceContext,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterviewArgs &&
          other.path == path &&
          other.name == name &&
          other.mode == mode &&
          other.priorSpecVersion == priorSpecVersion &&
          other.complianceContext == complianceContext);

  @override
  int get hashCode => Object.hash(path, name, mode, priorSpecVersion, complianceContext);
}

final interviewProvider =
    AsyncNotifierProvider.family<InterviewNotifier, InterviewState, InterviewArgs>(
  InterviewNotifier.new,
);
