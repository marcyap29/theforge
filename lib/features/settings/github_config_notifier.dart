import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

@immutable
class GitHubEngineerMapping {
  final String handle;
  final String githubLogin;

  const GitHubEngineerMapping({
    required this.handle,
    required this.githubLogin,
  });

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'githubLogin': githubLogin,
      };

  factory GitHubEngineerMapping.fromJson(Map<String, dynamic> json) {
    return GitHubEngineerMapping(
      handle: json['handle'] as String,
      githubLogin: json['githubLogin'] as String,
    );
  }
}

@immutable
class GitHubConfig {
  final String token;
  final String org;
  final List<String> repos;
  final List<GitHubEngineerMapping> engineerMappings;

  const GitHubConfig({
    this.token = '',
    this.org = '',
    this.repos = const [],
    this.engineerMappings = const [],
  });

  bool get isConfigured =>
      token.isNotEmpty && org.isNotEmpty && repos.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'token': token,
        'org': org,
        'repos': repos,
        'engineerMappings':
            engineerMappings.map((m) => m.toJson()).toList(),
      };

  factory GitHubConfig.fromJson(Map<String, dynamic> json) => GitHubConfig(
        token: json['token'] as String? ?? '',
        org: json['org'] as String? ?? '',
        repos: List<String>.from(json['repos'] as List? ?? const []),
        engineerMappings: (json['engineerMappings'] as List? ?? const [])
            .map((e) =>
                GitHubEngineerMapping.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class GitHubConfigNotifier extends AsyncNotifier<GitHubConfig> {
  static const _configFileName = 'forge_config.json';
  static const _configKey = 'watch_github_config';

  static Future<File> _configFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _configFileName));
  }

  static Future<Map<String, dynamic>> _readConfigFile() async {
    try {
      final file = await _configFile();
      if (!file.existsSync()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeConfigFile(Map<String, dynamic> data) async {
    try {
      final file = await _configFile();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
    } catch (_) {}
  }

  @override
  Future<GitHubConfig> build() async {
    final config = await _readConfigFile();
    final json = config[_configKey] as Map<String, dynamic>?;
    if (json == null) return const GitHubConfig();
    try {
      return GitHubConfig.fromJson(json);
    } catch (_) {
      return const GitHubConfig();
    }
  }

  Future<void> updateConfig(GitHubConfig config) async {
    final file = await _readConfigFile();
    file[_configKey] = config.toJson();
    await _writeConfigFile(file);
    state = AsyncData(config);
  }
}

final githubConfigProvider =
    AsyncNotifierProvider<GitHubConfigNotifier, GitHubConfig>(
  GitHubConfigNotifier.new,
);