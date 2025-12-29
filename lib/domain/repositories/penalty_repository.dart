import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../data/models/penalty_model.dart';

abstract class PenaltyRepository {
  Future<Either<Failure, List<PenaltyModel>>> getAllPenalties();

  Future<Either<Failure, PenaltyModel>> getPenaltyById(String id);

  Future<Either<Failure, List<PenaltyModel>>> getActivePenalties();
  Future<Either<Failure, List<PenaltyModel>>> getPenaltiesByType(
    PenaltyType type,
  );
  Future<Either<Failure, List<PenaltyModel>>> getRevertiblePenalties();
  Future<Either<Failure, List<PenaltyModel>>> getPenaltiesByIntensity(
    int minIntensity,
  );

  Future<Either<Failure, void>> createPenalty(PenaltyModel penalty);
  Future<Either<Failure, void>> updatePenalty(PenaltyModel penalty);
  Future<Either<Failure, void>> deletePenalty(String id);
  Future<Either<Failure, void>> togglePenaltyActive(String id, bool isActive);

  Future<Either<Failure, PenaltyExecutionModel>> executePenalty({
    required String penaltyId,
    required String habitId,
    Map<String, dynamic>? context,
  });

  Future<Either<Failure, void>> revertPenalty(String executionId);

  Future<Either<Failure, List<PenaltyExecutionModel>>> getPenaltyExecutions(
    String penaltyId,
  );
  Future<Either<Failure, List<PenaltyExecutionModel>>> getExecutionsByHabit(
    String habitId,
  );

  Future<Either<Failure, Map<String, dynamic>>> exportPenalty(String id);

  Future<Either<Failure, PenaltyModel>> importPenalty(
    Map<String, dynamic> json,
  );
}
