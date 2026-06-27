import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;

enum ArtifactViewMode { forge, spec, handoff, worksheet, audit }

class ArtifactViewArgs {
  final String projectPath;
  final String projectName;
  final String filename;
  final ArtifactViewMode mode;
  final String? specVersion;

  const ArtifactViewArgs({
    required this.projectPath,
    required this.projectName,
    required this.filename,
    required this.mode,
    this.specVersion,
  });
}

class ArtifactViewerScreen extends StatelessWidget {
  const ArtifactViewerScreen({super.key, required this.args});

  final ArtifactViewArgs args;

  String get _folder {
    return switch (args.mode) {
      ArtifactViewMode.forge => 'forge',
      ArtifactViewMode.spec => 'specs',
      ArtifactViewMode.handoff => 'handoffs',
      ArtifactViewMode.worksheet => 'worksheets',
      ArtifactViewMode.audit => 'audit',
    };
  }

  String get _title {
    return switch (args.mode) {
      ArtifactViewMode.forge => args.filename,
      ArtifactViewMode.spec => 'Spec — ${args.projectName}',
      ArtifactViewMode.handoff => 'Handoff — ${args.projectName}',
      ArtifactViewMode.worksheet => 'Worksheet — ${args.projectName}',
      ArtifactViewMode.audit => 'Audit Log — ${args.projectName}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final file = args.specVersion != null
        ? File(p.join(args.projectPath, _folder, args.specVersion!, args.filename))
        : File(p.join(args.projectPath, _folder, args.filename));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<String>(
        future: file.readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Could not read file:\n${args.filename}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 13,
                  color: Color(0xFFEF4444),
                ),
              ),
            );
          }
          return Markdown(
            data: snapshot.data!,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFE5E5E7),
              ),
              h1: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE5E5E7),
              ),
              h2: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE8A04C),
              ),
              h3: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E5E7),
              ),
              code: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                color: Color(0xFF22C55E),
                backgroundColor: Color(0xFF0F0F10),
              ),
              codeblockDecoration: BoxDecoration(
                color: const Color(0xFF0F0F10),
                border: Border.all(color: const Color(0xFF2C2C2E)),
                borderRadius: BorderRadius.circular(6),
              ),
              tableBorder: TableBorder.all(
                color: const Color(0xFF2C2C2E),
                width: 1,
              ),
              tableHead: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE8A04C),
              ),
              tableBody: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
            padding: const EdgeInsets.all(16),
          );
        },
      ),
    );
  }
}
