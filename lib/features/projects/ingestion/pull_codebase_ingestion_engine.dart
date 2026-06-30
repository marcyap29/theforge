import 'dart:convert';

import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service.dart';
import '../models/pull_ingestion_summary.dart';

const _extractionPrompt = '''
You are a codebase structure analyzer. Extract component metadata from the provided Dart file.

Output JSON with this structure:
{
  "componentName": "string or null",
  "responsibilities": "string",
  "interfaceContracts": [
    {
      "type": "class | interface | mixin",
      "methods": [
        {"name": "string", "params": "string", "returnType": "string"}
      ],
      "properties": [
        {"name": "string", "type": "string"}
      ]
    }
  ],
  "externalDependencies": [
    {
      "source": "string",
      "target": "string",
      "relationshipType": "imports | extends | implements | uses"
    }
  ],
  "infrastructurePatterns": [
    {
      "patternType": "string",
      "description": "string"
    }
  ]
}
''';

String buildIngestionPrompt(String filePath, String fileContent) {
  return 'FILE: $filePath\n\n$fileContent\n\n$_extractionPrompt';
}

ComponentInfo? parseComponentInfo(String filePath, String raw) {
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final interfaceContracts = <InterfaceContract>[];
    if (json['interfaceContracts'] is List<dynamic>) {
      for (final item in json['interfaceContracts'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          final methods = <Map<String, dynamic>>[];
          if (item['methods'] is List<dynamic>) {
            for (final m in item['methods'] as List<dynamic>) {
              if (m is Map<String, dynamic>) {
                methods.add({
                  'name': m['name'] as String? ?? '',
                  'params': m['params'] as String? ?? '',
                  'returnType': m['returnType'] as String? ?? 'void',
                });
              }
            }
          }

          final properties = <Map<String, dynamic>>[];
          if (item['properties'] is List<dynamic>) {
            for (final p in item['properties'] as List<dynamic>) {
              if (p is Map<String, dynamic>) {
                properties.add({
                  'name': p['name'] as String? ?? '',
                  'type': p['type'] as String? ?? '',
                });
              }
            }
          }

          interfaceContracts.add(InterfaceContract(
            type: item['type'] as String? ?? 'unknown',
            methods: methods,
            properties: properties,
          ));
        }
      }
    }

    final externalDependencies = <DependencyInfo>[];
    if (json['externalDependencies'] is List<dynamic>) {
      for (final item in json['externalDependencies'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          externalDependencies.add(DependencyInfo(
            source: item['source'] as String? ?? '',
            target: item['target'] as String? ?? '',
            relationshipType: item['relationshipType'] as String? ?? 'unknown',
            isLocal: item['isLocal'] as bool? ?? false,
            isPackage: item['isPackage'] as bool? ?? false,
            isRemote: item['isRemote'] as bool? ?? false,
          ));
        }
      }
    }

    final infrastructurePatterns = <InfrastructurePattern>[];
    if (json['infrastructurePatterns'] is List<dynamic>) {
      for (final item in json['infrastructurePatterns'] as List<dynamic>) {
        if (item is Map<String, dynamic>) {
          infrastructurePatterns.add(InfrastructurePattern(
            patternType: item['patternType'] as String? ?? 'unknown',
            description: item['description'] as String? ?? '',
          ));
        }
      }
    }

    return ComponentInfo(
      name: json['componentName'] as String? ?? '',
      responsibilities: json['responsibilities'] as String? ?? '',
      interfaceContracts: interfaceContracts,
      externalDependencies: externalDependencies,
      infrastructurePatterns: infrastructurePatterns,
    );
  } catch (e) {
    return null;
  }
}

Future<List<ComponentInfo>> extractComponentInfo(
    LlmService service, String filePath, String fileContent) async {
  final prompt = buildIngestionPrompt(filePath, fileContent);

  final response = await service.complete(
    role: LlmRole.architect,
    systemPrompt: 'You are a codebase structure analyzer.',
    userPrompt: prompt,
    temperature: 0.2,
    maxTokens: 4096,
  );

  final component = parseComponentInfo(filePath, response);
  return component != null ? [component] : [];
}

Future<List<ComponentInfo>> analyzeFileBatch(
    LlmService service, List<Map<String, dynamic>> files) async {
  final allComponents = <ComponentInfo>[];

  for (final file in files) {
    final filePath = file['filePath'] as String;
    final content = file['content'] as String;

    try {
      final components = await extractComponentInfo(service, filePath, content);
      allComponents.addAll(components);
    } catch (e) {
      continue;
    }
  }

  return allComponents;
}

IngestionSummary aggregateComponents({
  required String projectName,
  required String projectPath,
  required int fileCount,
  required List<ComponentInfo> components,
  required List<DependencyInfo> dependencies,
  required List<InfrastructurePattern> patterns,
  required List<String> gaps,
}) {
  return IngestionSummary(
    projectName: projectName,
    projectPath: projectPath,
    scannedAt: DateTime.now(),
    fileCount: fileCount,
    componentCount: components.length,
    components: components,
    dependencyList: dependencies,
    infrastructureChoices: patterns,
    gapList: gaps,
  );
}

List<String> identifyGaps(List<ComponentInfo> components) {
  final gaps = <String>[];

  for (final component in components) {
    if (component.name.isEmpty) {
      gaps.add('Component name not determined for ${component.responsibilities.substring(0, 50)}...');
    }
    if (component.interfaceContracts.isEmpty) {
      gaps.add('No interface contracts found for component "${component.name.isNotEmpty ? component.name : 'unnamed'}"');
    }
    if (component.externalDependencies.isEmpty) {
      gaps.add('No external dependencies found for component "${component.name.isNotEmpty ? component.name : 'unnamed'}" — may have hidden API calls');
    }
  }

  return gaps;
}
