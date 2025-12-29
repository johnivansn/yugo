import 'package:yugo/services/event_dispatcher_service.dart';
import 'package:yugo/services/macro_execution_service.dart';
import 'package:yugo/data/datasources/local/macro_local_datasource.dart';
import 'package:yugo/data/datasources/local/log_local_datasource.dart';
import 'package:yugo/data/repositories/macro_repository_impl.dart';

/// Servicio principal del motor de macros
///
/// Responsabilidades:
/// - Inicializar el EventDispatcher
/// - Mantener la instancia del motor activa
/// - Coordinar la ejecución de macros
class MacroEngineService {
  static MacroEngineService? _instance;

  EventDispatcherService? _eventDispatcher;
  MacroExecutionService? _executionService;
  bool _isInitialized = false;

  MacroEngineService._();

  static MacroEngineService get instance {
    _instance ??= MacroEngineService._();
    return _instance!;
  }

  Future<void> initialize({
    required MacroLocalDataSource macroDataSource,
    required LogLocalDataSource logDataSource,
  }) async {
    if (_isInitialized) {
      print('MacroEngine ya está inicializado');
      return;
    }

    try {
      print('Inicializando MacroEngine...');

      _executionService = MacroExecutionService();

      final macroRepository = MacroRepositoryImpl(
        localDataSource: macroDataSource,
        logDataSource: logDataSource,
        executionService: _executionService!,
      );

      _eventDispatcher = EventDispatcherService(
        macroRepository: macroRepository,
      );

      _isInitialized = true;
      print('MacroEngine inicializado correctamente');
    } catch (e) {
      print('Error al inicializar MacroEngine: $e');
      rethrow;
    }
  }

  EventDispatcherService get eventDispatcher {
    if (!_isInitialized || _eventDispatcher == null) {
      throw StateError(
        'MacroEngine no está inicializado. Llama a initialize() primero.',
      );
    }
    return _eventDispatcher!;
  }

  MacroExecutionService get executionService {
    if (!_isInitialized || _executionService == null) {
      throw StateError(
        'MacroEngine no está inicializado. Llama a initialize() primero.',
      );
    }
    return _executionService!;
  }

  bool get isInitialized => _isInitialized;

  void shutdown() {
    if (_isInitialized) {
      print('Deteniendo MacroEngine...');
      _eventDispatcher?.dispose();
      _eventDispatcher = null;
      _executionService = null;
      _isInitialized = false;
      print('MacroEngine detenido');
    }
  }

  Future<void> restart({
    required MacroLocalDataSource macroDataSource,
    required LogLocalDataSource logDataSource,
  }) async {
    print('Reiniciando MacroEngine...');
    shutdown();
    await initialize(
      macroDataSource: macroDataSource,
      logDataSource: logDataSource,
    );
  }
}
