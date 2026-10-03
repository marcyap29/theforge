import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_db/forge_database.dart';
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

  @override
  void initState() {
    super.initState();
    // Kick off with an opening turn so the architect greets + asks what to add.
    Future.microtask(() => _send(null));
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Text('$_addedCount added',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6BD69A))),
            ),
        ],
      ),
      body: Column(
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
