import 'package:dartz/dartz.dart';

import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../domain/repositories/macro_repository.dart';
import '../../services/macro_execution_service.dart';
import '../datasources/local/log_local_datasource.dart';
import '../datasources/local/macro_local_datasource.dart';
import '../models/execution_log_model.dart';
import '../models/macro_model.dart';

class MacroRepositoryImpl implements MacroRepository {
  final MacroLocalDataSource localDataSource;
  final LogLocalDataSource logDataSource;
  final MacroExecutionService executionService;

  MacroRepositoryImpl({
    required this.localDataSource,
    required this.logDataSource,
    required this.executionService,
  });

  @override
  Future<Either<Failure, List<MacroModel>>> getAllMacros() async {
    try {
      final macros = await localDataSource.getAllMacros();
      return Right(macros);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MacroModel>> getMacroById(String id) async {
    try {
      final macro = await localDataSource.getMacroById(id);
      return Right(macro);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MacroModel>>> getActiveMacros() async {
    try {
      final macros = await localDataSource.getActiveMacros();
      return Right(macros);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> createMacro(MacroModel macro) async {
    try {
      await localDataSource.createMacro(macro);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateMacro(MacroModel macro) async {
    try {
      await localDataSource.updateMacro(macro);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteMacro(String id) async {
    try {
      await localDataSource.deleteMacro(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleMacroActive(
    String id,
    bool isActive,
  ) async {
    try {
      await localDataSource.toggleMacroActive(id, isActive);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MacroModel>>> getMacrosByPriority() async {
    try {
      final macros = await localDataSource.getMacrosByPriority();
      return Right(macros);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExecutionLogModel>> executeMacro({
    required String macroId,
    required Map<String, dynamic> eventData,
  }) async {
    try {
      final macro = await localDataSource.getMacroById(macroId);

      final log = await executionService.executeMacro(
        macro: macro,
        eventData: eventData,
      );

      await logDataSource.createLog(log);

      return Right(log);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } on MacroExecutionException catch (e) {
      return Left(MacroExecutionFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExecutionLogModel>>> getMacroExecutionLogs(
    String macroId,
  ) async {
    try {
      final logs = await logDataSource.getLogsByEntity(macroId);
      return Right(logs);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> exportMacro(String id) async {
    try {
      final macro = await localDataSource.getMacroById(id);
      final json = macro.toJson();
      return Right(json);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, MacroModel>> importMacro(
    Map<String, dynamic> json,
  ) async {
    try {
      final macro = MacroModel.fromJson(json);
      await localDataSource.createMacro(macro);
      return Right(macro);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message, e.code));
    } catch (e) {
      return Left(ValidationFailure('JSON inválido: $e'));
    }
  }
}
