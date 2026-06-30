import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pull_interview_notifier.dart';

@immutable
class PullInterviewTurn {
  final bool isUser;
  final String text;

  const PullInterviewTurn({required this.isUser, required this.text});
}

@immutable
class PullInterviewState {
  final String projectPath;
  final String projectName;
  final List<PullInterviewTurn> turns;
  final bool isLoading;
  final bool isComplete;
  final String? error;

  const PullInterviewState({
    required this.projectPath,
    required this.projectName,
    this.turns = const [],
    this.isLoading = false,
    this.isComplete = false,
    this.error,
  });

  // Enabled after 4 user turns or when complete
  bool get canGenerateSpec =>
      turns.where((t) => t.isUser).length >= 4 || isComplete;

  PullInterviewState copyWith({
    List<PullInterviewTurn>? turns,
    bool? isLoading,
    bool? isComplete,
    String? error,
  }) =>
      PullInterviewState(
        projectPath: projectPath,
        projectName: projectName,
        turns: turns ?? this.turns,
        isLoading: isLoading ?? this.isLoading,
        isComplete: isComplete ?? this.isComplete,
        error: error,
      );
}

@immutable
class PullInterviewArgs {
  final String projectPath;
  final String projectName;

  const PullInterviewArgs({
    required this.projectPath,
    required this.projectName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PullInterviewArgs &&
          other.projectPath == projectPath &&
          other.projectName == projectName);

  @override
  int get hashCode => Object.hash(projectPath, projectName);
}

// Provider declared ONLY in this file. The screen and notifier import it from here.
// Riverpod pair: FamilyAsyncNotifier<T,Arg> ↔ AsyncNotifierProvider.family<N,T,Arg>
final pullInterviewProvider = AsyncNotifierProvider.family<
    PullInterviewNotifier,
    PullInterviewState,
    PullInterviewArgs>(
  PullInterviewNotifier.new,
);
