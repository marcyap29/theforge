import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_service_provider.dart';
import '../data/architecture_analyst.dart';

final architectureAnalystProvider = Provider<ArchitectureAnalyst>((ref) {
  return ArchitectureAnalyst(ref.watch(llmServiceProvider));
});
