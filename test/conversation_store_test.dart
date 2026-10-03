import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/features/tracker/data/conversation_store.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('forge_convo_'));
  tearDown(() => tmp.existsSync() ? tmp.deleteSync(recursive: true) : null);

  Conversation _c(String id, String title, List<StoredTurn> turns) =>
      Conversation(
        id: id,
        title: title,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        turns: turns,
      );

  test('write → read round-trips turns + title', () async {
    final c = _c('c1', 'Add dark mode', const [
      StoredTurn(isUser: true, text: 'add a dark mode toggle'),
      StoredTurn(isUser: false, text: 'Got it — one feature coming up.'),
    ]);
    await ConversationStore.write(tmp.path, c);

    final back = await ConversationStore.read(tmp.path, 'c1');
    expect(back, isNotNull);
    expect(back!.title, 'Add dark mode');
    expect(back.turns.length, 2);
    expect(back.turns.first.isUser, isTrue);
    expect(back.turns.first.text, 'add a dark mode toggle');
    expect(back.turns.last.isUser, isFalse);
  });

  test('list is newest-first and read-only metadata', () async {
    // write() stamps updatedAt = now, so writing in order makes the 2nd newer.
    await ConversationStore.write(tmp.path, _c('a', 'First', const []));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await ConversationStore.write(tmp.path, _c('b', 'Second', const []));

    final metas = await ConversationStore.list(tmp.path);
    expect(metas.map((m) => m.id).toList().take(2), ['b', 'a']);
  });

  test('delete removes a conversation', () async {
    await ConversationStore.write(tmp.path, _c('x', 'Bye', const []));
    expect(await ConversationStore.read(tmp.path, 'x'), isNotNull);
    await ConversationStore.delete(tmp.path, 'x');
    expect(await ConversationStore.read(tmp.path, 'x'), isNull);
  });

  test('list is empty (not an error) before any chat exists', () async {
    expect(await ConversationStore.list(tmp.path), isEmpty);
  });

  test('titleFrom trims and caps a long first message', () {
    expect(ConversationStore.titleFrom('  add login  '), 'add login');
    expect(ConversationStore.titleFrom(''), 'New chat');
    final long = 'a' * 100;
    expect(ConversationStore.titleFrom(long).length, lessThanOrEqualTo(43));
    expect(ConversationStore.titleFrom(long).endsWith('…'), isTrue);
  });
}
