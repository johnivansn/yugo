import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'macro_model.freezed.dart';
part 'macro_model.g.dart';

@freezed
@HiveType(typeId: 8)
class MacroModel with _$MacroModel {
  const factory MacroModel({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) required String description,
    @HiveField(3) required MacroEvent event,
    @HiveField(4) required List<MacroCondition> conditions,
    @HiveField(5) required List<MacroAction> actions,
    @HiveField(6) required bool isActive,
    @HiveField(7) required DateTime createdAt,
    @HiveField(8) @Default(false) bool isCustom,
    @HiveField(9) @Default(1) int priority,
    @HiveField(10) @Default({}) Map<String, dynamic> metadata,
  }) = _MacroModel;

  factory MacroModel.fromJson(Map<String, dynamic> json) =>
      _$MacroModelFromJson(json);
}

@freezed
@HiveType(typeId: 9)
class MacroEvent with _$MacroEvent {
  const factory MacroEvent({
    @HiveField(0) required EventType type,
    @HiveField(1) required Map<String, dynamic> config,
  }) = _MacroEvent;

  factory MacroEvent.fromJson(Map<String, dynamic> json) =>
      _$MacroEventFromJson(json);
}

@HiveType(typeId: 10)
enum EventType {
  @HiveField(0)
  habitCompleted,
  @HiveField(1)
  habitFailed,
  @HiveField(2)
  habitStarted,
  @HiveField(3)
  timeOfDay,
  @HiveField(4)
  appOpened,
  @HiveField(5)
  deviceInactive,
  @HiveField(6)
  custom,
}

@freezed
@HiveType(typeId: 11)
class MacroCondition with _$MacroCondition {
  const factory MacroCondition({
    @HiveField(0) required ConditionType type,
    @HiveField(1) required String operator,
    @HiveField(2) required dynamic value,
    @HiveField(3) @Default({}) Map<String, dynamic> config,
  }) = _MacroCondition;

  factory MacroCondition.fromJson(Map<String, dynamic> json) =>
      _$MacroConditionFromJson(json);
}

@HiveType(typeId: 12)
enum ConditionType {
  @HiveField(0)
  habitStreak,
  @HiveField(1)
  timeRange,
  @HiveField(2)
  dayOfWeek,
  @HiveField(3)
  appUsageDuration,
  @HiveField(4)
  disciplineModeActive,
  @HiveField(5)
  custom,
}

@freezed
@HiveType(typeId: 13)
class MacroAction with _$MacroAction {
  const factory MacroAction({
    @HiveField(0) required ActionType type,
    @HiveField(1) required Map<String, dynamic> config,
    @HiveField(2) @Default(0) int delaySeconds,
  }) = _MacroAction;

  factory MacroAction.fromJson(Map<String, dynamic> json) =>
      _$MacroActionFromJson(json);
}

@HiveType(typeId: 14)
enum ActionType {
  @HiveField(0)
  executePenalty,
  @HiveField(1)
  sendNotification,
  @HiveField(2)
  updateHabitStatus,
  @HiveField(3)
  activateDisciplineMode,
  @HiveField(4)
  logData,
  @HiveField(5)
  custom,
}
