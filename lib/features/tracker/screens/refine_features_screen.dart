import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
import '../data/conversation_store.dart';
import '../providers/tracker_providers.dart';
import '../scan/feature_scan.dart';
import '../widgets/scan_review_sheet.dart';

/// Conversational "refine features" — re-open a chat on an existing project and
/// add new features by talking (the natural-language counterpart to the
/// one-shot "Recommend features"). The architect converses, asks clarifying
/// questions, and proposes features; accepted ones land on the tracker board.
/// Ordering into sensible versions is a separate step ("Plan build order").
class RefineFeaturesScreen extends ConsumerStatefulWidget {
  const RefineFeaturesScreen({
    super.key,
    required this.project,
    this.repoPath,
  });

  final Project project;
  final String? repoPath;

  @override
  ConsumerState<RefineFeaturesScreen> createState() =>
      _RefineFeaturesScreenState();
}

class _RefineFeaturesScreenState extends ConsumerState<RefineFeaturesScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _history = <RefineTurn>[];
  List<ProposedFeature> _pending = const []; // latest proposals, not yet added
  bool _thinking = false;
  int _addedCount = 0;

  // Multi-session persistence: the current conversation (resumable; past chats
  // are browsable). Saved to `.forge/conversations/`.
  late Conversation _convo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitial);
  }

  /// Resume the most recent conversation, or start a fresh one (with a greeting).
  Future<void> _loadInitial() async {
    final metas = await ConversationStore.list(widget.project.path);
    if (metas.isNotEmpty) {
      final c = await ConversationStore.read(widget.project.path, metas.first.id);
      if (c != null && mounted) {
        setState(() {
          _convo = c;
          _history
            ..clear()
            ..addAll(c.turns.map((t) => RefineTurn(isUser: t.isUser, text: t.text)));
          _loading = false;
        });
        _jump();
        return;
      }
    }
    _startNew();
  }

  void _startNew() {
    _convo = Conversation(
      id: 'c${DateTime.now().millisecondsSinceEpoch}',
      title: 'New chat',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      turns: [],
    );
    if (mounted) {
      setState(() {
        _history.clear();
        _pending = const [];
        _loading = false;
      });
    }
    // Greet + ask what to add.
    _send(null);
  }

  Future<void> _save() async {
    _convo.turns
      ..clear()
      ..addAll(_history.map((t) => StoredTurn(isUser: t.isUser, text: t.text)));
    // Title from the first user message, once there is one.
    if (_convo.title == 'New chat') {
      final firstUser = _history.firstWhere((t) => t.isUser,
          orElse: () => const RefineTurn(isUser: true, text: ''));
      if (firstUser.text.isNotEmpty) {
        _convo.title = ConversationStore.titleFrom(firstUser.text);
      }
    }
    await ConversationStore.write(widget.project.path, _convo);
  }

  Future<void> _openHistory() async {
    final metas = await ConversationStore.list(widget.project.path);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF15161C),
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_comment_outlined,
                  color: Color(0xFFE8A04C)),
              title: const Text('New chat'),
              onTap: () {
                Navigator.pop(ctx);
                _startNew();
              },
            ),
            const Divider(height: 1),
            if (metas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No past chats yet.',
                    style: TextStyle(color: Color(0xFF8A8A8E))),
              ),
            for (final m in metas)
              ListTile(
                leading: Icon(
                    m.id == _convo.id
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                    size: 18,
                    color: m.id == _convo.id
                        ? const Color(0xFFE8A04C)
                        : const Color(0xFF8A8A8E)),
                title: Text(m.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_ago(m.updatedAt),
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    await ConversationStore.delete(widget.project.path, m.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (m.id == _convo.id) _startNew();
                  },
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final c = await ConversationStore.read(
                      widget.project.path, m.id);
                  if (c != null && mounted) {
                    setState(() {
                      _convo = c;
                      _pending = const [];
                      _history
                        ..clear()
                        ..addAll(c.turns
                            .map((t) => RefineTurn(isUser: t.isUser, text: t.text)));
                    });
                    _jump();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String? text) async {
    if (_thinking) return;
    final msg = text?.trim();
    setState(() {
      if (msg != null && msg.isNotEmpty) {
        _history.add(RefineTurn(isUser: true, text: msg));
      }
      _thinking = true;
      _input.clear();
    });
    _jump();
    try {
      final existing =
          ref.read(featureListProvider(widget.project.id)).valueOrNull ??
              const <Feature>[];
      final result = await ref.read(featureScannerProvider).refineFeatures(
            projectPath: widget.project.path,
            repoPath: widget.repoPath,
            existing: existing,
            history: _history,
          );
      if (!mounted) return;
      setState(() {
        if (result.reply.isNotEmpty) {
          _history.add(RefineTurn(isUser: false, text: result.reply));
        }
        if (result.proposals.isNotEmpty) _pending = result.proposals;
        _thinking = false;
      });
      await _save();
      _jump();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _history.add(RefineTurn(
            isUser: false,
            text: 'Sorry — I hit a problem: '
                '${e.toString().replaceFirst('Exception: ', '')}'));
        _thinking = false;
      });
      _jump();
    }
  }

  void _jump() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });

  Future<void> _reviewAndAdd() async {
    if (_pending.isEmpty) return;
    // Dedup against the board so we never re-add.
    final existing =
        ref.read(featureListProvider(widget.project.id)).valueOrNull ??
            const <Feature>[];
    String norm(String s) => s.toLowerCase().trim();
    final seen = existing.map((f) => norm(f.title)).toSet();
    final fresh = _pending
        .where((p) => p.title.isNotEmpty && seen.add(norm(p.title)))
        .toList();
    if (fresh.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Those are already on the board.')));
      return;
    }
    final accepted = await showScanReviewSheet(context, fresh);
    if (accepted == null || accepted.isEmpty || !mounted) return;
    final notifier = ref.read(featureListProvider(widget.project.id).notifier);
    for (final f in accepted) {
      await notifier.addFeature(
        title: f.title,
        description: f.description,
        status: f.status,
        targetVersion: f.targetVersion,
        source: 'refine',
      );
    }
    if (!mounted) return;
    setState(() {
      _addedCount += accepted.length;
      _pending = const [];
      _history.add(RefineTurn(
          isUser: false,
          text: 'Added ${accepted.length} feature'
              '${accepted.length == 1 ? '' : 's'} to the board. Tell me more to '
              'add, or close this and run "Plan build order" to order them into '
              'versions.'));
    });
    await _save();
    _jump();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1016),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12161C),
        title: Text('Refine features — ${widget.project.name}'),
        actions: [
          if (_addedCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
              child: Text('$_addedCount added',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6BD69A))),
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Past chats',
            onPressed: _loading ? null : _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: _loading ? null : _startNew,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _history.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= _history.length) return const _Typing();
                return _Bubble(turn: _history[i]);
              },
            ),
          ),
          if (_pending.isNotEmpty && !_thinking) _proposalsBar(),
          _composer(),
        ],
      ),
    );
  }

  Widget _proposalsBar() => Container(
        width: double.infinity,
        color: const Color(0x22E8A04C),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            const Icon(Icons.playlist_add_check_outlined,
                size: 18, color: Color(0xFFE8A04C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_pending.length} feature${_pending.length == 1 ? '' : 's'} '
                'ready to add',
                style: const TextStyle(fontSize: 13, color: Color(0xFFE5E5E7)),
              ),
            ),
            FilledButton(
              onPressed: _reviewAndAdd,
              child: const Text('Review & add'),
            ),
          ],
        ),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_thinking,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: _send,
                  decoration: const InputDecoration(
                    hintText: 'Describe features to add…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _thinking ? null : () => _send(_input.text),
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
            ],
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final RefineTurn turn;

  @override
  Widget build(BuildContext context) {
    final user = turn.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: user ? const Color(0xFF2A2320) : const Color(0xFF15161C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: user ? const Color(0x55E8A04C) : const Color(0xFF26262B)),
        ),
        child: SelectableText(
          turn.text,
          style: const TextStyle(
              fontSize: 14, height: 1.4, color: Color(0xFFE5E5E7)),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
}
