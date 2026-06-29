import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'as_built_spec_notifier.dart';

class AsBuiltSpecScreen extends ConsumerStatefulWidget {
  const AsBuiltSpecScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  final String projectPath;
  final String projectName;

  @override
  ConsumerState<AsBuiltSpecScreen> createState() => _AsBuiltSpecScreenState();
}

class _AsBuiltSpecScreenState extends ConsumerState<AsBuiltSpecScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(asBuiltSpecProvider.notifier)
          .generate(widget.projectPath, widget.projectName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(asBuiltSpecProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Generating As-Built Spec — ${widget.projectName}'),
        automaticallyImplyLeading: false,
      ),
      body: switch (state.status) {
        AsBuiltGenStatus.idle || AsBuiltGenStatus.generating => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFFE8A04C)),
                SizedBox(height: 24),
                Text(
                  'Generating as-built spec…',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        AsBuiltGenStatus.done => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle,
                    size: 80, color: Color(0xFF22C55E)),
                const SizedBox(height: 16),
                Text(
                  state.specFilename ?? 'AsBuiltSpec_v1.md',
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 14,
                    color: Color(0xFFE5E5E7),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'As-built spec generated.',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Back to Projects'),
                ),
              ],
            ),
          ),
        AsBuiltGenStatus.error => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 80, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.errorMessage ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontFamily: 'Menlo'),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: const Text('Back to Projects'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => ref
                          .read(asBuiltSpecProvider.notifier)
                          .generate(widget.projectPath, widget.projectName),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A04C),
                        foregroundColor: const Color(0xFF0F0F10),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      },
    );
  }
}
