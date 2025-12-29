import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/habit_repository.dart';
import '../datasources/local/habit_local_datasource.dart';
import '../models/habit_model.dart';

/// Implementación del repositorio de Hábitos
class HabitRepositoryImpl implements HabitRepository {
  final HabitLocalDataSource localDataSource;

  HabitRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<HabitModel>>> getAllHabits() async {
    try {
      final habits = await localDataSource.getAllHabits();
      return Right(habits);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, HabitModel>> getHabitById(String id) async {
    try {
      final habit = await localDataSource.getHabitById(id);
      return Right(habit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<HabitModel>>> getActiveHabits() async {
    try {
      final habits = await localDataSource.getActiveHabits();
      return Right(habits);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<HabitModel>>> getHabitsByPriority() async {
    try {
      final habits = await localDataSource.getHabitsByPriority();
      return Right(habits);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createHabit(HabitModel habit) async {
    try {
      await localDataSource.createHabit(habit);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateHabit(HabitModel habit) async {
    try {
      await localDataSource.updateHabit(habit);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteHabit(String id) async {
    try {
      await localDataSource.deleteHabit(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleHabitActive(
    String id,
    bool isActive,
  ) async {
    try {
      await localDataSource.toggleHabitActive(id, isActive);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateStreak(
    String id,
    int currentStreak,
    int longestStreak,
  ) async {
    try {
      await localDataSource.updateStreak(id, currentStreak, longestStreak);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markHabitCompleted(String id) async {
    try {
      await localDataSource.incrementCompletions(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markHabitFailed(String id) async {
    try {
      await localDataSource.incrementFailures(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportHabit(String id) async {
    try {
      final habit = await localDataSource.getHabitById(id);
      final json = habit.toJson();
      return Right(json);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, HabitModel>> importHabit(
    Map<String, dynamic> json,
  ) async {
    try {
      final habit = HabitModel.fromJson(json);
      await localDataSource.createHabit(habit);
      return Right(habit);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(ValidationFailure('JSON inválido: $e'));
    }
  }
}
