import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../data/filesystem/project_file_repository.dart';

/// One persisted message in a saved conversation.
class StoredTurn {
  const StoredTurn({required this.isUser, required this.text});
  final bool isUser;
  final String text;

  Map<String, dynamic> toJson() => {'u': isUser, 't': text};
  factory StoredTurn.fromJson(Map<String, dynamic> j) =>
      StoredTurn(isUser: j['u'] == true, text: (j['t'] ?? '').toString());
}

/// A saved "Work on the app" conversation — its id, title, timestamps, and
/// turns. Lives at `.forge/conversations/<id>.json`.
class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.turns,
  });

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<StoredTurn> turns;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'turns': turns.map((t) => t.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? 'Chat').toString(),
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse((j['updatedAt'] ?? '').toString()) ?? DateTime.now(),
        turns: [
          for (final t in (j['turns'] as List? ?? const []))
            if (t is Map) StoredTurn.fromJson(t.cast<String, dynamic>()),
        ],
      );
}

/// Lightweight list entry for the "past chats" picker (no turns loaded).
class ConversationMeta {
  const ConversationMeta(
      {required this.id, required this.title, required this.updatedAt});
  final String id;
  final String title;
  final DateTime updatedAt;
}

/// Persists "Work on the app" conversations under `.forge/conversations/`, so a
/// builder can browse past chats and resume where they left off. Best-effort —
/// a read/write hiccup never breaks the chat.
class ConversationStore {
  const ConversationStore._();

  static Directory _dir(String projectPath) => Directory(
      p.join(projectPath, ProjectFileRepository.forgeDirName, 'conversations'));

  /// Newest-first list of saved conversations (metadata only).
  static Future<List<ConversationMeta>> list(String projectPath) async {
    final dir = _dir(projectPath);
    if (!dir.existsSync()) return const [];
    final out = <ConversationMeta>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await f.readAsString());
        if (j is! Map) continue;
        out.add(ConversationMeta(
          id: (j['id'] ?? p.basenameWithoutExtension(f.path)).toString(),
          title: (j['title'] ?? 'Chat').toString(),
          updatedAt: DateTime.tryParse((j['updatedAt'] ?? '').toString()) ??
              f.lastModifiedSync(),
        ));
      } catch (_) {}
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  static Future<Conversation?> read(String projectPath, String id) async {
    try {
      final f = File(p.join(_dir(projectPath).path, '$id.json'));
      if (!f.existsSync()) return null;
      final j = jsonDecode(await f.readAsString());
      return j is Map ? Conversation.fromJson(j.cast<String, dynamic>()) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String projectPath, Conversation c) async {
    try {
      final dir = _dir(projectPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      c.updatedAt = DateTime.now();
      await File(p.join(dir.path, '${c.id}.json'))
          .writeAsString(jsonEncode(c.toJson()));
    } catch (_) {}
  }

  static Future<void> delete(String projectPath, String id) async {
    try {
      final f = File(p.join(_dir(projectPath).path, '$id.json'));
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// A short title from the first user message (or a timestamped fallback).
  static String titleFrom(String firstUserMessage) {
    final t = firstUserMessage.trim().replaceAll('\n', ' ');
    if (t.isEmpty) return 'New chat';
    return t.length > 42 ? '${t.substring(0, 42)}…' : t;
  }
}
