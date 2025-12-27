import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_constants.dart';
import 'data/models/habit_model.dart';
import 'data/models/validator_model.dart';
import 'data/models/penalty_model.dart';
import 'data/models/macro_model.dart';
import 'data/models/streak_model.dart';
import 'data/models/execution_log_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await _initHive();

  runApp(const YugoApp());
}

Future<void> _initHive() async {
  await Hive.initFlutter();

  _registerTypeAdapters();

  await Hive.openBox(AppConstants.hiveBoxSettings);
}

void _registerTypeAdapters() {
  Hive.registerAdapter(HabitModelAdapter());
  Hive.registerAdapter(HabitStatusModelAdapter());
  Hive.registerAdapter(HabitStatusAdapter());

  Hive.registerAdapter(ValidatorModelAdapter());
  Hive.registerAdapter(ValidatorTypeAdapter());

  Hive.registerAdapter(PenaltyModelAdapter());
  Hive.registerAdapter(PenaltyTypeAdapter());
  Hive.registerAdapter(PenaltyExecutionStatusAdapter());

  Hive.registerAdapter(MacroModelAdapter());
  Hive.registerAdapter(MacroEventAdapter());
  Hive.registerAdapter(EventTypeAdapter());
  Hive.registerAdapter(MacroConditionAdapter());
  Hive.registerAdapter(ConditionTypeAdapter());
  Hive.registerAdapter(MacroActionAdapter());
  Hive.registerAdapter(ActionTypeAdapter());

  Hive.registerAdapter(StreakModelAdapter());
  Hive.registerAdapter(StreakDayStatusAdapter());

  Hive.registerAdapter(ExecutionLogModelAdapter());
  Hive.registerAdapter(LogTypeAdapter());
  Hive.registerAdapter(LogLevelAdapter());
}

class YugoApp extends StatelessWidget {
  const YugoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yugo'), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Versión ${AppConstants.appVersion}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                AppConstants.appDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funcionalidad en desarrollo...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Comenzar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
