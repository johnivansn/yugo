import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/storage_keys.dart';

import 'data/models/habit_model.dart';
import 'data/models/validator_model.dart';
import 'data/models/penalty_model.dart';
import 'data/models/macro_model.dart';
import 'data/models/streak_model.dart';
import 'data/models/execution_log_model.dart';

import 'services/foreground_service_manager.dart';
import 'services/battery_optimization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await _initHive();
  await _initServices();

  runApp(const YugoApp());
}

Future<void> _initHive() async {
  await Hive.initFlutter();

  _registerTypeAdapters();

  await _openBoxes();
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

Future<void> _openBoxes() async {
  try {
    await Hive.openBox(AppConstants.hiveBoxSettings);
    await Hive.openBox<HabitModel>(StorageKeys.habitsBox);
    await Hive.openBox<ValidatorModel>(StorageKeys.validatorsBox);
    await Hive.openBox<PenaltyModel>(StorageKeys.penaltiesBox);
    await Hive.openBox<MacroModel>(StorageKeys.macrosBox);
    await Hive.openBox<StreakModel>(StorageKeys.streaksBox);
    await Hive.openBox<ExecutionLogModel>(StorageKeys.executionLogsBox);
    await Hive.openBox<HabitStatusModel>(StorageKeys.habitStatusBox);
    await Hive.openBox<PenaltyExecutionModel>(StorageKeys.penaltyExecutionsBox);

    print('All Hive boxes opened successfully');
  } catch (e) {
    print('Error opening Hive boxes: $e');
    rethrow;
  }
}

Future<void> _initServices() async {
  try {
    print('Initializing services...');

    final serviceManager = ForegroundServiceManager();
    await serviceManager.ensureServiceRunning();

    final batteryService = BatteryOptimizationService();
    final status = await batteryService.checkAndRequest();

    if (status == BatteryOptimizationStatus.enabled) {
      print('Battery optimization is enabled - service may be killed');
      print('ℹUser should disable it in Settings for best performance');
    }

    print('Services initialized');
  } catch (e) {
    print('Error initializing services: $e');
  }
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
