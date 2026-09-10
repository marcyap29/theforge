import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/forge_theme.dart';
import '../../core/widgets/hearth_dial.dart';
import '../onboarding/first_run_screen.dart';
import '../projects/providers/providers.dart';
import '../tracker/providers/tracker_providers.dart';
import '../tracker/screens/portfolio_dashboard_screen.dart';
import '../tracker/widgets/portfolio_digest.dart';

/// The launch moment. The mark is the loading bar: the brass arc sweeps from
/// empty and settles at the icon's resting position while real boot work runs.
///
/// Rules baked in:
///  - held a minimum of 600ms so a fast boot doesn't flicker;
///  - capped at 4s, after which it routes anyway and lets the destination
///    surface the failure;
///  - the arc tracks real steps, so a hang is visible instead of a lie.
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen>
    with SingleTickerProviderStateMixin {
  static const _minHold = Duration(milliseconds: 600);
  static const _cap = Duration(seconds: 4);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  String _step = 'STARTING UP';
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _boot();
    // Safety net: never let a wedged provider trap the user on the splash.
    Future<void>.delayed(_cap, () {
      if (mounted && !_routed) _go(hasProjects: true);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final started = DateTime.now();
    var hasProjects = true;

    try {
      setState(() => _step = 'READING YOUR PROJECTS');
      final projects = await ref.read(projectListProvider.future);
      hasProjects = projects.isNotEmpty;

      if (hasProjects) {
        if (mounted) setState(() => _step = 'ROLLING UP FEATURES');
        await ref.read(portfolioProvider.future);

        if (mounted) setState(() => _step = 'CHECKING WHAT CHANGED');
        await ref.read(portfolioDigestProvider.future);
      }
      if (mounted) setState(() => _step = 'READY');
    } catch (_) {
      // Let the destination screen show the real error. A splash is the wrong
      // place to explain a failure.
      if (mounted) setState(() => _step = 'READY');
    }

    final elapsed = DateTime.now().difference(started);
    if (elapsed < _minHold) {
      await Future<void>.delayed(_minHold - elapsed);
    }
    // Let the arc finish its sweep before moving on.
    if (_anim.isAnimating) await _anim.forward().orCancel.catchError((_) {});
    if (mounted) _go(hasProjects: hasProjects);
  }

  void _go({required bool hasProjects}) {
    if (_routed) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => hasProjects
            ? const PortfolioDashboardScreen()
            : const FirstRunScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedHearthDial(controller: _anim, size: 118),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _anim,
                      curve: const Interval(0.6, 1, curve: Curves.easeOut),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'THE FORGE',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 6.6,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'ORBITAL AI',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: ForgeColors.steelDim,
                                letterSpacing: 3.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 34,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    _step,
                    key: ValueKey(_step),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: ForgeColors.steelDim,
                        ),
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
