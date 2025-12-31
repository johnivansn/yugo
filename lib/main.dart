import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/storage_keys.dart';

import 'data/datasources/local/log_local_datasource.dart';
import 'data/datasources/local/macro_local_datasource.dart';

import 'data/models/execution_log_model.dart';
import 'data/models/habit_model.dart';
import 'data/models/macro_model.dart';
import 'data/models/penalty_model.dart';
import 'data/models/streak_model.dart';
import 'data/models/validator_model.dart';

import 'presentation/screens/calendar/calendar_screen.dart';
import 'presentation/screens/habits/habit_list_screen.dart';
import 'presentation/screens/logs/logs_screen.dart';
import 'presentation/screens/macros/macro_list_screen.dart';
import 'presentation/screens/penalties/penalty_list_screen.dart';
import 'presentation/screens/streaks/streak_list_screen.dart';
import 'presentation/screens/validators/validator_list_screen.dart';

import 'services/battery_optimization_service.dart';
import 'services/event_dispatcher_service.dart';
import 'services/foreground_service_manager.dart';
import 'services/macro_engine_service.dart';
import 'services/test_data_helper.dart';

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
  Hive.registerAdapter(ActionTypeAdapter());
  Hive.registerAdapter(ConditionTypeAdapter());
  Hive.registerAdapter(EventTypeAdapter());
  Hive.registerAdapter(ExecutionLogModelAdapter());
  Hive.registerAdapter(HabitModelAdapter());
  Hive.registerAdapter(HabitStatusAdapter());
  Hive.registerAdapter(HabitStatusModelAdapter());
  Hive.registerAdapter(LogLevelAdapter());
  Hive.registerAdapter(LogTypeAdapter());
  Hive.registerAdapter(MacroActionAdapter());
  Hive.registerAdapter(MacroConditionAdapter());
  Hive.registerAdapter(MacroEventAdapter());
  Hive.registerAdapter(MacroModelAdapter());
  Hive.registerAdapter(PenaltyExecutionStatusAdapter());
  Hive.registerAdapter(PenaltyModelAdapter());
  Hive.registerAdapter(PenaltyTypeAdapter());
  Hive.registerAdapter(StreakDayStatusAdapter());
  Hive.registerAdapter(StreakModelAdapter());
  Hive.registerAdapter(ValidatorModelAdapter());
  Hive.registerAdapter(ValidatorTypeAdapter());
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
  bool _isLoadingTestData = false;
  String? _testDataMessage;
  bool _isEmittingEvent = false;
  String? _eventMessage;

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

  Future<void> _createTestData() async {
    setState(() {
      _isLoadingTestData = true;
      _testDataMessage = null;
    });

    try {
      final testData = TestDataHelper.createFullTestDataSet();

      for (final validator in testData.validators) {
        final box = Hive.box<ValidatorModel>(StorageKeys.validatorsBox);
        await box.put(validator.id, validator);
      }

      for (final habit in testData.habits) {
        final box = Hive.box<HabitModel>(StorageKeys.habitsBox);
        await box.put(habit.id, habit);
      }

      for (final penalty in testData.penalties) {
        final box = Hive.box<PenaltyModel>(StorageKeys.penaltiesBox);
        await box.put(penalty.id, penalty);
      }

      for (final streak in testData.streaks) {
        final box = Hive.box<StreakModel>(StorageKeys.streaksBox);
        await box.put(streak.id, streak);
      }

      for (final macro in testData.macros) {
        final box = Hive.box<MacroModel>(StorageKeys.macrosBox);
        await box.put(macro.id, macro);
      }

      setState(() {
        _testDataMessage =
            '✅ ${testData.totalItems} elementos creados:\n'
            '• ${testData.validators.length} validadores\n'
            '• ${testData.habits.length} hábitos\n'
            '• ${testData.penalties.length} penalizaciones\n'
            '• ${testData.streaks.length} rachas\n'
            '• ${testData.macros.length} macros';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Datos de prueba creados correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _testDataMessage = '❌ Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al crear datos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingTestData = false;
      });
    }
  }

  Future<void> _emitTestEvent(EventType eventType) async {
    if (!_engineStatus) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Motor no está inicializado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isEmittingEvent = true;
      _eventMessage = null;
    });

    try {
      final dispatcher = MacroEngineService.instance.eventDispatcher;
      final habits = Hive.box<HabitModel>(StorageKeys.habitsBox);

      if (habits.isEmpty) {
        setState(() {
          _eventMessage =
              '⚠️ No hay hábitos creados\nCrea datos de prueba primero';
        });
        return;
      }

      final firstHabit = habits.values.first;

      switch (eventType) {
        case EventType.habitCompleted:
          dispatcher.emitHabitEvent(
            HabitEvent(
              type: EventType.habitCompleted,
              habitId: firstHabit.id,
              data: {
                'completed_at': DateTime.now().toIso8601String(),
                'source': 'manual_test',
              },
            ),
          );
          break;

        case EventType.habitFailed:
          dispatcher.emitHabitEvent(
            HabitEvent(
              type: EventType.habitFailed,
              habitId: firstHabit.id,
              data: {
                'failed_at': DateTime.now().toIso8601String(),
                'reason': 'test_failure',
              },
            ),
          );
          break;

        case EventType.habitStarted:
          dispatcher.emitHabitEvent(
            HabitEvent(
              type: EventType.habitStarted,
              habitId: firstHabit.id,
              data: {'started_at': DateTime.now().toIso8601String()},
            ),
          );
          break;

        default:
          dispatcher.emitSystemEvent(
            SystemEvent(
              type: eventType,
              data: {'triggered_at': DateTime.now().toIso8601String()},
            ),
          );
      }

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _eventMessage =
            '✅ Evento emitido: ${eventType.name}\n'
            'Hábito: ${firstHabit.name}\n'
            'Revisa los logs para ver la ejecución';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚀 Evento ${eventType.name} emitido'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _eventMessage = '❌ Error al emitir evento: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isEmittingEvent = false;
      });
    }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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

              // Botón crear datos
              ElevatedButton.icon(
                onPressed: _isLoadingTestData ? null : _createTestData,
                icon: _isLoadingTestData
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.science),
                label: Text(
                  _isLoadingTestData ? 'Creando...' : 'Crear Datos de Prueba',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Botón para ver logs
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogsScreen()),
                  );
                },
                icon: const Icon(Icons.description),
                label: const Text('Ver Logs de Ejecución'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón para ver macros
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MacroListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.dashboard_customize),
                label: const Text('Ver Macros'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón para ver hábitos
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HabitListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.task_alt),
                label: const Text('Ver Hábitos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón para ver penalizaciones
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PenaltyListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.warning_amber),
                label: const Text('Ver Penalizaciones'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón para ver validadores
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ValidatorListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.verified_user),
                label: const Text('Ver Validadores'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Botón para ver rachas
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StreakListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.local_fire_department),
                label: const Text('Ver Rachas'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón para ver calendario
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CalendarScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Ver Calendario'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),

              if (_testDataMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: _testDataMessage!.startsWith('✅')
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _testDataMessage!.startsWith('✅')
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Text(
                    _testDataMessage!,
                    style: TextStyle(
                      color: _testDataMessage!.startsWith('✅')
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // SECCIÓN DE TEST DE EVENTOS
              Text(
                'Emitir Eventos de Prueba',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Prueba el dispatcher emitiendo eventos manualmente',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isEmittingEvent
                        ? null
                        : () => _emitTestEvent(EventType.habitCompleted),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text('Hábito\nCompletado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isEmittingEvent
                        ? null
                        : () => _emitTestEvent(EventType.habitFailed),
                    icon: const Icon(Icons.cancel, size: 20),
                    label: const Text('Hábito\nFallido'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isEmittingEvent
                        ? null
                        : () => _emitTestEvent(EventType.habitStarted),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Hábito\nIniciado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),

              if (_eventMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: _eventMessage!.startsWith('✅')
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _eventMessage!.startsWith('✅')
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  ),
                  child: Text(
                    _eventMessage!,
                    style: TextStyle(
                      color: _eventMessage!.startsWith('✅')
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
