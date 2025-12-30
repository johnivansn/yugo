import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/validator_repository.dart';
import '../datasources/local/validator_local_datasource.dart';
import '../models/validator_model.dart';

/// Implementación del repositorio de Validadores
class ValidatorRepositoryImpl implements ValidatorRepository {
  final ValidatorLocalDataSource localDataSource;

  ValidatorRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<ValidatorModel>>> getAllValidators() async {
    try {
      final validators = await localDataSource.getAllValidators();
      return Right(validators);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ValidatorModel>> getValidatorById(String id) async {
    try {
      final validator = await localDataSource.getValidatorById(id);
      return Right(validator);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ValidatorModel>>> getActiveValidators() async {
    try {
      final validators = await localDataSource.getActiveValidators();
      return Right(validators);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ValidatorModel>>> getValidatorsByType(
    ValidatorType type,
  ) async {
    try {
      final validators = await localDataSource.getValidatorsByType(type);
      return Right(validators);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ValidatorModel>>>
  getPredefinedValidators() async {
    try {
      final validators = await localDataSource.getPredefinedValidators();
      return Right(validators);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ValidatorModel>>> getCustomValidators() async {
    try {
      final validators = await localDataSource.getCustomValidators();
      return Right(validators);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createValidator(
    ValidatorModel validator,
  ) async {
    try {
      await localDataSource.createValidator(validator);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateValidator(
    ValidatorModel validator,
  ) async {
    try {
      await localDataSource.updateValidator(validator);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteValidator(String id) async {
    try {
      await localDataSource.deleteValidator(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleValidatorActive(
    String id,
    bool isActive,
  ) async {
    try {
      await localDataSource.toggleValidatorActive(id, isActive);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ValidatorResultModel>> validateHabit({
    required String validatorId,
    required String habitId,
    required Map<String, dynamic> context,
  }) async {
    try {
      final result = ValidatorResultModel(
        validatorId: validatorId,
        habitId: habitId,
        timestamp: DateTime.now(),
        isValid: true,
        message: 'Validación placeholder - Implementar en Sprint 3',
        evidence: context,
      );

      return Right(result);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportValidator(
    String id,
  ) async {
    try {
      final validator = await localDataSource.getValidatorById(id);
      final json = validator.toJson();
      return Right(json);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ValidatorModel>> importValidator(
    Map<String, dynamic> json,
  ) async {
    try {
      final validator = ValidatorModel.fromJson(json);
      await localDataSource.createValidator(validator);
      return Right(validator);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(ValidationFailure('JSON inválido: $e'));
    }
  }
}
