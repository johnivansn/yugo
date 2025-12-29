import 'package:uuid/uuid.dart';
import '../data/models/macro_model.dart';
import '../data/models/habit_model.dart';
import '../data/models/validator_model.dart';
import '../data/models/penalty_model.dart';
import '../data/models/streak_model.dart';

/// Helper para crear datos de prueba
class TestDataHelper {
  static const Uuid _uuid = Uuid();

  /// Crea una macro de prueba simple: cuando se completa un hábito, enviar notificación
  static MacroModel createSimpleNotificationMacro() {
    return MacroModel(
      id: _uuid.v4(),
      name: 'Notificación al completar hábito',
      description: 'Envía una notificación cuando se completa cualquier hábito',
      event: const MacroEvent(type: EventType.habitCompleted, config: {}),
      conditions: [], // Sin condiciones, siempre se ejecuta
      actions: [
        const MacroAction(
          type: ActionType.sendNotification,
          config: {
            'title': 'Hábito completado',
            'body': '¡Bien hecho! Has completado un hábito',
            'priority': 'high',
          },
          delaySeconds: 0,
        ),
        const MacroAction(
          type: ActionType.logData,
          config: {'message': 'Macro de prueba ejecutada correctamente'},
          delaySeconds: 0,
        ),
      ],
      isActive: true,
      createdAt: DateTime.now(),
      isCustom: false,
      priority: 1,
    );
  }

  /// Crea una macro de penalización: cuando falla un hábito, ejecutar penalización
  static MacroModel createPenaltyMacro(String penaltyId) {
    return MacroModel(
      id: _uuid.v4(),
      name: 'Penalización por fallo',
      description: 'Ejecuta penalización cuando falla un hábito',
      event: const MacroEvent(type: EventType.habitFailed, config: {}),
      conditions: [],
      actions: [
        MacroAction(
          type: ActionType.executePenalty,
          config: {'penalty_id': penaltyId},
          delaySeconds: 0,
        ),
        const MacroAction(
          type: ActionType.sendNotification,
          config: {
            'title': 'Hábito fallido',
            'body': 'Se ha aplicado una penalización',
            'priority': 'high',
          },
          delaySeconds: 0,
        ),
      ],
      isActive: true,
      createdAt: DateTime.now(),
      isCustom: false,
      priority: 2,
    );
  }

  /// Crea una macro con condición de tiempo: solo de 8AM a 10PM
  static MacroModel createTimeConditionMacro() {
    return MacroModel(
      id: _uuid.v4(),
      name: 'Notificación diurna',
      description: 'Solo notifica durante el día (8AM - 10PM)',
      event: const MacroEvent(type: EventType.habitCompleted, config: {}),
      conditions: [
        const MacroCondition(
          type: ConditionType.timeRange,
          operator: 'between',
          value: null,
          config: {'start_hour': 8, 'end_hour': 22},
        ),
      ],
      actions: [
        const MacroAction(
          type: ActionType.sendNotification,
          config: {
            'title': 'Hábito completado (horario diurno)',
            'body': 'Completado durante horas activas',
          },
          delaySeconds: 0,
        ),
      ],
      isActive: true,
      createdAt: DateTime.now(),
      isCustom: false,
      priority: 1,
    );
  }

  /// Crea un hábito de prueba simple
  static HabitModel createSimpleHabit(String validatorId) {
    return HabitModel(
      id: _uuid.v4(),
      name: 'Leer 30 minutos',
      description: 'Leer al menos 30 minutos al día',
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      validatorId: validatorId,
      validatorConfig: {
        'app_package': 'com.example.reading_app',
        'min_duration_minutes': 30,
      },
      penaltyIds: [],
      autoExecutePenalties: true,
      activeDays: [1, 2, 3, 4, 5, 6, 7], // Todos los días
      priority: 1,
    );
  }

  /// Crea un validador manual de prueba
  static ValidatorModel createManualValidator() {
    return ValidatorModel(
      id: _uuid.v4(),
      name: 'Validación Manual',
      description: 'El usuario marca manualmente cuando completa',
      type: ValidatorType.manual,
      config: {},
      isActive: true,
      createdAt: DateTime.now(),
      isCustom: false,
    );
  }

  /// Crea un validador de uso de app
  static ValidatorModel createAppUsageValidator() {
    return ValidatorModel(
      id: _uuid.v4(),
      name: 'Uso de App',
      description: 'Valida que se use una app específica por X minutos',
      type: ValidatorType.appUsage,
      config: {'min_duration_minutes': 30, 'check_frequency_minutes': 5},
      isActive: true,
      createdAt: DateTime.now(),
      isCustom: false,
    );
  }

  /// Crea una penalización de notificación persistente
  static PenaltyModel createPersistentNotificationPenalty() {
    return PenaltyModel(
      id: _uuid.v4(),
      name: 'Notificación Persistente',
      description: 'Muestra una notificación molesta que no se puede quitar',
      type: PenaltyType.persistentNotification,
      config: {
        'message': '¡Fallaste tu hábito! No lo olvides.',
        'vibration_pattern': [0, 500, 200, 500],
      },
      isActive: true,
      createdAt: DateTime.now(),
      isRevertible: true,
      intensity: 2,
      durationMinutes: 60,
    );
  }

  /// Crea una racha de prueba
  static StreakModel createStreak(String habitId) {
    return StreakModel(
      id: _uuid.v4(),
      habitId: habitId,
      currentStreak: 3,
      longestStreak: 5,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      isActive: true,
      totalCompletions: 5,
      totalFailures: 2,
      completedDates: [
        DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      ],
      failedDates: [
        DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      ],
    );
  }

  /// Crea conjunto completo de datos de prueba
  static TestDataSet createFullTestDataSet() {
    final validator = createManualValidator();
    final habit = createSimpleHabit(validator.id);
    final penalty = createPersistentNotificationPenalty();
    final streak = createStreak(habit.id);

    final macros = [
      createSimpleNotificationMacro(),
      createPenaltyMacro(penalty.id),
      createTimeConditionMacro(),
    ];

    return TestDataSet(
      validators: [validator, createAppUsageValidator()],
      habits: [habit],
      penalties: [penalty],
      streaks: [streak],
      macros: macros,
    );
  }
}

/// Clase que agrupa un conjunto de datos de prueba
class TestDataSet {
  final List<ValidatorModel> validators;
  final List<HabitModel> habits;
  final List<PenaltyModel> penalties;
  final List<StreakModel> streaks;
  final List<MacroModel> macros;

  TestDataSet({
    required this.validators,
    required this.habits,
    required this.penalties,
    required this.streaks,
    required this.macros,
  });

  int get totalItems =>
      validators.length +
      habits.length +
      penalties.length +
      streaks.length +
      macros.length;
}
