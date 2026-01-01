import 'package:flutter/material.dart';

import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/habits/habit_list_screen.dart';
import '../presentation/screens/habits/habit_editor_screen.dart';
import '../presentation/screens/calendar/calendar_screen.dart';
import '../presentation/screens/macros/macro_list_screen.dart';
import '../presentation/screens/macros/macro_editor_screen.dart';
import '../presentation/screens/settings/permissions_screen.dart';
import '../presentation/screens/analytics/analytics_screen.dart';
import '../presentation/screens/discipline_mode/discipline_mode_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String habitList = '/habits';
  static const String habitEditor = '/habits/editor';
  static const String calendar = '/calendar';
  static const String macroList = '/macros';
  static const String macroEditor = '/macros/editor';
  static const String permissions = '/permissions';
  static const String analytics = '/analytics';
  static const String disciplineMode = '/discipline-mode';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      //case home:
      //  return MaterialPageRoute(builder: (_) => const HomeScreen());

      case habitList:
        return MaterialPageRoute(builder: (_) => const HabitListScreen());

      //case habitEditor:
        //return MaterialPageRoute(builder: (_) => const HabitEditorScreen());

      case calendar:
        return MaterialPageRoute(builder: (_) => const CalendarScreen());

      case macroList:
        return MaterialPageRoute(builder: (_) => const MacroListScreen());

      //case macroEditor:
        //return MaterialPageRoute(builder: (_) => const MacroEditorScreen());

      //case permissions:
        //return MaterialPageRoute(builder: (_) => const PermissionsScreen());

      //case analytics:
        //return MaterialPageRoute(builder: (_) => const AnalyticsScreen());

      //case disciplineMode:
        //return MaterialPageRoute(builder: (_) => const DisciplineModeScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
