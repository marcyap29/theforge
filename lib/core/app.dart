import 'package:flutter/material.dart';

import '../features/interview/providers/interview_providers.dart';
import '../features/interview/ui/interview_screen.dart';
import '../features/projects/screens/projects_list_screen.dart';
import '../features/projects/screens/pull_ingestion_progress_screen.dart';
import '../features/projects/screens/pull_ingestion_summary_screen.dart';
import '../features/pull_interview/state/pull_interview_state.dart';
import '../features/pull_interview/ui/pull_interview_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/spec_generation/as_built_spec_screen.dart';
import '../features/watch/briefing_screen.dart';
import '../features/watch/decision_screen.dart';
import '../features/watch/spec_drift_screen.dart';
import '../features/watch/watch_dashboard_screen.dart';
import 'theme/app_theme.dart';

final routeObserver = RouteObserver<ModalRoute<dynamic>>();

class TheForgeApp extends StatelessWidget {
  const TheForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Forge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      navigatorObservers: [routeObserver],
      initialRoute: '/',
      routes: {
        '/': (context) => const ProjectsListScreen(),
        '/interview': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is InterviewArgs) {
            return InterviewScreen(args: args);
          }
          return const _MissingInterviewArgs();
        },
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
        '/reverse-interview': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is PullInterviewArgs) {
            return PullInterviewScreen(args: args);
          }
          return const Scaffold(
            body: Center(child: Text('Invalid pull interview args')),
          );
        },
        '/as-built-spec': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, String>) {
            return AsBuiltSpecScreen(
              projectPath: args['projectPath']!,
              projectName: args['projectName']!,
            );
          }
          return const Scaffold(
            body: Center(child: Text('Invalid as-built spec args')),
          );
        },
      },
    );
  }
}

class _MissingInterviewArgs extends StatelessWidget {
  const _MissingInterviewArgs();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Missing interview arguments.\n\n'
            'Navigate with:\n'
            'Navigator.pushNamed(context, "/interview", '
            'arguments: InterviewArgs(path: p, name: n));',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Menlo', fontSize: 13, height: 1.5),
          ),
        ),
      ),
    );
  }
}
