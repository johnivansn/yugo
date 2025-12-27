import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'penalty_model.freezed.dart';
part 'penalty_model.g.dart';

@freezed
@HiveType(typeId: 5)
class PenaltyModel with _$PenaltyModel {
  const factory PenaltyModel({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) required String description,
    @HiveField(3) required PenaltyType type,
    @HiveField(4) required Map<String, dynamic> config,
    @HiveField(5) required bool isActive,
    @HiveField(6) required DateTime createdAt,
    @HiveField(7) @Default(false) bool isRevertible,
    @HiveField(8) @Default(false) bool isCustom,
    @HiveField(9) @Default(1) int intensity,
    @HiveField(10) int? durationMinutes,
    @HiveField(11) @Default([]) List<String> targetApps,
    @HiveField(12) @Default({}) Map<String, dynamic> metadata,
  }) = _PenaltyModel;

  factory PenaltyModel.fromJson(Map<String, dynamic> json) =>
      _$PenaltyModelFromJson(json);
}

@HiveType(typeId: 6)
enum PenaltyType {
  @HiveField(0)
  appBlock,
  @HiveField(1)
  persistentNotification,
  @HiveField(2)
  brightnessControl,
  @HiveField(3)
  volumeControl,
  @HiveField(4)
  dataRestriction,
  @HiveField(5)
  screenTimeLimit,
  @HiveField(6)
  custom,
}

@freezed
class PenaltyExecutionModel with _$PenaltyExecutionModel {
  const factory PenaltyExecutionModel({
    required String id,
    required String penaltyId,
    required String habitId,
    required DateTime executedAt,
    DateTime? revertedAt,
    required PenaltyExecutionStatus status,
    String? errorMessage,
    Map<String, dynamic>? executionData,
  }) = _PenaltyExecutionModel;

  factory PenaltyExecutionModel.fromJson(Map<String, dynamic> json) =>
      _$PenaltyExecutionModelFromJson(json);
}

@HiveType(typeId: 7)
enum PenaltyExecutionStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  executing,
  @HiveField(2)
  executed,
  @HiveField(3)
  failed,
  @HiveField(4)
  reverted,
}
