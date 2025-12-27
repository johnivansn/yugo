import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/execution_log_model.dart';

abstract class LogLocalDataSource {
  Future<void> createLog(ExecutionLogModel log);

  Future<List<ExecutionLogModel>> getAllLogs();

  Future<List<ExecutionLogModel>> getLogsByEntity(String entityId);

  Future<List<ExecutionLogModel>> getLogsByType(LogType type);

  Future<List<ExecutionLogModel>> getLogsByLevel(LogLevel level);

  Future<List<ExecutionLogModel>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  Future<List<ExecutionLogModel>> getRecentLogs(int count);

  Future<void> clearOldLogs(int daysToKeep);

  Future<void> clearAllLogs();
}

class LogLocalDataSourceImpl implements LogLocalDataSource {
  late Box<ExecutionLogModel> _logsBox;

  Future<void> init() async {
    _logsBox = await Hive.openBox<ExecutionLogModel>(
      StorageKeys.executionLogsBox,
    );
  }

  @override
  Future<void> createLog(ExecutionLogModel log) async {
    try {
      await _logsBox.put(log.id, log);
    } catch (e) {
      throw CacheException('Error al crear log: $e');
    }
  }

  @override
  Future<List<ExecutionLogModel>> getAllLogs() async {
    try {
      final logs = _logsBox.values.toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      throw CacheException('Error al obtener todos los logs: $e');
    }
  }

  @override
  Future<List<ExecutionLogModel>> getLogsByEntity(String entityId) async {
    try {
      final logs = _logsBox.values
          .where((log) => log.entityId == entityId)
          .toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      throw CacheException('Error al obtener logs por entidad: $e');
    }
  }

  @override
  Future<List<ExecutionLogModel>> getLogsByType(LogType type) async {
    try {
      final logs = _logsBox.values.where((log) => log.type == type).toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      throw CacheException('Error al obtener logs por tipo: $e');
    }
  }

  @override
  Future<List<ExecutionLogModel>> getLogsByLevel(LogLevel level) async {
    try {
      final logs = _logsBox.values.where((log) => log.level == level).toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      throw CacheException('Error al obtener logs por nivel: $e');
    }
  }

  @override
  Future<List<ExecutionLogModel>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final logs = _logsBox.values
          .where(
            (log) =>
                log.timestamp.isAfter(startDate) &&
                log.timestamp.isBefore(endDate),
          )
          .toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    } catch (e) {
      throw CacheException('Error al obtener logs por rango de fechas: $e');
    }
  }

  @override
  Future<List<ExecutionLogModel>> getRecentLogs(int count) async {
    try {
      final logs = await getAllLogs();
      return logs.take(count).toList();
    } catch (e) {
      throw CacheException('Error al obtener logs recientes: $e');
    }
  }

  @override
  Future<void> clearOldLogs(int daysToKeep) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final keysToDelete = <String>[];

      for (final entry in _logsBox.toMap().entries) {
        if (entry.value.timestamp.isBefore(cutoffDate)) {
          keysToDelete.add(entry.key);
        }
      }

      await _logsBox.deleteAll(keysToDelete);
    } catch (e) {
      throw CacheException('Error al limpiar logs antiguos: $e');
    }
  }

  @override
  Future<void> clearAllLogs() async {
    try {
      await _logsBox.clear();
    } catch (e) {
      throw CacheException('Error al limpiar todos los logs: $e');
    }
  }
}
