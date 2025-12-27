import 'dart:async';

import 'package:yugo/data/models/execution_log_model.dart';

import '../data/models/macro_model.dart';
import '../domain/repositories/macro_repository.dart';

class EventDispatcherService {
  final MacroRepository macroRepository;

  final _habitEventController = StreamController<HabitEvent>.broadcast();
  final _systemEventController = StreamController<SystemEvent>.broadcast();
  final _customEventController = StreamController<CustomEvent>.broadcast();

  EventDispatcherService({required this.macroRepository});

  void emitHabitEvent(HabitEvent event) {
    _habitEventController.add(event);
    _processEvent(event.type, event.data);
  }

  void emitSystemEvent(SystemEvent event) {
    _systemEventController.add(event);
    _processEvent(event.type, event.data);
  }

  void emitCustomEvent(CustomEvent event) {
    _customEventController.add(event);
    _processEvent(EventType.custom, event.data);
  }

  Future<void> _processEvent(
    EventType eventType,
    Map<String, dynamic> eventData,
  ) async {
    try {
      final result = await macroRepository.getMacrosByPriority();

      result.fold(
        (failure) {
          print('Error al obtener macros: ${failure.message}');
        },
        (macros) async {
          final matchingMacros = macros.where((macro) {
            return macro.isActive && macro.event.type == eventType;
          }).toList();

          if (matchingMacros.isEmpty) {
            print('No hay macros para el evento: ${eventType.name}');
            return;
          }

          print(
            'Ejecutando ${matchingMacros.length} macro(s) para evento: ${eventType.name}',
          );

          for (final macro in matchingMacros) {
            await _executeMacroSafely(macro, eventData);
          }
        },
      );
    } catch (e) {
      print('Error al procesar evento: $e');
    }
  }

  Future<void> _executeMacroSafely(
    MacroModel macro,
    Map<String, dynamic> eventData,
  ) async {
    try {
      print('Ejecutando macro: ${macro.name}');

      final result = await macroRepository.executeMacro(
        macroId: macro.id,
        eventData: eventData,
      );

      result.fold(
        (failure) {
          print('Macro "${macro.name}" falló: ${failure.message}');
        },
        (log) {
          if (log.level == LogLevel.error) {
            print(
              'Macro "${macro.name}" ejecutada con errores: ${log.message}',
            );
          } else {
            print('Macro "${macro.name}" ejecutada: ${log.message}');
          }
        },
      );
    } catch (e) {
      print('Error inesperado al ejecutar macro "${macro.name}": $e');
    }
  }

  Stream<HabitEvent> get habitEventStream => _habitEventController.stream;

  Stream<SystemEvent> get systemEventStream => _systemEventController.stream;

  Stream<CustomEvent> get customEventStream => _customEventController.stream;

  void dispose() {
    _habitEventController.close();
    _systemEventController.close();
    _customEventController.close();
  }
}

class HabitEvent {
  final EventType type;
  final String habitId;
  final Map<String, dynamic> data;

  HabitEvent({
    required this.type,
    required this.habitId,
    Map<String, dynamic>? data,
  }) : data = {'habit_id': habitId, ...?data};
}

class SystemEvent {
  final EventType type;
  final Map<String, dynamic> data;

  SystemEvent({required this.type, Map<String, dynamic>? data})
    : data = data ?? {};
}

class CustomEvent {
  final String name;
  final Map<String, dynamic> data;

  CustomEvent({required this.name, Map<String, dynamic>? data})
    : data = {'custom_event_name': name, ...?data};
}
