import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
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
