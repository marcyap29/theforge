import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

import '../../../data/local_db/forge_database.dart';
import '../../../services/llm/llm_provider.dart';
import '../../../services/llm/llm_service_provider.dart';
import '../../tracker/data/conversation_store.dart';
import '../../tracker/widgets/active_model_chip.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _Turn {
  _Turn({required this.isUser, required this.text, this.streaming = false});
  final bool isUser;
  String text;
  bool streaming;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Free-form AI chat, separate from the Build and Architect-Mode flows.
/// The user can ask anything: code questions, architecture review, writing
/// prompts for AI agents, debugging, or general guidance.
///
/// On open it scans the Forge project docs (FEATURES, ARCHITECTURE, CHANGELOG,
/// backlog) plus any docs at the linked repo root and passes them all as
/// system-prompt context so the AI never suggests work that's already done.
///
/// Conversations persist under `Forge/direct-chats/`.
class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({
    super.key,
    required this.project,
    this.repoPath,
  });

  final Project project;
  final String? repoPath;

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focusNode = FocusNode();
  final _history = <_Turn>[];
  bool _thinking = false;
  late Conversation _convo;
  bool _ready = false;

  // Context — loaded once per session, pre-fetched on init.
  String? _projectContext;
  List<String> _contextSources = const [];

  // Live status shown while the AI is working.
  String? _statusText;

  List<ConversationMeta> _pastChats = const [];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Kick off context loading in the background so the banner appears before
    // the user sends their first message.
    _loadContext();

    final metas = await _listMetas();
    if (metas.isNotEmpty) {
      final loaded = await _readConvo(metas.first.id);
      if (loaded != null && mounted) {
        setState(() {
          _convo = loaded;
          _history.addAll(
              loaded.turns.map((t) => _Turn(isUser: t.isUser, text: t.text)));
          _pastChats = metas;
          _ready = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
        return;
      }
    }
    _startNew(metas: metas);
  }

  void _startNew({List<ConversationMeta>? metas}) {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _convo = Conversation(
          id: now.millisecondsSinceEpoch.toString(),
          title: 'New chat',
          createdAt: now,
          updatedAt: now,
          turns: [],
        );
        _history.clear();
        if (metas != null) _pastChats = metas;
        _ready = true;
      });
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  // ---------------------------------------------------------------------------
  // Storage (Forge/direct-chats/)
  // ---------------------------------------------------------------------------

  static const _subdir = 'direct-chats';

  Directory _chatDir() =>
      Directory(p.join(widget.project.path, 'Forge', _subdir));

  Future<List<ConversationMeta>> _listMetas() async {
    final dir = _chatDir();
    if (!dir.existsSync()) return const [];
    final out = <ConversationMeta>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        final j = _tryDecodeJson(await f.readAsString());
        if (j == null) continue;
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

  Future<Conversation?> _readConvo(String id) async {
    try {
      final f = File(p.join(_chatDir().path, '$id.json'));
      if (!f.existsSync()) return null;
      final j = _tryDecodeJson(await f.readAsString());
      return j != null ? Conversation.fromJson(j) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveConvo() async {
    try {
      final dir = _chatDir();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      _convo.updatedAt = DateTime.now();
      _convo.turns
        ..clear()
        ..addAll(_history
            .where((t) => !t.streaming && t.text.isNotEmpty)
            .map((t) => StoredTurn(isUser: t.isUser, text: t.text)));
      if (_convo.title == 'New chat') {
        final first = _history.firstWhere((t) => t.isUser,
            orElse: () => _Turn(isUser: true, text: ''));
        if (first.text.isNotEmpty) {
          _convo.title = ConversationStore.titleFrom(first.text);
        }
      }
      await File(p.join(dir.path, '${_convo.id}.json'))
          .writeAsString(jsonEncode(_convo.toJson()));
      final updated = await _listMetas();
      if (mounted) setState(() => _pastChats = updated);
    } catch (_) {}
  }

  Future<void> _deleteConvo(String id) async {
    try {
      final f = File(p.join(_chatDir().path, '$id.json'));
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  Map<String, dynamic>? _tryDecodeJson(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map ? v.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Context loading
  // ---------------------------------------------------------------------------

  /// Loads project docs into [_projectContext] and tracks which files landed
  /// in [_contextSources]. Safe to call multiple times — returns immediately
  /// on subsequent calls once the cache is warm.
  Future<String?> _loadContext() async {
    if (_projectContext != null) return _projectContext;
    final buf = StringBuffer();
    final sources = <String>[];
    final proj = widget.project.path;
    final rp = widget.repoPath;

    // Forge project docs — tell the AI what's already been built and planned.
    await _appendFile(buf, sources,
        path: p.join(proj, 'tracking md files', 'FEATURES.md'),
        heading: '## Shipped features',
        name: 'FEATURES',
        maxChars: 6000);
    await _appendFile(buf, sources,
        path: p.join(proj, 'tracking md files', 'ARCHITECTURE.md'),
        heading: '## Architecture',
        name: 'ARCHITECTURE',
        maxChars: 6000);
    await _appendFile(buf, sources,
        path: p.join(proj, 'tracking md files', 'CHANGELOG.md'),
        heading: '## Recent changelog',
        name: 'CHANGELOG',
        maxChars: 4000);
    await _appendFile(buf, sources,
        path: p.join(proj, 'tracking md files', 'backlog.md'),
        heading: '## Backlog (planned)',
        name: 'backlog',
        maxChars: 3000);
    await _appendFile(buf, sources,
        path: p.join(proj, 'README.md'),
        heading: '## Project README',
        name: 'README',
        maxChars: 3000);
    // Ingested reference context (generated by the Ingest feature, if present).
    await _appendFile(buf, sources,
        path: p.join(proj, 'Forge', 'ingested', 'reference_context.md'),
        heading: '## Ingested reference',
        name: 'ingested',
        maxChars: 3000);

    // Repo docs — grounding from the linked codebase.
    if (rp != null) {
      await _appendFile(buf, sources,
          path: p.join(rp, 'CLAUDE.md'),
          heading: '## Repo CLAUDE.md',
          name: 'repo:CLAUDE',
          maxChars: 3000);
      await _appendFile(buf, sources,
          path: p.join(rp, 'CHANGELOG.md'),
          heading: '## Repo changelog',
          name: 'repo:CHANGELOG',
          maxChars: 2000);
      await _appendFile(buf, sources,
          path: p.join(rp, 'FEATURES.md'),
          heading: '## Repo features',
          name: 'repo:FEATURES',
          maxChars: 2000);
      await _appendFile(buf, sources,
          path: p.join(rp, 'docs', 'ARCHITECTURE.md'),
          heading: '## Repo architecture',
          name: 'repo:ARCHITECTURE',
          maxChars: 2000);
    }

    final ctx = buf.toString().trim();
    _projectContext = ctx.isEmpty ? null : ctx;
    if (mounted) setState(() => _contextSources = List.unmodifiable(sources));
    return _projectContext;
  }

  Future<void> _appendFile(
    StringBuffer buf,
    List<String> sources, {
    required String path,
    required String heading,
    required String name,
    required int maxChars,
  }) async {
    try {
      final f = File(path);
      if (!f.existsSync()) return;
      final text = (await f.readAsString()).trim();
      if (text.isEmpty) return;
      buf.writeln(heading);
      buf.writeln(text.length > maxChars ? text.substring(0, maxChars) : text);
      buf.writeln();
      sources.add(name);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Prompts
  // ---------------------------------------------------------------------------

  String _systemPrompt(String? context) {
    final buf = StringBuffer(
      'You are a direct, capable AI assistant embedded in The Forge, '
      'an AI-powered app builder for solo developers.\n\n'
      'You help with anything: code review, architecture questions, writing '
      'prompts for AI agents, debugging, planning, or general guidance. '
      'Be concise and opinionated. Use markdown. Give actionable answers.\n\n'
      'IMPORTANT: The project context below shows what has already been built '
      'and what is planned. Do not suggest implementing features that are '
      'already shipped. Reference the existing architecture when proposing '
      'changes.',
    );
    if (context != null) {
      buf.write('\n\n## Project context\n\n');
      buf.write(context);
    }
    return buf.toString();
  }

  String _userPrompt(List<_Turn> priorTurns, String latestMessage) {
    final buf = StringBuffer();
    if (priorTurns.isNotEmpty) {
      buf.writeln('## Conversation so far');
      for (final t in priorTurns) {
        buf.writeln('${t.isUser ? 'USER' : 'ASSISTANT'}: ${t.text}');
      }
      buf.writeln();
    }
    buf.write('USER: $latestMessage');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // File attachment
  // ---------------------------------------------------------------------------

  /// Opens a file picker, reads the selected file, and inserts its contents
  /// into the input field as a labelled code block so the AI can see it.
  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: [
        'dart', 'yaml', 'yml', 'json', 'md', 'txt',
        'swift', 'kt', 'java', 'js', 'ts', 'py', 'sh',
      ],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final path = file.path;
    if (path == null) return;

    try {
      final contents = await File(path).readAsString();
      final ext = p.extension(path).replaceFirst('.', '');
      final label = p.basename(path);

      // Format: file label line + fenced code block
      final block = '`$label`\n```$ext\n$contents\n```';

      final current = _input.text;
      final prefix = current.isEmpty ? '' : '$current\n\n';
      _input.text = '$prefix$block';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    if (_thinking) return;
    final msg = _input.text.trim();
    if (msg.isEmpty) return;

    // Snapshot history before mutating so the transcript doesn't include the
    // message we're about to send.
    final prior = List<_Turn>.unmodifiable(
        _history.where((t) => !t.streaming && t.text.isNotEmpty).toList());

    setState(() {
      _history.add(_Turn(isUser: true, text: msg));
      _history.add(_Turn(isUser: false, text: '', streaming: true));
      _thinking = true;
      _input.clear();
    });
    _jumpToBottom();

    // Load context if not already cached, narrating the phase.
    if (_projectContext == null) {
      if (mounted) setState(() => _statusText = 'Loading project context…');
    }
    final context = await _loadContext();

    if (!mounted) return;
    setState(() => _statusText = 'Thinking…');

    try {
      final stream = ref.read(llmServiceProvider).completeStream(
            systemPrompt: _systemPrompt(context),
            userPrompt: _userPrompt(prior, msg),
            temperature: 0.7,
            role: LlmRole.architect,
          );

      var firstToken = true;
      final buf = StringBuffer();
      await for (final delta in stream) {
        if (delta.thinking) continue;
        if (firstToken) {
          firstToken = false;
          if (mounted) setState(() => _statusText = 'Writing…');
        }
        buf.write(delta.text);
        if (!mounted) return;
        setState(() => _history.last.text = buf.toString());
        _jumpToBottom();
      }

      if (!mounted) return;
      setState(() {
        _history.last.streaming = false;
        _thinking = false;
        _statusText = null;
      });
      await _saveConvo();
      _jumpToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _history.last
          ..text = 'Something went wrong: '
              '${e.toString().replaceFirst('Exception: ', '')}'
          ..streaming = false;
        _thinking = false;
        _statusText = null;
      });
      _jumpToBottom();
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Past chats sheet
  // ---------------------------------------------------------------------------

  void _showPastChats() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
              child: Row(
                children: [
                  const Text('Past chats',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startNew();
                    },
                    child: const Text('New chat'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StatefulBuilder(
                builder: (ctx2, setSt) => _pastChats.isEmpty
                    ? const Center(
                        child: Text('No saved chats yet.',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: _pastChats.length,
                        itemBuilder: (_, i) {
                          final m = _pastChats[i];
                          final isCurrent = m.id == _convo.id;
                          return ListTile(
                            selected: isCurrent,
                            selectedTileColor: Colors.white10,
                            leading: const Icon(Icons.chat_bubble_outline,
                                size: 18, color: Colors.white38),
                            title: Text(m.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isCurrent
                                        ? Colors.amber
                                        : Colors.white)),
                            subtitle: Text(
                              _formatDate(m.updatedAt),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white38),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 16, color: Colors.white30),
                              onPressed: () async {
                                await _deleteConvo(m.id);
                                final updated = await _listMetas();
                                if (!mounted) return;
                                setState(() => _pastChats = updated);
                                setSt(() {});
                                if (m.id == _convo.id) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _startNew(metas: updated);
                                }
                              },
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              if (m.id == _convo.id) return;
                              final loaded = await _readConvo(m.id);
                              if (loaded == null || !mounted) return;
                              setState(() {
                                _convo = loaded;
                                _history.clear();
                                _history.addAll(loaded.turns.map(
                                    (t) => _Turn(isUser: t.isUser, text: t.text)));
                              });
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) => _jumpToBottom());
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F14),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Flexible(
              child: Text(widget.project.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15)),
            ),
            const SizedBox(width: 6),
            const Text('· Chat',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8E))),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: ActiveModelChip(role: LlmRole.architect),
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Past chats',
            onPressed: _showPastChats,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: _startNew,
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_contextSources.isNotEmpty)
                  _ContextBanner(sources: _contextSources),
                Expanded(
                  child: _history.isEmpty
                      ? _EmptyState(projectName: widget.project.name)
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _history.length,
                          itemBuilder: (_, i) => _Bubble(turn: _history[i]),
                        ),
                ),
                if (_statusText != null) _StatusBar(text: _statusText!),
                _InputBar(
                  controller: _input,
                  focusNode: _focusNode,
                  thinking: _thinking,
                  onSend: _send,
                  onAttach: _attachFile,
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// Thin strip showing which project files have been loaded into the AI's
/// context. Green chip per source — scrollable if there are many.
class _ContextBanner extends StatelessWidget {
  const _ContextBanner({required this.sources});
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F0C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_outlined,
              size: 12, color: Color(0xFF4A9A5C)),
          const SizedBox(width: 6),
          const Text('Context:',
              style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF4A9A5C),
                  fontFamily: 'Menlo')),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sources
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF112218),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF2A4A33), width: 0.5),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF6BD69A),
                                  fontFamily: 'Menlo'),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line status bar shown above the input while the AI is doing work.
