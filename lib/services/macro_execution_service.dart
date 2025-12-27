import 'package:uuid/uuid.dart';

import '../core/errors/exceptions.dart';
import '../data/models/macro_model.dart';
import '../data/models/execution_log_model.dart';

class MacroExecutionService {
  final Uuid _uuid = const Uuid();

  Future<ExecutionLogModel> executeMacro({
    required MacroModel macro,
    required Map<String, dynamic> eventData,
  }) async {
    final logId = _uuid.v4();
    final timestamp = DateTime.now();

    try {
      if (!macro.isActive) {
        return _createLog(
          id: logId,
          macroId: macro.id,
          level: LogLevel.info,
          message: 'Macro inactiva, no se ejecutó',
          timestamp: timestamp,
        );
      }

      final conditionsResult = await _evaluateConditions(
        macro.conditions,
        eventData,
      );

      if (!conditionsResult.isValid) {
        return _createLog(
          id: logId,
          macroId: macro.id,
          level: LogLevel.info,
          message: 'Condiciones no cumplidas: ${conditionsResult.reason}',
          timestamp: timestamp,
          data: {'evaluated_conditions': conditionsResult.evaluatedConditions},
        );
      }

      final actionsResult = await _executeActions(macro.actions, eventData);

      if (!actionsResult.success) {
        return _createLog(
          id: logId,
          macroId: macro.id,
          level: LogLevel.error,
          message: 'Error al ejecutar acciones',
          timestamp: timestamp,
          errorMessage: actionsResult.errorMessage,
          data: {
            'executed_actions': actionsResult.executedActions,
            'failed_action': actionsResult.failedAction,
          },
        );
      }

      return _createLog(
        id: logId,
        macroId: macro.id,
        level: LogLevel.info,
        message: 'Macro ejecutada exitosamente',
        timestamp: timestamp,
        data: {
          'executed_actions': actionsResult.executedActions,
          'event_data': eventData,
        },
      );
    } catch (e) {
      return _createLog(
        id: logId,
        macroId: macro.id,
        level: LogLevel.error,
        message: 'Error inesperado al ejecutar macro',
        timestamp: timestamp,
        errorMessage: e.toString(),
      );
    }
  }

  Future<_ConditionsEvaluationResult> _evaluateConditions(
    List<MacroCondition> conditions,
    Map<String, dynamic> eventData,
  ) async {
    if (conditions.isEmpty) {
      return _ConditionsEvaluationResult(
        isValid: true,
        evaluatedConditions: [],
      );
    }

    final evaluatedConditions = <String>[];

    for (final condition in conditions) {
      final result = await _evaluateCondition(condition, eventData);
      evaluatedConditions.add(
        '${condition.type.name} ${condition.operator} ${condition.value}: $result',
      );

      if (!result) {
        return _ConditionsEvaluationResult(
          isValid: false,
          reason: 'Condición fallida: ${condition.type.name}',
          evaluatedConditions: evaluatedConditions,
        );
      }
    }

    return _ConditionsEvaluationResult(
      isValid: true,
      evaluatedConditions: evaluatedConditions,
    );
  }

  Future<bool> _evaluateCondition(
    MacroCondition condition,
    Map<String, dynamic> eventData,
  ) async {
    try {
      switch (condition.type) {
        case ConditionType.habitStreak:
          return _evaluateHabitStreakCondition(condition, eventData);

        case ConditionType.timeRange:
          return _evaluateTimeRangeCondition(condition, eventData);

        case ConditionType.dayOfWeek:
          return _evaluateDayOfWeekCondition(condition, eventData);

        case ConditionType.appUsageDuration:
          return _evaluateAppUsageDurationCondition(condition, eventData);

        case ConditionType.disciplineModeActive:
          return _evaluateDisciplineModeCondition(condition, eventData);

        case ConditionType.custom:
          return true;
      }
    } catch (e) {
      throw MacroExecutionException(
        'Error al evaluar condición ${condition.type.name}: $e',
      );
    }
  }

  Future<_ActionsExecutionResult> _executeActions(
    List<MacroAction> actions,
    Map<String, dynamic> eventData,
  ) async {
    final executedActions = <String>[];

    for (final action in actions) {
      try {
        if (action.delaySeconds > 0) {
          await Future.delayed(Duration(seconds: action.delaySeconds));
        }

        await _executeAction(action, eventData);
        executedActions.add(action.type.name);
      } catch (e) {
        return _ActionsExecutionResult(
          success: false,
          executedActions: executedActions,
          failedAction: action.type.name,
          errorMessage: e.toString(),
        );
      }
    }

    return _ActionsExecutionResult(
      success: true,
      executedActions: executedActions,
    );
  }

