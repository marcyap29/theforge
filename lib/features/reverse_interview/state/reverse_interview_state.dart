import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reverse_interview_notifier.dart';

@immutable
class ReverseInterviewTurn {
  final bool isUser;
  final String text;

  const ReverseInterviewTurn({required this.isUser, required this.text});
}

@immutable
class ReverseInterviewState {
  final String projectPath;
  final String projectName;
  final List<ReverseInterviewTurn> turns;
  final bool isLoading;
  final bool isComplete;
  final String? error;

  const ReverseInterviewState({
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

  ReverseInterviewState copyWith({
    List<ReverseInterviewTurn>? turns,
    bool? isLoading,
    bool? isComplete,
    String? error,
  }) =>
      ReverseInterviewState(
        projectPath: projectPath,
        projectName: projectName,
        turns: turns ?? this.turns,
        isLoading: isLoading ?? this.isLoading,
        isComplete: isComplete ?? this.isComplete,
        error: error,
      );
}

@immutable
class ReverseInterviewArgs {
  final String projectPath;
  final String projectName;

  const ReverseInterviewArgs({
    required this.projectPath,
    required this.projectName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReverseInterviewArgs &&
          other.projectPath == projectPath &&
          other.projectName == projectName);

  @override
  int get hashCode => Object.hash(projectPath, projectName);
}

// Provider declared ONLY in this file. The screen and notifier import it from here.
// Riverpod pair: FamilyAsyncNotifier<T,Arg> ↔ AsyncNotifierProvider.family<N,T,Arg>
final reverseInterviewProvider = AsyncNotifierProvider.family<
    ReverseInterviewNotifier,
    ReverseInterviewState,
    ReverseInterviewArgs>(
  ReverseInterviewNotifier.new,
);