/// Narrates the current phase: loading context → thinking → writing.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12121A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Color(0xFF8A8A8E)),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8A8E)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.projectName});
  final String projectName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'Chat about $projectName',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask anything — architecture, code review,\n'
              'writing prompts, planning, or debugging.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatefulWidget {
  const _Bubble({required this.turn});
  final _Turn turn;
  @override
  State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  bool _copied = false;

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: widget.turn.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.turn.isUser;
    return Padding(
      padding: EdgeInsets.only(
        top: 8,
        bottom: 4,
        left: isUser ? 56 : 0,
        right: isUser ? 0 : 56,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Stack(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(
                  14, isUser ? 10 : 32, 14, 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF2C2C3A)
                    : const Color(0xFF1A1A24),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: Colors.white10, width: 0.5),
              ),
              child: widget.turn.text.isEmpty
                  ? const _TypingDots()
                  : isUser
                      ? SelectableText(
                          widget.turn.text,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white, height: 1.45),
                        )
                      : MarkdownBody(
                          data: widget.turn.text,
                          // _CodeBlockBuilder adds per-block copy buttons.
                          // Inline code falls through to styleSheet.code.
                          builders: {'code': _CodeBlockBuilder()},
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: const TextStyle(
                                fontSize: 14, color: Colors.white, height: 1.5),
                            code: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFE5C07B),
                                fontFamily: 'Menlo',
                                backgroundColor: Color(0xFF1A1420)),
                          ),
                          selectable: true,
                        ),
            ),
            // Copy-message button — top-right of assistant bubbles only.
            if (!isUser && widget.turn.text.isNotEmpty)
              Positioned(
                top: 4,
                right: 6,
                child: GestureDetector(
                  onTap: _copyMessage,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111120),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.white12, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check_rounded : Icons.copy_outlined,
                          size: 11,
                          color: _copied
                              ? const Color(0xFF6BD69A)
                              : const Color(0xFF8A8A8E),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _copied ? 'Copied' : 'Copy',
                          style: TextStyle(
                            fontSize: 10,
                            color: _copied
                                ? const Color(0xFF6BD69A)
                                : const Color(0xFF8A8A8E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Code block copy button
// ---------------------------------------------------------------------------

/// Intercepts `<code>` elements from flutter_markdown. Block code (detected
/// by newlines in content) gets a full-width container with a copy button.
/// Inline code returns null so the default styleSheet.code applies.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    // Inline code never contains newlines.
    if (!code.contains('\n')) return null;
    return _CodeBlock(code: code.trimRight());
  }
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code});
  final String code;
  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar with copy button
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: const BoxDecoration(
              color: Color(0xFF111120),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _copy,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _copied ? Icons.check_rounded : Icons.copy_outlined,
                        size: 13,
                        color: _copied
                            ? const Color(0xFF6BD69A)
                            : const Color(0xFF8A8A8E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? 'Copied' : 'Copy',
                        style: TextStyle(
                          fontSize: 11,
                          color: _copied
                              ? const Color(0xFF6BD69A)
                              : const Color(0xFF8A8A8E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Code body — horizontally scrollable so long lines don't wrap.
          // Uses Text (not SelectableText) to avoid nested selection conflicts
          // with MarkdownBody(selectable: true); use the Copy button instead.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.code,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFE5C07B),
                fontFamily: 'Menlo',
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
          final opacity =
              (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.2, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: opacity,
              child: const CircleAvatar(
                  radius: 3.5, backgroundColor: Colors.white54),
            ),
          );
        }),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.thinking,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool thinking;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF14141C),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Paperclip — attach a file as a code block
            SizedBox(
              width: 36,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.attach_file_rounded,
                    size: 20, color: Colors.white38),
                padding: EdgeInsets.zero,
                tooltip: 'Attach file',
                onPressed: thinking ? null : onAttach,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 6,
                minLines: 1,
                enabled: !thinking,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ask anything…',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1E1E28),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              height: 40,
              child: thinking
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon:
                          const Icon(Icons.send_rounded, color: Colors.amber),
                      padding: EdgeInsets.zero,
                      onPressed: onSend,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
