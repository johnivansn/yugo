import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'streak_model.freezed.dart';
part 'streak_model.g.dart';

@freezed
@HiveType(typeId: 15)
class StreakModel with _$StreakModel {
  const factory StreakModel({
    @HiveField(0) required String id,
    @HiveField(1) required String habitId,
    @HiveField(2) required int currentStreak,
    @HiveField(3) required int longestStreak,
    @HiveField(4) required DateTime startDate,
    @HiveField(5) DateTime? endDate,
    @HiveField(6) required bool isActive,
    @HiveField(7) @Default(0) int totalCompletions,
    @HiveField(8) @Default(0) int totalFailures,
    @HiveField(9) @Default([]) List<String> completedDates,
    @HiveField(10) @Default([]) List<String> failedDates,
    @HiveField(11) @Default({}) Map<String, dynamic> metadata,
  }) = _StreakModel;

  factory StreakModel.fromJson(Map<String, dynamic> json) =>
      _$StreakModelFromJson(json);
}

@freezed
class StreakDayModel with _$StreakDayModel {
  const factory StreakDayModel({
    required String habitId,
    required DateTime date,
    required StreakDayStatus status,
    List<String>? executedPenaltyIds,
    List<String>? avoidedPenaltyIds,
    String? validationMethod,
    Map<String, dynamic>? metadata,
  }) = _StreakDayModel;

  factory StreakDayModel.fromJson(Map<String, dynamic> json) =>
      _$StreakDayModelFromJson(json);
}

@HiveType(typeId: 16)
enum StreakDayStatus {
  @HiveField(0)
  completed,
  @HiveField(1)
  failed,
  @HiveField(2)
  skipped,
  @HiveField(3)
  pending,
}
