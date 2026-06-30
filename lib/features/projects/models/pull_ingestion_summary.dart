import 'package:flutter/foundation.dart';

enum IngestionState { idle, scanning, processing, aggregating, done, error }

@immutable
class ComponentInfo {
  final String name;
  final String responsibilities;
  final List<InterfaceContract> interfaceContracts;
  final List<DependencyInfo> externalDependencies;
  final List<InfrastructurePattern> infrastructurePatterns;

  const ComponentInfo({
    required this.name,
    required this.responsibilities,
    required this.interfaceContracts,
    required this.externalDependencies,
    required this.infrastructurePatterns,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'responsibilities': responsibilities,
        'interfaceContracts': interfaceContracts.map((e) => e.toJson()).toList(),
        'externalDependencies': externalDependencies.map((e) => e.toJson()).toList(),
        'infrastructurePatterns': infrastructurePatterns.map((e) => e.toJson()).toList(),
      };

  factory ComponentInfo.fromJson(Map<String, dynamic> json) => ComponentInfo(
        name: json['name'] as String,
        responsibilities: json['responsibilities'] as String,
        interfaceContracts: (json['interfaceContracts'] as List<dynamic>)
            .map((e) => InterfaceContract.fromJson(e as Map<String, dynamic>))
            .toList(),
        externalDependencies: (json['externalDependencies'] as List<dynamic>)
            .map((e) => DependencyInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        infrastructurePatterns: (json['infrastructurePatterns'] as List<dynamic>)
            .map((e) => InfrastructurePattern.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

@immutable
class InterfaceContract {
  final String type;
  final List<Map<String, dynamic>> methods;
  final List<Map<String, dynamic>> properties;

  const InterfaceContract({
    required this.type,
    required this.methods,
    required this.properties,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'methods': methods,
        'properties': properties,
      };

  factory InterfaceContract.fromJson(Map<String, dynamic> json) => InterfaceContract(
        type: json['type'] as String,
        methods: (json['methods'] as List<dynamic>).cast<Map<String, dynamic>>(),
        properties: (json['properties'] as List<dynamic>).cast<Map<String, dynamic>>(),
      );
}

@immutable
class DependencyInfo {
  final String source;
  final String target;
  final String relationshipType;
  final bool isLocal;
  final bool isPackage;
  final bool isRemote;

  const DependencyInfo({
    required this.source,
    required this.target,
    required this.relationshipType,
    required this.isLocal,
    required this.isPackage,
    required this.isRemote,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        'relationshipType': relationshipType,
        'isLocal': isLocal,
        'isPackage': isPackage,
        'isRemote': isRemote,
      };

  factory DependencyInfo.fromJson(Map<String, dynamic> json) => DependencyInfo(
        source: json['source'] as String,
        target: json['target'] as String,
        relationshipType: json['relationshipType'] as String,
        isLocal: (json['isLocal'] as bool?) ?? false,
        isPackage: (json['isPackage'] as bool?) ?? false,
        isRemote: (json['isRemote'] as bool?) ?? false,
      );
}

@immutable
class InfrastructurePattern {
  final String patternType;
  final String description;

  const InfrastructurePattern({
    required this.patternType,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'patternType': patternType,
        'description': description,
      };

  factory InfrastructurePattern.fromJson(Map<String, dynamic> json) => InfrastructurePattern(
        patternType: json['patternType'] as String,
        description: json['description'] as String,
      );
}

class IngestionSummary {
  final String projectName;
  final String projectPath;
  final DateTime scannedAt;
  final int fileCount;
  final int componentCount;
  final List<ComponentInfo> components;
  final List<DependencyInfo> dependencyList;
  final List<InfrastructurePattern> infrastructureChoices;
  final List<String> gapList;

  const IngestionSummary({
    required this.projectName,
    required this.projectPath,
    required this.scannedAt,
    required this.fileCount,
    required this.componentCount,
    required this.components,
    required this.dependencyList,
    required this.infrastructureChoices,
    required this.gapList,
  });

  Map<String, dynamic> toJson() => {
        'projectName': projectName,
        'projectPath': projectPath,
        'scannedAt': scannedAt.toIso8601String(),
        'fileCount': fileCount,
        'componentCount': componentCount,
        'components': components.map((e) => e.toJson()).toList(),
        'dependencyList': dependencyList.map((e) => e.toJson()).toList(),
        'infrastructureChoices': infrastructureChoices.map((e) => e.toJson()).toList(),
        'gapList': gapList,
      };

  factory IngestionSummary.fromJson(Map<String, dynamic> json) => IngestionSummary(
        projectName: json['projectName'] as String,
        projectPath: json['projectPath'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        fileCount: json['fileCount'] as int,
        componentCount: json['componentCount'] as int,
        components: (json['components'] as List<dynamic>)
            .map((e) => ComponentInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        dependencyList: (json['dependencyList'] as List<dynamic>)
            .map((e) => DependencyInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        infrastructureChoices: (json['infrastructureChoices'] as List<dynamic>)
            .map((e) => InfrastructurePattern.fromJson(e as Map<String, dynamic>))
            .toList(),
        gapList: (json['gapList'] as List<dynamic>).cast<String>(),
      );

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# $projectName — Codebase Ingestion Summary\n');
    buffer.writeln('**Scanned:** ${scannedAt.toIso8601String()}\n');
    buffer.writeln('**Files scanned:** $fileCount\n');
    buffer.writeln('**Components found:** $componentCount\n');

    buffer.writeln('## Components\n');
    for (final component in components) {
      buffer.writeln('### ${component.name}\n');
      buffer.writeln('${component.responsibilities}\n');
      if (component.interfaceContracts.isNotEmpty) {
        buffer.writeln('**Interface Contracts:**\n');
        for (final contract in component.interfaceContracts) {
          buffer.writeln('- Type: ${contract.type}');
          if (contract.methods.isNotEmpty) {
            buffer.writeln('  - Methods:');
            for (final method in contract.methods) {
              buffer.writeln('    - ${method['name'] ?? 'unknown'}(${method['params'] ?? ''}): ${method['returnType'] ?? 'void'}');
            }
          }
          buffer.writeln();
        }
      }
      if (component.externalDependencies.isNotEmpty) {
        buffer.writeln('**External Dependencies:**\n');
        for (final dep in component.externalDependencies) {
          buffer.writeln('- ${dep.source} → ${dep.target} (${dep.relationshipType})');
        }
        buffer.writeln();
      }
      if (component.infrastructurePatterns.isNotEmpty) {
        buffer.writeln('**Infrastructure Patterns:**\n');
        for (final pattern in component.infrastructurePatterns) {
          buffer.writeln('- ${pattern.patternType}: ${pattern.description}');
        }
        buffer.writeln();
      }
    }

    if (dependencyList.isNotEmpty) {
      buffer.writeln('## Dependencies\n');
      for (final dep in dependencyList) {
        buffer.writeln('- ${dep.source} → ${dep.target} (${dep.relationshipType})');
      }
      buffer.writeln();
    }

    if (infrastructureChoices.isNotEmpty) {
      buffer.writeln('## Infrastructure Choices\n');
      for (final pattern in infrastructureChoices) {
        buffer.writeln('- ${pattern.patternType}: ${pattern.description}');
      }
      buffer.writeln();
    }

    if (gapList.isNotEmpty) {
      buffer.writeln('## Gaps (Need Interview to Resolve)\n');
      for (final gap in gapList) {
        buffer.writeln('- $gap');
      }
    }

    return buffer.toString();
  }
}
