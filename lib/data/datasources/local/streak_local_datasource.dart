import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/streak_model.dart';

abstract class StreakLocalDataSource {
  Future<List<StreakModel>> getAllStreaks();

  Future<StreakModel> getStreakById(String id);
  Future<StreakModel?> getStreakByHabit(String habitId);

  Future<List<StreakModel>> getActiveStreaks();

  Future<void> createStreak(StreakModel streak);
  Future<void> updateStreak(StreakModel streak);
  Future<void> deleteStreak(String id);
  Future<void> incrementCurrentStreak(String habitId);
  Future<void> resetCurrentStreak(String habitId);
  Future<void> recordCompletedDay(String habitId, String date);
  Future<void> recordFailedDay(String habitId, String date);

  Future<List<StreakModel>> getStreaksByLength();

  Future<void> clearAllStreaks();
}

class StreakLocalDataSourceImpl implements StreakLocalDataSource {
  late Box<StreakModel> _streaksBox;

  Future<void> init() async {
    _streaksBox = await Hive.openBox<StreakModel>(StorageKeys.streaksBox);
  }

  @override
  Future<List<StreakModel>> getAllStreaks() async {
    try {
      return _streaksBox.values.toList();
    } catch (e) {
      throw CacheException('Error al obtener todas las rachas: $e');
    }
  }

  @override
  Future<StreakModel> getStreakById(String id) async {
    try {
      final streak = _streaksBox.get(id);
      if (streak == null) {
        throw CacheException('Racha no encontrada con ID: $id');
      }
      return streak;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al obtener racha por ID: $e');
    }
  }

  @override
  Future<StreakModel?> getStreakByHabit(String habitId) async {
    try {
      final streaks = _streaksBox.values
          .where((streak) => streak.habitId == habitId && streak.isActive)
          .toList();

      return streaks.isNotEmpty ? streaks.first : null;
    } catch (e) {
      throw CacheException('Error al obtener racha por hábito: $e');
    }
  }

  @override
  Future<List<StreakModel>> getActiveStreaks() async {
    try {
      return _streaksBox.values.where((streak) => streak.isActive).toList();
    } catch (e) {
      throw CacheException('Error al obtener rachas activas: $e');
    }
  }

  @override
  Future<void> createStreak(StreakModel streak) async {
    try {
      await _streaksBox.put(streak.id, streak);
    } catch (e) {
      throw CacheException('Error al crear racha: $e');
    }
  }

  @override
  Future<void> updateStreak(StreakModel streak) async {
    try {
      if (!_streaksBox.containsKey(streak.id)) {
        throw CacheException('Racha no existe, no se puede actualizar');
      }
      await _streaksBox.put(streak.id, streak);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al actualizar racha: $e');
    }
  }

  @override
  Future<void> deleteStreak(String id) async {
    try {
      if (!_streaksBox.containsKey(id)) {
        throw CacheException('Racha no existe, no se puede eliminar');
      }
      await _streaksBox.delete(id);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al eliminar racha: $e');
    }
  }

  @override
  Future<void> incrementCurrentStreak(String habitId) async {
    try {
      final streak = await getStreakByHabit(habitId);
      if (streak == null) {
        throw CacheException('No hay racha activa para el hábito: $habitId');
      }

      final newCurrentStreak = streak.currentStreak + 1;
      final newLongestStreak = newCurrentStreak > streak.longestStreak
          ? newCurrentStreak
          : streak.longestStreak;

      final updatedStreak = streak.copyWith(
        currentStreak: newCurrentStreak,
        longestStreak: newLongestStreak,
        totalCompletions: streak.totalCompletions + 1,
      );

      await updateStreak(updatedStreak);
    } catch (e) {
      throw CacheException('Error al incrementar racha: $e');
    }
  }

  @override
  Future<void> resetCurrentStreak(String habitId) async {
    try {
      final streak = await getStreakByHabit(habitId);
      if (streak == null) {
        throw CacheException('No hay racha activa para el hábito: $habitId');
      }

      final updatedStreak = streak.copyWith(
        currentStreak: 0,
        totalFailures: streak.totalFailures + 1,
      );

      await updateStreak(updatedStreak);
    } catch (e) {
      throw CacheException('Error al reiniciar racha: $e');
    }
  }

  @override
  Future<void> recordCompletedDay(String habitId, String date) async {
    try {
      final streak = await getStreakByHabit(habitId);
      if (streak == null) {
        throw CacheException('No hay racha activa para el hábito: $habitId');
      }

      final completedDates = List<String>.from(streak.completedDates);
      if (!completedDates.contains(date)) {
        completedDates.add(date);
      }

      final updatedStreak = streak.copyWith(completedDates: completedDates);

      await updateStreak(updatedStreak);
    } catch (e) {
      throw CacheException('Error al registrar día completado: $e');
    }
  }

  @override
  Future<void> recordFailedDay(String habitId, String date) async {
    try {
      final streak = await getStreakByHabit(habitId);
      if (streak == null) {
        throw CacheException('No hay racha activa para el hábito: $habitId');
      }

      final failedDates = List<String>.from(streak.failedDates);
      if (!failedDates.contains(date)) {
        failedDates.add(date);
      }

      final updatedStreak = streak.copyWith(failedDates: failedDates);

      await updateStreak(updatedStreak);
    } catch (e) {
      throw CacheException('Error al registrar día fallido: $e');
    }
  }

  @override
  Future<List<StreakModel>> getStreaksByLength() async {
    try {
      final streaks = await getAllStreaks();
      streaks.sort((a, b) => b.longestStreak.compareTo(a.longestStreak));
      return streaks;
    } catch (e) {
      throw CacheException('Error al obtener rachas ordenadas: $e');
    }
  }

  @override
  Future<void> clearAllStreaks() async {
    try {
      await _streaksBox.clear();
    } catch (e) {
      throw CacheException('Error al limpiar todas las rachas: $e');
    }
  }
}
