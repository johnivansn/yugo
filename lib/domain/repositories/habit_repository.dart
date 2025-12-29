import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../data/models/habit_model.dart';

abstract class HabitRepository {
  Future<Either<Failure, HabitModel>> getHabitById(String id);

  Future<Either<Failure, List<HabitModel>>> getAllHabits();
  Future<Either<Failure, List<HabitModel>>> getActiveHabits();
  Future<Either<Failure, List<HabitModel>>> getHabitsByPriority();

  Future<Either<Failure, void>> createHabit(HabitModel habit);
  Future<Either<Failure, void>> updateHabit(HabitModel habit);
  Future<Either<Failure, void>> deleteHabit(String id);
  Future<Either<Failure, void>> toggleHabitActive(String id, bool isActive);
  Future<Either<Failure, void>> updateStreak(
    String id,
    int currentStreak,
    int longestStreak,
  );

  Future<Either<Failure, void>> markHabitCompleted(String id);
  Future<Either<Failure, void>> markHabitFailed(String id);

  Future<Either<Failure, Map<String, dynamic>>> exportHabit(String id);
  Future<Either<Failure, HabitModel>> importHabit(Map<String, dynamic> json);
}
