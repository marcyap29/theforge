import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../features/interview/providers/interview_providers.dart';
import '../../../features/interview/ui/interview_screen.dart';
import '../compliance/spec_compliance_models.dart';
import '../compliance/spec_compliance_notifier.dart';

class SpecComplianceScreen extends ConsumerWidget {
  final String projectPath;
  final String projectName;
  final String priorSpecVersion;
  final String nextVersion;
  final ProjectMode mode;

  const SpecComplianceScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
    required this.priorSpecVersion,
    required this.nextVersion,
    required this.mode,
  });

  ({String projectPath, String projectName, String priorSpecVersion}) get _args => (
        projectPath: projectPath,
        projectName: projectName,
        priorSpecVersion: priorSpecVersion,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complianceNotifier = ref.read(specComplianceProvider(_args).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('${priorSpecVersion.toUpperCase()} Compliance Check'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final result = ref.watch(specComplianceProvider(_args));

          return result.when(
            data: (data) {
              if (data == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  complianceNotifier.check(_args);
                });
                return const Center(child: CircularProgressIndicator());
              }
              return _buildComplianceContent(context, ref, data);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Check failed'),
                  TextButton(
                    onPressed: () => complianceNotifier.check(_args),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildComplianceContent(BuildContext context, WidgetRef ref, SpecComplianceResult result) {
    final verifiedCount = result.verified.length;
    final uncertainCount = result.uncertain.length;
    final failedCount = result.failed.length;
    final skipCount = result.skipToLlm.length;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${priorSpecVersion.toUpperCase()} Build Compliance Summary',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$verifiedCount/${result.total} verified · $uncertainCount uncertain · $failedCount failed · $skipCount skipped to LLM',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 16),
              if (result.passedAutoCheck)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'All auto-checks passed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Some auto-checks failed or are uncertain',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Detailed Results',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        _buildComplianceTable(result),
        const SizedBox(height: 24),
        _buildFooterButtons(context, result),
      ],
    );
  }
  
  Widget _buildComplianceTable(SpecComplianceResult result) {
    final allItems = [
      ...result.verified,
      ...result.uncertain,
      ...result.failed,
      ...result.skipToLlm,
    ];
    
    return Column(
      children: allItems.map((item) {
        return _buildComplianceRow(item);
      }).toList(),
    );
  }
  
  Widget _buildComplianceRow(ComponentCompliance item) {
    final statusIcon = switch (item.status) {
      ComplianceStatus.verified => const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
      ComplianceStatus.uncertain => const Icon(Icons.warning, color: Color(0xFFF59E0B), size: 18),
      ComplianceStatus.failed => const Icon(Icons.error, color: Color(0xFFEF4444), size: 18),
      ComplianceStatus.skipToLlm => const Icon(Icons.arrow_right, color: Color(0xFF6B7280), size: 18),
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                statusIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.item.requirement,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.evidence.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF171718),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Evidence:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.evidence.join(', '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildFooterButtons(BuildContext context, SpecComplianceResult result) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => _buildInterviewScreen(context, result),
                ),
              );
            },
            child: Text('Continue to ${nextVersion.toUpperCase()} Interview →'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => _buildInterviewScreen(context, null),
              ),
            );
          },
          child: const Text('Skip →'),
        ),
      ],
    );
  }
  
  Widget _buildInterviewScreen(BuildContext context, SpecComplianceResult? result) {
    // Navigate to interview screen with appropriate parameters
    final complianceContext = result?.toComplianceContext();
    
    return InterviewScreen(
      args: InterviewArgs(
        path: projectPath,
        name: projectName,
        mode: mode,
        priorSpecVersion: priorSpecVersion,
        complianceContext: complianceContext,
      ),
    );
  }
}

