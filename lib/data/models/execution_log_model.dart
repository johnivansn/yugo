import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'execution_log_model.freezed.dart';
part 'execution_log_model.g.dart';

@freezed
@HiveType(typeId: 17)
class ExecutionLogModel with _$ExecutionLogModel {
  const factory ExecutionLogModel({
    @HiveField(0) required String id,
    @HiveField(1) required LogType type,
    @HiveField(2) required DateTime timestamp,
    @HiveField(3) required String entityId,
    @HiveField(4) required String entityType,
    @HiveField(5) required LogLevel level,
    @HiveField(6) required String message,
    @HiveField(7) String? errorMessage,
    @HiveField(8) @Default({}) Map<String, dynamic> data,
    @HiveField(9) @Default({}) Map<String, dynamic> metadata,
  }) = _ExecutionLogModel;

  factory ExecutionLogModel.fromJson(Map<String, dynamic> json) =>
      _$ExecutionLogModelFromJson(json);
}

@HiveType(typeId: 18)
enum LogType {
  @HiveField(0)
  macroExecution,
  @HiveField(1)
  penaltyExecution,
  @HiveField(2)
  habitValidation,
  @HiveField(3)
  systemEvent,
  @HiveField(4)
  error,
  @HiveField(5)
  info,
}

@HiveType(typeId: 19)
enum LogLevel {
  @HiveField(0)
  debug,
  @HiveField(1)
  info,
  @HiveField(2)
  warning,
  @HiveField(3)
  error,
  @HiveField(4)
  critical,
}

@freezed
class MacroExecutionLogModel with _$MacroExecutionLogModel {
  const factory MacroExecutionLogModel({
    required String macroId,
    required String macroName,
    required DateTime executedAt,
    required bool success,
    required String eventTrigger,
    required List<String> evaluatedConditions,
    required List<String> executedActions,
    String? errorMessage,
    Map<String, dynamic>? executionData,
  }) = _MacroExecutionLogModel;

  factory MacroExecutionLogModel.fromJson(Map<String, dynamic> json) =>
      _$MacroExecutionLogModelFromJson(json);
}
