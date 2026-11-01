import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../../projects/providers/providers.dart';
import '../data/prompt_generator.dart';

final promptGeneratorProvider = Provider<PromptGenerator>((ref) {
  return PromptGenerator(ref.watch(llmServiceProvider));
});

final promptHistoryProvider = FutureProvider.family<List<PromptRecord>,
    ({String projectId, String featureId})>((ref, args) {
  final db = ref.watch(forgeDatabaseProvider);
  return db.getPromptRecordsForFeature(args.projectId, args.featureId);
});
