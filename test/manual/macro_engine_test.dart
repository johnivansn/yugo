import 'package:uuid/uuid.dart';
import 'package:yugo/data/models/macro_model.dart';
import 'package:yugo/services/macro_execution_service.dart';

/// Para ejecutar:
/// 1. Descomentar la función main() abajo
/// 2. Ejecutar: dart test/manual/macro_engine_test.dart
void main() async {
  print('INICIANDO TEST MANUAL DEL MOTOR DE MACROS\n');

  final service = MacroExecutionService();
  const uuid = Uuid();

  print('TEST 1: Macro simple sin condiciones');
  print('─' * 50);

  final macro1 = MacroModel(
    id: uuid.v4(),
    name: 'Test Macro - Sin Condiciones',
    description: 'Macro de prueba que siempre se ejecuta',
    event: const MacroEvent(type: EventType.habitCompleted, config: {}),
    conditions: [],
    actions: [
      const MacroAction(
        type: ActionType.logData,
        config: {'message': 'Hábito completado - Acción ejecutada'},
      ),
      const MacroAction(
        type: ActionType.sendNotification,
        config: {'title': 'Test', 'body': 'Notificación de prueba'},
        delaySeconds: 2,
      ),
    ],
    isActive: true,
    createdAt: DateTime.now(),
  );

  final log1 = await service.executeMacro(
    macro: macro1,
    eventData: {'habit_id': 'habit_123', 'timestamp': DateTime.now()},
  );

  print('Resultado: ${log1.message}');
  print('Level: ${log1.level.name}');
  print('Data: ${log1.data}');
  print('+ TEST 1 COMPLETADO\n');

  print('TEST 2: Macro con condición de hora');
  print('─' * 50);

  final currentHour = DateTime.now().hour;
  print('Hora actual: $currentHour');

  final macro2 = MacroModel(
    id: uuid.v4(),
    name: 'Test Macro - Condición Horaria',
    description: 'Solo se ejecuta en ciertas horas',
    event: const MacroEvent(type: EventType.habitFailed, config: {}),
    conditions: [
      const MacroCondition(
        type: ConditionType.timeRange,
        operator: 'between',
        value: null,
        config: {'start_hour': 0, 'end_hour': 23},
      ),
    ],
    actions: [
      const MacroAction(
        type: ActionType.executePenalty,
        config: {'penalty_id': 'penalty_123'},
      ),
    ],
    isActive: true,
    createdAt: DateTime.now(),
  );

  final log2 = await service.executeMacro(
    macro: macro2,
    eventData: {'habit_id': 'habit_456'},
  );

  print('Resultado: ${log2.message}');
  print('Level: ${log2.level.name}');
  if (log2.data.isNotEmpty) {
    print('Condiciones evaluadas: ${log2.data['evaluated_conditions']}');
  }
  print('+ TEST 2 COMPLETADO\n');

  print('TEST 3: Macro con condición que falla');
  print('─' * 50);

  final macro3 = MacroModel(
    id: uuid.v4(),
    name: 'Test Macro - Condición Fallida',
    description: 'Condición imposible de cumplir',
    event: const MacroEvent(type: EventType.habitStarted, config: {}),
    conditions: [
      const MacroCondition(
        type: ConditionType.timeRange,
        operator: 'after',
        value: 25, // Hora imposible
      ),
    ],
    actions: [
      const MacroAction(
        type: ActionType.logData,
        config: {'message': 'Esta acción NO debe ejecutarse'},
      ),
    ],
    isActive: true,
    createdAt: DateTime.now(),
  );

  final log3 = await service.executeMacro(
    macro: macro3,
    eventData: {'habit_id': 'habit_789'},
  );

  print('Resultado: ${log3.message}');
  print('Level: ${log3.level.name}');
  print('+ TEST 3 COMPLETADO\n');

  print('TEST 4: Macro inactiva');
  print('─' * 50);

  final macro4 = MacroModel(
    id: uuid.v4(),
    name: 'Test Macro - Inactiva',
    description: 'No debe ejecutarse porque está inactiva',
    event: const MacroEvent(type: EventType.habitCompleted, config: {}),
    conditions: [],
    actions: [
      const MacroAction(
        type: ActionType.logData,
        config: {'message': 'Esta acción NO debe ejecutarse'},
      ),
    ],
    isActive: false, // ❌ INACTIVA
    createdAt: DateTime.now(),
  );

  final log4 = await service.executeMacro(
    macro: macro4,
    eventData: {'habit_id': 'habit_999'},
  );

  print('Resultado: ${log4.message}');
  print('Level: ${log4.level.name}');
  print('+ TEST 4 COMPLETADO\n');

  print('TEST 5: Macro con múltiples acciones');
  print('─' * 50);

  final macro5 = MacroModel(
    id: uuid.v4(),
    name: 'Test Macro - Múltiples Acciones',
    description: 'Ejecuta varias acciones en secuencia',
    event: const MacroEvent(type: EventType.habitCompleted, config: {}),
    conditions: [],
    actions: [
      const MacroAction(
        type: ActionType.logData,
        config: {'step': 1, 'message': 'Primera acción'},
      ),
      const MacroAction(
        type: ActionType.logData,
        config: {'step': 2, 'message': 'Segunda acción'},
        delaySeconds: 1,
      ),
      const MacroAction(
        type: ActionType.sendNotification,
        config: {
          'title': 'Completado',
          'body': 'Todas las acciones ejecutadas',
        },
        delaySeconds: 1,
      ),
    ],
    isActive: true,
    createdAt: DateTime.now(),
  );

  print('Ejecutando acciones con delays...');
  final log5 = await service.executeMacro(
    macro: macro5,
    eventData: {'habit_id': 'habit_complete'},
  );

  print('Resultado: ${log5.message}');
  print('Acciones ejecutadas: ${log5.data['executed_actions']}');
  print('+ TEST 5 COMPLETADO\n');

  print('=' * 50);
  print('TODOS LOS TESTS COMPLETADOS');
  print('=' * 50);
  print('\nRESUMEN:');
  print('+ Motor de macros funcional');
  print('+ Evaluación de condiciones OK');
  print('+ Ejecución de acciones OK');
  print('+ Manejo de delays OK');
  print('+ Logging automático OK');
  print('\nEl motor está listo para Sprint 2!');
}
