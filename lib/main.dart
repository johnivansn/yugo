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
import 'data/datasources/local/macro_local_datasource.dart';
import 'data/datasources/local/log_local_datasource.dart';

import 'services/foreground_service_manager.dart';
import 'services/battery_optimization_service.dart';
import 'services/macro_engine_service.dart';

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

    print('✅ All Hive boxes opened successfully');
  } catch (e) {
    print('❌ Error opening Hive boxes: $e');
    rethrow;
  }
}

Future<void> _initServices() async {
  try {
    print('🚀 Initializing services...');
    await _initMacroEngine();
    final serviceManager = ForegroundServiceManager();
    await serviceManager.ensureServiceRunning();
    final batteryService = BatteryOptimizationService();
    final status = await batteryService.checkAndRequest();

    if (status == BatteryOptimizationStatus.enabled) {
      print('⚠️ Battery optimization is enabled - service may be killed');
      print('ℹ️  User should disable it in Settings for best performance');
    }

    print('✅ Services initialized');
  } catch (e) {
    print('❌ Error initializing services: $e');
  }
}

Future<void> _initMacroEngine() async {
  try {
    print('🚀 Initializing MacroEngine...');

    final macroDataSource = MacroLocalDataSourceImpl();
    await macroDataSource.init();

    final logDataSource = LogLocalDataSourceImpl();
    await logDataSource.init();

    await MacroEngineService.instance.initialize(
      macroDataSource: macroDataSource,
      logDataSource: logDataSource,
    );

    print('✅ MacroEngine initialized successfully');
  } catch (e) {
    print('❌ Error initializing MacroEngine: $e');
    rethrow;
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _engineStatus = false;

  @override
  void initState() {
    super.initState();
    _checkEngineStatus();
  }

  void _checkEngineStatus() {
    setState(() {
      _engineStatus = MacroEngineService.instance.isInitialized;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yugo'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _engineStatus ? Icons.check_circle : Icons.error,
              color: _engineStatus ? Colors.green : Colors.red,
            ),
            onPressed: _checkEngineStatus,
            tooltip: _engineStatus ? 'Motor activo' : 'Motor inactivo',
          ),
        ],
      ),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _engineStatus
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _engineStatus ? Icons.check_circle : Icons.error,
                    color: _engineStatus ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _engineStatus ? 'Motor activo' : 'Motor inactivo',
                    style: TextStyle(
                      color: _engineStatus ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