  Future<void> _executeAction(
    MacroAction action,
    Map<String, dynamic> eventData,
  ) async {
    switch (action.type) {
      case ActionType.executePenalty:
        await _executePenaltyAction(action, eventData);
        break;

      case ActionType.sendNotification:
        await _sendNotificationAction(action, eventData);
        break;

      case ActionType.updateHabitStatus:
        await _updateHabitStatusAction(action, eventData);
        break;

      case ActionType.activateDisciplineMode:
        await _activateDisciplineModeAction(action, eventData);
        break;

      case ActionType.logData:
        await _logDataAction(action, eventData);
        break;

      case ActionType.custom:
        break;
    }
  }

  bool _evaluateHabitStreakCondition(
    MacroCondition condition,
    Map<String, dynamic> eventData,
  ) {
    return true;
  }

  bool _evaluateTimeRangeCondition(
    MacroCondition condition,
    Map<String, dynamic> eventData,
  ) {
    final now = DateTime.now();
    final startHour = condition.config['start_hour'] as int? ?? 0;
    final endHour = condition.config['end_hour'] as int? ?? 23;

    switch (condition.operator) {
      case 'between':
        return now.hour >= startHour && now.hour <= endHour;
      case 'before':
        return now.hour < (condition.value as int);
      case 'after':
        return now.hour > (condition.value as int);
      default:
        return true;
    }
  }

  bool _evaluateDayOfWeekCondition(
    MacroCondition condition,
    Map<String, dynamic> eventData,
  ) {
    final now = DateTime.now();
    final targetDay = condition.value as int;

    switch (condition.operator) {
      case 'equals':
        return now.weekday == targetDay;
      case 'in':
        final days = condition.value as List<int>;
        return days.contains(now.weekday);
      default:
        return true;
    }
  }

  bool _evaluateAppUsageDurationCondition(
    MacroCondition condition,
    Map<String, dynamic> eventData,
  ) {
    return true;
  }

  bool _evaluateDisciplineModeCondition(
    MacroCondition condition,
    Map<String, dynamic> eventData,
  ) {
    return true;
  }

  Future<void> _executePenaltyAction(
    MacroAction action,
    Map<String, dynamic> eventData,
  ) async {
    print('Placeholder: Execute Penalty - ${action.config}');
  }

  Future<void> _sendNotificationAction(
    MacroAction action,
    Map<String, dynamic> eventData,
  ) async {
    print('Placeholder: Send Notification - ${action.config}');
  }

  Future<void> _updateHabitStatusAction(
    MacroAction action,
    Map<String, dynamic> eventData,
  ) async {
    print('Placeholder: Update Habit Status - ${action.config}');
  }

  Future<void> _activateDisciplineModeAction(
    MacroAction action,
    Map<String, dynamic> eventData,
  ) async {
    print('Placeholder: Activate Discipline Mode');
  }

  Future<void> _logDataAction(
    MacroAction action,
    Map<String, dynamic> eventData,
  ) async {
    print('Log: ${action.config}');
  }

  ExecutionLogModel _createLog({
    required String id,
    required String macroId,
    required LogLevel level,
    required String message,
    required DateTime timestamp,
    String? errorMessage,
    Map<String, dynamic>? data,
  }) {
    return ExecutionLogModel(
      id: id,
      type: LogType.macroExecution,
      timestamp: timestamp,
      entityId: macroId,
      entityType: 'macro',
      level: level,
      message: message,
      errorMessage: errorMessage,
      data: data ?? {},
    );
  }
}

class _ConditionsEvaluationResult {
  final bool isValid;
  final String? reason;
  final List<String> evaluatedConditions;

  _ConditionsEvaluationResult({
    required this.isValid,
    this.reason,
    required this.evaluatedConditions,
  });
}

class _ActionsExecutionResult {
  final bool success;
  final List<String> executedActions;
  final String? failedAction;
  final String? errorMessage;

  _ActionsExecutionResult({
    required this.success,
    required this.executedActions,
    this.failedAction,
    this.errorMessage,
  });
}
