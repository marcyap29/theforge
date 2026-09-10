import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_service_provider.dart';
import '../data/impl_agent.dart';
import '../models/run_session.dart';

/// Gates the paid "Build with AI" feature. Stubbed to always-on for now; will be
/// wired to the managed backend / entitlement check per the monetization plan.
final entitlementProvider = Provider<bool>((ref) => true);

final implAgentProvider = Provider<ImplAgent>(
  (ref) => ImplAgent(ref.watch(llmServiceProvider)),
);

/// App-level registry of which features currently have a live implementation
/// run, and their phase. The tracker board watches this to show a status dot
/// per feature — so a build stays visible even after the window is closed.
final implActiveRunsProvider =
    NotifierProvider<ImplActiveRuns, Map<String, RunPhase>>(ImplActiveRuns.new);

class ImplActiveRuns extends Notifier<Map<String, RunPhase>> {
  @override
  Map<String, RunPhase> build() => const {};

  void set(String featureId, RunPhase phase) {
    state = {...state, featureId: phase};
  }

  RunPhase? phaseFor(String featureId) => state[featureId];
}
