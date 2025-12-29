import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../data/models/streak_model.dart';

abstract class StreakRepository {
  Future<Either<Failure, List<StreakModel>>> getAllStreaks();

  Future<Either<Failure, StreakModel>> getStreakById(String id);

  Future<Either<Failure, StreakModel?>> getStreakByHabit(String habitId);

  Future<Either<Failure, List<StreakModel>>> getActiveStreaks();

  Future<Either<Failure, List<StreakModel>>> getStreaksByLength();
  Future<Either<Failure, void>> createStreak(StreakModel streak);
  Future<Either<Failure, void>> updateStreak(StreakModel streak);
  Future<Either<Failure, void>> deleteStreak(String id);
  Future<Either<Failure, void>> incrementCurrentStreak(String habitId);
  Future<Either<Failure, void>> resetCurrentStreak(String habitId);
  Future<Either<Failure, void>> recordCompletedDay(String habitId, String date);
  Future<Either<Failure, void>> recordFailedDay(String habitId, String date);

  Future<Either<Failure, int>> calculateCurrentStreak(String habitId);

  Future<Either<Failure, Map<String, dynamic>>> exportStreak(String id);

  Future<Either<Failure, StreakModel>> importStreak(Map<String, dynamic> json);
}
