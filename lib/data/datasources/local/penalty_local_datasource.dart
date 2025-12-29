import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/penalty_model.dart';

abstract class PenaltyLocalDataSource {
  Future<List<PenaltyModel>> getAllPenalties();

  Future<PenaltyModel> getPenaltyById(String id);

  Future<List<PenaltyModel>> getActivePenalties();
  Future<List<PenaltyModel>> getPenaltiesByType(PenaltyType type);
  Future<List<PenaltyModel>> getRevertiblePenalties();
  Future<List<PenaltyModel>> getPenaltiesByIntensity(int minIntensity);

  Future<void> createPenalty(PenaltyModel penalty);
  Future<void> updatePenalty(PenaltyModel penalty);
  Future<void> deletePenalty(String id);
  Future<void> togglePenaltyActive(String id, bool isActive);
  Future<void> clearAllPenalties();
  Future<void> createPenaltyExecution(PenaltyExecutionModel execution);

  Future<List<PenaltyExecutionModel>> getPenaltyExecutions(String penaltyId);
  Future<List<PenaltyExecutionModel>> getExecutionsByHabit(String habitId);
}

class PenaltyLocalDataSourceImpl implements PenaltyLocalDataSource {
  late Box<PenaltyModel> _penaltiesBox;
  late Box<PenaltyExecutionModel> _executionsBox;

  Future<void> init() async {
    _penaltiesBox = await Hive.openBox<PenaltyModel>(StorageKeys.penaltiesBox);
    _executionsBox = await Hive.openBox<PenaltyExecutionModel>(
      StorageKeys.penaltyExecutionsBox,
    );
  }

  @override
  Future<List<PenaltyModel>> getAllPenalties() async {
    try {
      return _penaltiesBox.values.toList();
    } catch (e) {
      throw CacheException('Error al obtener todas las penalizaciones: $e');
    }
  }

  @override
  Future<PenaltyModel> getPenaltyById(String id) async {
    try {
      final penalty = _penaltiesBox.get(id);
      if (penalty == null) {
        throw CacheException('Penalización no encontrada con ID: $id');
      }
      return penalty;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al obtener penalización por ID: $e');
    }
  }

  @override
  Future<List<PenaltyModel>> getActivePenalties() async {
    try {
      return _penaltiesBox.values.where((penalty) => penalty.isActive).toList();
    } catch (e) {
      throw CacheException('Error al obtener penalizaciones activas: $e');
    }
  }

  @override
  Future<List<PenaltyModel>> getPenaltiesByType(PenaltyType type) async {
    try {
      return _penaltiesBox.values
          .where((penalty) => penalty.type == type)
          .toList();
    } catch (e) {
      throw CacheException('Error al obtener penalizaciones por tipo: $e');
    }
  }

  @override
  Future<List<PenaltyModel>> getRevertiblePenalties() async {
    try {
      return _penaltiesBox.values
          .where((penalty) => penalty.isRevertible)
          .toList();
    } catch (e) {
      throw CacheException('Error al obtener penalizaciones revertibles: $e');
    }
  }

  @override
  Future<List<PenaltyModel>> getPenaltiesByIntensity(int minIntensity) async {
    try {
      return _penaltiesBox.values
          .where((penalty) => penalty.intensity >= minIntensity)
          .toList();
    } catch (e) {
      throw CacheException(
        'Error al obtener penalizaciones por intensidad: $e',
      );
    }
  }

  @override
  Future<void> createPenalty(PenaltyModel penalty) async {
    try {
      await _penaltiesBox.put(penalty.id, penalty);
    } catch (e) {
      throw CacheException('Error al crear penalización: $e');
    }
  }

  @override
  Future<void> updatePenalty(PenaltyModel penalty) async {
    try {
      if (!_penaltiesBox.containsKey(penalty.id)) {
        throw CacheException('Penalización no existe, no se puede actualizar');
      }
      await _penaltiesBox.put(penalty.id, penalty);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al actualizar penalización: $e');
    }
  }

  @override
  Future<void> deletePenalty(String id) async {
    try {
      if (!_penaltiesBox.containsKey(id)) {
        throw CacheException('Penalización no existe, no se puede eliminar');
      }
      await _penaltiesBox.delete(id);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al eliminar penalización: $e');
    }
  }

  @override
  Future<void> togglePenaltyActive(String id, bool isActive) async {
    try {
      final penalty = await getPenaltyById(id);
      final updatedPenalty = penalty.copyWith(isActive: isActive);
      await updatePenalty(updatedPenalty);
    } catch (e) {
      throw CacheException('Error al cambiar estado de penalización: $e');
    }
  }

  @override
  Future<void> clearAllPenalties() async {
    try {
      await _penaltiesBox.clear();
    } catch (e) {
      throw CacheException('Error al limpiar todas las penalizaciones: $e');
    }
  }

  @override
  Future<void> createPenaltyExecution(PenaltyExecutionModel execution) async {
    try {
      await _executionsBox.put(execution.id, execution);
    } catch (e) {
      throw CacheException('Error al crear ejecución de penalización: $e');
    }
  }

  @override
  Future<List<PenaltyExecutionModel>> getPenaltyExecutions(
    String penaltyId,
  ) async {
    try {
      final executions = _executionsBox.values
          .where((execution) => execution.penaltyId == penaltyId)
          .toList();
      executions.sort((a, b) => b.executedAt.compareTo(a.executedAt));
      return executions;
    } catch (e) {
      throw CacheException('Error al obtener ejecuciones: $e');
    }
  }

  @override
  Future<List<PenaltyExecutionModel>> getExecutionsByHabit(
    String habitId,
  ) async {
    try {
      final executions = _executionsBox.values
          .where((execution) => execution.habitId == habitId)
          .toList();
      executions.sort((a, b) => b.executedAt.compareTo(a.executedAt));
      return executions;
    } catch (e) {
      throw CacheException('Error al obtener ejecuciones por hábito: $e');
    }
  }
}
