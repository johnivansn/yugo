import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../data/models/macro_model.dart';
import '../../data/models/execution_log_model.dart';

abstract class MacroRepository {
  Future<Either<Failure, List<MacroModel>>> getAllMacros();

  Future<Either<Failure, MacroModel>> getMacroById(String id);

  Future<Either<Failure, List<MacroModel>>> getActiveMacros();

  Future<Either<Failure, void>> createMacro(MacroModel macro);

  Future<Either<Failure, void>> updateMacro(MacroModel macro);

  Future<Either<Failure, void>> deleteMacro(String id);

  Future<Either<Failure, void>> toggleMacroActive(String id, bool isActive);

  Future<Either<Failure, List<MacroModel>>> getMacrosByPriority();

  Future<Either<Failure, ExecutionLogModel>> executeMacro({
    required String macroId,
    required Map<String, dynamic> eventData,
  });

  Future<Either<Failure, List<ExecutionLogModel>>> getMacroExecutionLogs(
    String macroId,
  );

  Future<Either<Failure, Map<String, dynamic>>> exportMacro(String id);

  Future<Either<Failure, MacroModel>> importMacro(Map<String, dynamic> json);
}
