import 'package:flutter/material.dart';

import '../features/interview/providers/interview_providers.dart';
import '../features/interview/ui/interview_screen.dart';
import '../features/projects/screens/projects_list_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/watch/briefing_screen.dart';
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
