import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/streak_repository.dart';
import '../datasources/local/streak_local_datasource.dart';
import '../models/streak_model.dart';

/// Implementación del repositorio de Rachas
class StreakRepositoryImpl implements StreakRepository {
  final StreakLocalDataSource localDataSource;

  StreakRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<StreakModel>>> getAllStreaks() async {
    try {
      final streaks = await localDataSource.getAllStreaks();
      return Right(streaks);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, StreakModel>> getStreakById(String id) async {
    try {
      final streak = await localDataSource.getStreakById(id);
      return Right(streak);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, StreakModel?>> getStreakByHabit(String habitId) async {
    try {
      final streak = await localDataSource.getStreakByHabit(habitId);
      return Right(streak);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StreakModel>>> getActiveStreaks() async {
    try {
      final streaks = await localDataSource.getActiveStreaks();
      return Right(streaks);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StreakModel>>> getStreaksByLength() async {
    try {
      final streaks = await localDataSource.getStreaksByLength();
      return Right(streaks);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createStreak(StreakModel streak) async {
    try {
      await localDataSource.createStreak(streak);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateStreak(StreakModel streak) async {
    try {
      await localDataSource.updateStreak(streak);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteStreak(String id) async {
    try {
      await localDataSource.deleteStreak(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> incrementCurrentStreak(String habitId) async {
    try {
      await localDataSource.incrementCurrentStreak(habitId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resetCurrentStreak(String habitId) async {
    try {
      await localDataSource.resetCurrentStreak(habitId);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> recordCompletedDay(
    String habitId,
    String date,
  ) async {
    try {
      await localDataSource.recordCompletedDay(habitId, date);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> recordFailedDay(
    String habitId,
    String date,
  ) async {
    try {
      await localDataSource.recordFailedDay(habitId, date);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> calculateCurrentStreak(String habitId) async {
    try {
      final streak = await localDataSource.getStreakByHabit(habitId);

      if (streak == null) {
        return const Right(0);
      }
      
      return Right(streak.currentStreak);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportStreak(String id) async {
    try {
      final streak = await localDataSource.getStreakById(id);
      final json = streak.toJson();
      return Right(json);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, StreakModel>> importStreak(
    Map<String, dynamic> json,
  ) async {
    try {
      final streak = StreakModel.fromJson(json);
      await localDataSource.createStreak(streak);
      return Right(streak);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(ValidationFailure('JSON inválido: $e'));
    }
  }
}
