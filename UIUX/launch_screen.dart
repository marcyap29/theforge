import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lib/core/theme/forge_theme.dart';
import '../lib/core/widgets/hearth_dial.dart';
import '../lib/features/onboarding/first_run_screen.dart';
import '../lib/features/projects/providers/providers.dart';
import '../lib/features/tracker/providers/tracker_providers.dart';
import '../lib/features/tracker/widgets/portfolio_digest.dart';

/// The splash. Decides where to send the user: the first-run screen when
/// nothing is tracked yet, or the portfolio home when there's work to show.
class LaunchScreen extends ConsumerWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);

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
          child: Center(
            child: projects.when(
              loading: () => const _Splash(),
              error: (e, _) => _Splash(message: '$e'),
              data: (list) {
                if (list.isEmpty) {
                  return const FirstRunScreen();
                }
                return const _PortfolioHome();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HearthDial(size: 96, progress: 0),
        const SizedBox(height: 24),
        Text(
          'THE FORGE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ForgeColors.ivory,
            fontWeight: FontWeight.w600,
            letterSpacing: 3.2,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ForgeColors.rustLit),
          ),
        ],
      ],
    );
  }
}

class _PortfolioHome extends ConsumerWidget {
  const _PortfolioHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);
    return portfolio.when(
      loading: () => const _Splash(),
      error: (e, _) => _Splash(message: '$e'),
      data: (entries) => PortfolioDigest(entries: entries),
    );
  }
}
