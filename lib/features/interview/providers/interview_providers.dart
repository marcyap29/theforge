import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/interview_notifier.dart';
import '../state/interview_state.dart';

@immutable
class InterviewArgs {
  final String path;
  final String name;

  const InterviewArgs({required this.path, required this.name});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterviewArgs && other.path == path && other.name == name);

  @override
  int get hashCode => Object.hash(path, name);
}

final interviewProvider =
    AsyncNotifierProvider.family<InterviewNotifier, InterviewState, InterviewArgs>(
  InterviewNotifier.new,
);
