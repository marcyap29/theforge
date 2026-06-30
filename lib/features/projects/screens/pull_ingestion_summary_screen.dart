import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pull_ingestion_summary.dart';
import '../providers/providers.dart';

class PullIngestionSummaryScreen extends ConsumerWidget {
  final String projectPath;
  final String projectName;

  const PullIngestionSummaryScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(projectFileRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('$projectName — Ingestion Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              // TODO: Add export functionality
            },
          ),
        ],
      ),
      body: FutureBuilder<IngestionSummary?>(
        future: repo.readIngestionSummary(projectPath, projectName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final summary = snapshot.data;

          if (summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_outlined, size: 80),
                  const SizedBox(height: 16),
                  const Text('No ingestion summary found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(summary),
                const SizedBox(height: 24),
                _buildComponentsSection(summary),
                const SizedBox(height: 24),
                _buildDependenciesSection(summary),
                const SizedBox(height: 24),
                _buildInfrastructureSection(summary),
                const SizedBox(height: 24),
                _buildGapsSection(summary),
                const SizedBox(height: 24),
                _buildMetadataSection(summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(IngestionSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingestion Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSummaryRow('Scanned', summary.scannedAt.toIso8601String().split('T')[0]),
            _buildSummaryRow('Files scanned', '${summary.fileCount} files'),
            _buildSummaryRow('Components found', '${summary.componentCount} components'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildComponentsSection(IngestionSummary summary) {
    if (summary.components.isEmpty) {
      return const Text('No components found.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Components', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final component in summary.components)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(component.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (component.responsibilities.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Responsibilities:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(component.responsibilities),
                      ],
                    ),
                  if (component.interfaceContracts.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Interface Contracts:', style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        for (final contract in component.interfaceContracts)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Text('• ${contract.type} — ${contract.methods.map((m) => m['name']).join(', ')}'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDependenciesSection(IngestionSummary summary) {
    if (summary.dependencyList.isEmpty) {
      return const Text('No dependencies detected.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dependencies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final dep in summary.dependencyList)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(dep.source)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_right_alt, size: 16)),
                Expanded(child: Text(dep.target)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfrastructureSection(IngestionSummary summary) {
    if (summary.infrastructureChoices.isEmpty) {
      return const Text('No infrastructure patterns detected.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Infrastructure Patterns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final pattern in summary.infrastructureChoices)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${pattern.patternType}:', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Expanded(child: Text(pattern.description)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGapsSection(IngestionSummary summary) {
    if (summary.gapList.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No gaps identified — codebase is well-documented!'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gaps (Need Interview to Resolve)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 12),
        for (final gap in summary.gapList)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.help_outline, size: 16, color: Colors.orange)),
                Expanded(child: Text(gap)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetadataSection(IngestionSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Metadata', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildSummaryRow('Project path', summary.projectPath),
            _buildSummaryRow('Scanned at', summary.scannedAt.toIso8601String()),
          ],
        ),
      ),
    );
  }
}
