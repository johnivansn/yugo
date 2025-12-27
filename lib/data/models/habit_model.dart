import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'habit_model.freezed.dart';
part 'habit_model.g.dart';

/// Modelo de Hábito
@freezed
@HiveType(typeId: 0)
class HabitModel with _$HabitModel {
  const factory HabitModel({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) required String description,
    @HiveField(3) required bool isActive,
    @HiveField(4) required DateTime createdAt,
    @HiveField(5) required DateTime updatedAt,
    @HiveField(6) required String validatorId,
    @HiveField(7) required Map<String, dynamic> validatorConfig,
    @HiveField(8) required List<String> penaltyIds,
    @HiveField(9) @Default(false) bool autoExecutePenalties,
    @HiveField(10) String? scheduledTime,
    @HiveField(11) @Default([]) List<int> activeDays,
    @HiveField(12) @Default(0) int currentStreak,
    @HiveField(13) @Default(0) int longestStreak,
    @HiveField(14) @Default(0) int totalCompletions,
    @HiveField(15) @Default(0) int totalFailures,
    @HiveField(16) @Default(false) bool isDisciplineMode,
    @HiveField(17) @Default(1) int priority,
    @HiveField(18) @Default({}) Map<String, dynamic> metadata,
  }) = _HabitModel;

  factory HabitModel.fromJson(Map<String, dynamic> json) =>
      _$HabitModelFromJson(json);
}

@freezed
@HiveType(typeId: 1)
class HabitStatusModel with _$HabitStatusModel {
  const factory HabitStatusModel({
    @HiveField(0) required String habitId,
    @HiveField(1) required DateTime date,
    @HiveField(2) required HabitStatus status,
    @HiveField(3) DateTime? completedAt,
    @HiveField(4) String? validationMethod,
    @HiveField(5) List<String>? executedPenaltyIds,
    @HiveField(6) Map<String, dynamic>? validationData,
  }) = _HabitStatusModel;

  factory HabitStatusModel.fromJson(Map<String, dynamic> json) =>
      _$HabitStatusModelFromJson(json);
}

@HiveType(typeId: 2)
enum HabitStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  completed,
  @HiveField(2)
  failed,
  @HiveField(3)
  skipped,
  @HiveField(4)
  inProgress,
}
