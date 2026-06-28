import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'decision_models.dart';
import 'decision_notifier.dart';

class DecisionScreen extends ConsumerStatefulWidget {
  const DecisionScreen({super.key});

  @override
  ConsumerState<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends ConsumerState<DecisionScreen> {
  final _questionCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  final _option1Ctrl = TextEditingController();
  final _option2Ctrl = TextEditingController();
  final _option3Ctrl = TextEditingController();

  @override
  void dispose() {
    _questionCtrl.dispose();
    _contextCtrl.dispose();
    _option1Ctrl.dispose();
    _option2Ctrl.dispose();
    _option3Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decisionAsync = ref.watch(decisionProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Decision Simulation'),
      ),
      body: decisionAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFE8A04C)),
              SizedBox(height: 16),
              Text(
                'Running 50 simulations...',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 13,
                  fontFamily: 'Menlo',
                ),
              ),
            ],
          ),
        ),
        error: (e, _) => _buildError(e.toString()),
        data: (result) =>
            result == null ? _buildForm() : _buildResult(result),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _questionCtrl,
          decoration: const InputDecoration(
            labelText: 'Decision question',
            hintText: 'What should we do about X?',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF9CA3AF)),
            hintStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF6B7280)),
          ),
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contextCtrl,
          decoration: const InputDecoration(
            labelText: 'Context & constraints',
            hintText: 'Any relevant details or constraints...',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF9CA3AF)),
            hintStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF6B7280)),
          ),
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _option1Ctrl,
          decoration: const InputDecoration(
            labelText: 'Option 1',
            hintText: 'First option...',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF9CA3AF)),
            hintStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF6B7280)),
          ),
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
          maxLines: 1,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _option2Ctrl,
          decoration: const InputDecoration(
            labelText: 'Option 2',
            hintText: 'Second option...',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF9CA3AF)),
            hintStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF6B7280)),
          ),
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
          maxLines: 1,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _option3Ctrl,
          decoration: const InputDecoration(
            labelText: 'Option 3 (optional)',
            hintText: 'Third option (optional)...',
            border: OutlineInputBorder(),
            labelStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF9CA3AF)),
            hintStyle: TextStyle(fontFamily: 'Menlo', color: Color(0xFF6B7280)),
          ),
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 13, color: Color(0xFFE5E5E7)),
          maxLines: 1,
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            final options = [
              _option1Ctrl.text.trim(),
              _option2Ctrl.text.trim(),
              _option3Ctrl.text.trim(),
            ].where((o) => o.isNotEmpty).toList();
            if (_questionCtrl.text.trim().isEmpty || options.isEmpty) return;
            ref.read(decisionProvider.notifier).runSimulation(
              DecisionInput(
                question: _questionCtrl.text.trim(),
                context: _contextCtrl.text.trim(),
                options: options,
              ),
            );
          },
          child: const Text('RUN SIMULATION →'),
        ),
      ],
    );
  }

  Widget _buildResult(DecisionResult result) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: SelectableText(
            result.markdown,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 13,
              color: Color(0xFFE5E5E7),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => ref.read(decisionProvider.notifier).reset(),
          child: const Text('NEW SIMULATION'),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
                fontFamily: 'Menlo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.read(decisionProvider.notifier).reset(),
              child: const Text('BACK TO FORM'),
            ),
          ],
        ),
      ),
    );
  }
}
