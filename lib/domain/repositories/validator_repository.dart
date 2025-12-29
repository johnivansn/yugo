import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../data/models/validator_model.dart';

abstract class ValidatorRepository {
  Future<Either<Failure, List<ValidatorModel>>> getAllValidators();

  Future<Either<Failure, ValidatorModel>> getValidatorById(String id);

  Future<Either<Failure, List<ValidatorModel>>> getActiveValidators();
  Future<Either<Failure, List<ValidatorModel>>> getValidatorsByType(
    ValidatorType type,
  );
  Future<Either<Failure, List<ValidatorModel>>> getPredefinedValidators();
  Future<Either<Failure, List<ValidatorModel>>> getCustomValidators();

  Future<Either<Failure, void>> createValidator(ValidatorModel validator);
  Future<Either<Failure, void>> updateValidator(ValidatorModel validator);
  Future<Either<Failure, void>> deleteValidator(String id);
  Future<Either<Failure, void>> toggleValidatorActive(String id, bool isActive);

  Future<Either<Failure, ValidatorResultModel>> validateHabit({
    required String validatorId,
    required String habitId,
    required Map<String, dynamic> context,
  });

  Future<Either<Failure, Map<String, dynamic>>> exportValidator(String id);

  Future<Either<Failure, ValidatorModel>> importValidator(
    Map<String, dynamic> json,
  );
}
