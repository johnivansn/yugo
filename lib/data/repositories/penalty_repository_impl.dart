import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/penalty_repository.dart';
import '../datasources/local/penalty_local_datasource.dart';
import '../models/penalty_model.dart';

/// Implementación del repositorio de Penalizaciones
class PenaltyRepositoryImpl implements PenaltyRepository {
  final PenaltyLocalDataSource localDataSource;
  final Uuid _uuid = const Uuid();

  PenaltyRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<PenaltyModel>>> getAllPenalties() async {
    try {
      final penalties = await localDataSource.getAllPenalties();
      return Right(penalties);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PenaltyModel>> getPenaltyById(String id) async {
    try {
      final penalty = await localDataSource.getPenaltyById(id);
      return Right(penalty);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PenaltyModel>>> getActivePenalties() async {
    try {
      final penalties = await localDataSource.getActivePenalties();
      return Right(penalties);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PenaltyModel>>> getPenaltiesByType(
    PenaltyType type,
  ) async {
    try {
      final penalties = await localDataSource.getPenaltiesByType(type);
      return Right(penalties);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PenaltyModel>>> getRevertiblePenalties() async {
    try {
      final penalties = await localDataSource.getRevertiblePenalties();
      return Right(penalties);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PenaltyModel>>> getPenaltiesByIntensity(
    int minIntensity,
  ) async {
    try {
      final penalties = await localDataSource.getPenaltiesByIntensity(
        minIntensity,
      );
      return Right(penalties);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createPenalty(PenaltyModel penalty) async {
    try {
      await localDataSource.createPenalty(penalty);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePenalty(PenaltyModel penalty) async {
    try {
      await localDataSource.updatePenalty(penalty);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deletePenalty(String id) async {
    try {
      await localDataSource.deletePenalty(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> togglePenaltyActive(
    String id,
    bool isActive,
  ) async {
    try {
      await localDataSource.togglePenaltyActive(id, isActive);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PenaltyExecutionModel>> executePenalty({
    required String penaltyId,
    required String habitId,
    Map<String, dynamic>? context,
  }) async {
    try {

      final execution = PenaltyExecutionModel(
        id: _uuid.v4(),
        penaltyId: penaltyId,
        habitId: habitId,
        executedAt: DateTime.now(),
        status: PenaltyExecutionStatus.executing,
        executionData: context,
      );

      await localDataSource.createPenaltyExecution(execution);

      final completedExecution = execution.copyWith(
        status: PenaltyExecutionStatus.executed,
      );

      await localDataSource.createPenaltyExecution(completedExecution);

      return Right(completedExecution);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } on PenaltyExecutionException catch (e) {
      return Left(PenaltyExecutionFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> revertPenalty(String executionId) async {
    try {
      print('Reverting penalty execution: $executionId');
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } on PenaltyExecutionException catch (e) {
      return Left(PenaltyExecutionFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PenaltyExecutionModel>>> getPenaltyExecutions(
    String penaltyId,
  ) async {
    try {
      final executions = await localDataSource.getPenaltyExecutions(penaltyId);
      return Right(executions);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PenaltyExecutionModel>>> getExecutionsByHabit(
    String habitId,
  ) async {
    try {
      final executions = await localDataSource.getExecutionsByHabit(habitId);
      return Right(executions);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportPenalty(String id) async {
    try {
      final penalty = await localDataSource.getPenaltyById(id);
      final json = penalty.toJson();
      return Right(json);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PenaltyModel>> importPenalty(
    Map<String, dynamic> json,
  ) async {
    try {
      final penalty = PenaltyModel.fromJson(json);
      await localDataSource.createPenalty(penalty);
      return Right(penalty);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(ValidationFailure('JSON inválido: $e'));
    }
  }
}
