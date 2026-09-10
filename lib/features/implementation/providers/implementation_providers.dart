import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_service_provider.dart';
import '../data/impl_agent.dart';

/// Gates the paid "Build with AI" feature. Stubbed to always-on for now; will be
/// wired to the managed backend / entitlement check per the monetization plan.
final entitlementProvider = Provider<bool>((ref) => true);

final implAgentProvider = Provider<ImplAgent>(
  (ref) => ImplAgent(ref.watch(llmServiceProvider)),
);
