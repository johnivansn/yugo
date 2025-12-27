import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'validator_model.freezed.dart';
part 'validator_model.g.dart';

@freezed
@HiveType(typeId: 3)
class ValidatorModel with _$ValidatorModel {
  const factory ValidatorModel({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) required String description,
    @HiveField(3) required ValidatorType type,
    @HiveField(4) required Map<String, dynamic> config,
    @HiveField(5) required bool isActive,
    @HiveField(6) required DateTime createdAt,
    @HiveField(7) @Default(false) bool isCustom,
    @HiveField(8) @Default({}) Map<String, dynamic> metadata,
  }) = _ValidatorModel;

  factory ValidatorModel.fromJson(Map<String, dynamic> json) =>
      _$ValidatorModelFromJson(json);
}

@HiveType(typeId: 4)
enum ValidatorType {
  @HiveField(0)
  appUsage,
  @HiveField(1)
  deviceInactivity,
  @HiveField(2)
  location,
  @HiveField(3)
  timeOfDay,
  @HiveField(4)
  dataUsage,
  @HiveField(5)
  stepCount,
  @HiveField(6)
  manual,
  @HiveField(7)
  custom,
}

@freezed
class ValidatorResultModel with _$ValidatorResultModel {
  const factory ValidatorResultModel({
    required String validatorId,
    required String habitId,
    required DateTime timestamp,
    required bool isValid,
    required String message,
    Map<String, dynamic>? evidence,
  }) = _ValidatorResultModel;

  factory ValidatorResultModel.fromJson(Map<String, dynamic> json) =>
      _$ValidatorResultModelFromJson(json);
}
