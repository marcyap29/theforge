import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/forge_theme.dart';
import '../../core/widgets/hearth_dial.dart';
import '../projects/screens/new_project_screen.dart';

/// What a brand-new user sees before anything is tracked.
///
/// Two rules drive the layout:
///  1. The primary path needs nothing — no folder, no API key, no git. That
///     inverts today's flow, which assumes a repo up front.
///  2. There is always a way out. Forcing setup before someone can look
///     around is the fastest way to lose them on install day.
class FirstRunScreen extends ConsumerWidget {
  const FirstRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: ForgeColors.navy,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ForgeColors.navyLift,
              ForgeColors.navy,
              ForgeColors.navyDeep,
            ],
            stops: [0, 0.42, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(48, 48, 48, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 660),
                      child: Column(
                        children: [
                          // Progress 0: all steel, ember hollow. Nothing forged
                          // yet. It fills the moment the first project lands.
                          const HearthDial(size: 86, progress: 0),
                          const SizedBox(height: 28),
                          Text(
                            'Nothing tracked yet.',
                            style: t.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Add the thing you\'re building. The Forge keeps '
                            'the feature list, what\'s done, and what changed '
                            'since you last looked.',
                            style: t.bodyMedium?.copyWith(fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton(
                                onPressed: () => _addProject(context),
                                child: const Text('ADD A PROJECT'),
                              ),
                              OutlinedButton(
                                onPressed: () => _addProject(context),
                                child: const Text('LINK A CODE FOLDER'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 44),
                          const _Steps(),
                          const SizedBox(height: 26),
                          TextButton(
                            onPressed: () => _skip(context),
                            style: TextButton.styleFrom(
                              foregroundColor: ForgeColors.steelDim,
                            ),
                            child: Text(
                              'LOOK AROUND FIRST',
                              style: t.labelSmall
                                  ?.copyWith(color: ForgeColors.steelDim),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: ForgeColors.hairline)),
        ),
        child: Row(
          children: [
            const HearthDial(size: 20, progress: 0),
            const SizedBox(width: 9),
            Text(
              'THE FORGE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ForgeColors.ivory,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.1,
                  ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 17),
              color: ForgeColors.steel,
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
            ),
          ],
        ),
      );

  void _addProject(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NewProjectScreen()),
    );
  }

  void _skip(BuildContext context) {
    // Both buttons land in the same place today: NewProjectScreen already
    // branches between naming a project and pointing at a folder. Split them
    // only once those are genuinely different flows.
    Navigator.of(context).pushReplacementNamed('/');
  }
}

/// Three steps, so they get numbers. Numbering decoration that isn't a real
/// sequence is the tell of a template; this one is a sequence.
class _Steps extends StatelessWidget {
  const _Steps();

  static const _items = [
    ('01', 'Name what you\'re building'),
    ('02', 'List what it should do, or let The Forge read your folder and draft it'),
    ('03', 'Come back whenever. It tells you what moved'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ForgeColors.hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: ForgeColors.hairline,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      Text(
                        _items[i].$1,
                        style: t.labelSmall
                            ?.copyWith(color: ForgeColors.brass),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _items[i].$2,
                        textAlign: TextAlign.center,
                        style: t.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
