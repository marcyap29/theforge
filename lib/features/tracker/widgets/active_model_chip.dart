import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';

/// A compact, always-visible indicator of which model is currently doing the
/// work (the executor role — what Build with AI uses). Tapping it opens
/// Settings to change the model. Shown in the tracker/dashboard app bars so the
/// active model is visible without opening the model picker.
class ActiveModelChip extends ConsumerWidget {
  const ActiveModelChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(llmServiceProvider).resolve(LlmRole.executor);
    if (resolved == null || resolved.modelId.isEmpty) {
      return const SizedBox.shrink();
    }
    final label = '${resolved.provider.name} · ${resolved.modelId}';
    return Tooltip(
      message: 'Active model (executor). Tap to change in Settings.',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed('/settings'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.memory, size: 13, color: Color(0xFF8A8A8E)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Menlo', fontSize: 11.5, color: Color(0xFFCFCFD2)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
