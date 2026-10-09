import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/launch/launch_screen.dart';
import '../features/projects/screens/pull_ingestion_progress_screen.dart';
import '../features/projects/screens/pull_ingestion_summary_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/tracker/screens/portfolio_dashboard_screen.dart';
import '../features/watch/briefing_screen.dart';
import '../features/watch/decision_screen.dart';
import '../features/watch/spec_drift_screen.dart';
import '../features/watch/watch_dashboard_screen.dart';
import 'text_scale_notifier.dart';
import 'theme/forge_theme.dart';

final routeObserver = RouteObserver<ModalRoute<dynamic>>();

class TheForgeApp extends ConsumerWidget {
  const TheForgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(textScaleProvider).valueOrNull ?? 1.0;

    return MaterialApp(
      title: 'The Forge',
      debugShowCheckedModeBanner: false,
      theme: ForgeTheme.dark,
      darkTheme: ForgeTheme.dark,
      themeMode: ThemeMode.dark,
      navigatorObservers: [routeObserver],
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.equal, meta: true):
            const IncreaseTextScaleIntent(),
        const SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true):
            const IncreaseTextScaleIntent(),
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            const IncreaseTextScaleIntent(),
        const SingleActivator(LogicalKeyboardKey.equal, control: true, shift: true):
            const IncreaseTextScaleIntent(),
        const SingleActivator(LogicalKeyboardKey.minus, meta: true):
            const DecreaseTextScaleIntent(),
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            const DecreaseTextScaleIntent(),
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
            const ResetTextScaleIntent(),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            const ResetTextScaleIntent(),
      },
      actions: {
        IncreaseTextScaleIntent: CallbackAction<IncreaseTextScaleIntent>(
          onInvoke: (_) {
            ref.read(textScaleProvider.notifier).increase();
            return null;
          },
        ),
        DecreaseTextScaleIntent: CallbackAction<DecreaseTextScaleIntent>(
          onInvoke: (_) {
            ref.read(textScaleProvider.notifier).decrease();
            return null;
          },
        ),
        ResetTextScaleIntent: CallbackAction<ResetTextScaleIntent>(
          onInvoke: (_) {
            ref.read(textScaleProvider.notifier).reset();
            return null;
          },
        ),
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const LaunchScreen(),
        '/home': (context) => const PortfolioDashboardScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/watch': (context) => const WatchDashboardScreen(),
        '/watch/briefing': (context) => const BriefingScreen(),
        '/watch/decision': (context) => const DecisionScreen(),
        '/watch/spec-drift': (context) => const SpecDriftScreen(),
        '/reverse-ingestion/progress': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is String) {
            return PullIngestionProgressScreen(projectPath: args);
          }
          return const Scaffold(
            body: Center(child: Text('Invalid project path')),
          );
        },
        '/reverse-ingestion/summary': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, String>) {
            return PullIngestionSummaryScreen(
              projectPath: args['projectPath']!,
              projectName: args['projectName']!,
            );
          }
          return const Scaffold(
            body: Center(child: Text('Invalid arguments')),
          );
        },
      },
    );
  }
}

class IncreaseTextScaleIntent extends Intent {
  const IncreaseTextScaleIntent();
}

class DecreaseTextScaleIntent extends Intent {
  const DecreaseTextScaleIntent();
}

class ResetTextScaleIntent extends Intent {
  const ResetTextScaleIntent();
}
