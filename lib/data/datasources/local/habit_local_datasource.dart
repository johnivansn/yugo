import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/habit_model.dart';

abstract class HabitLocalDataSource {
  Future<List<HabitModel>> getAllHabits();
  Future<HabitModel> getHabitById(String id);
  Future<List<HabitModel>> getActiveHabits();
  Future<List<HabitModel>> getHabitsByPriority();
  Future<void> createHabit(HabitModel habit);
  Future<void> updateHabit(HabitModel habit);
  Future<void> deleteHabit(String id);
  Future<void> toggleHabitActive(String id, bool isActive);
  Future<void> updateStreak(String id, int currentStreak, int longestStreak);
  Future<void> incrementCompletions(String id);
  Future<void> incrementFailures(String id);
  Future<void> clearAllHabits();
}

class HabitLocalDataSourceImpl implements HabitLocalDataSource {
  late Box<HabitModel> _habitsBox;

  Future<void> init() async {
    _habitsBox = await Hive.openBox<HabitModel>(StorageKeys.habitsBox);
  }

  @override
  Future<List<HabitModel>> getAllHabits() async {
    try {
      return _habitsBox.values.toList();
    } catch (e) {
      throw CacheException('Error al obtener todos los hábitos: $e');
    }
  }

  @override
  Future<HabitModel> getHabitById(String id) async {
    try {
      final habit = _habitsBox.get(id);
      if (habit == null) {
        throw CacheException('Hábito no encontrado con ID: $id');
      }
      return habit;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al obtener hábito por ID: $e');
    }
  }

  @override
  Future<List<HabitModel>> getActiveHabits() async {
    try {
      return _habitsBox.values.where((habit) => habit.isActive).toList();
    } catch (e) {
      throw CacheException('Error al obtener hábitos activos: $e');
    }
  }

  @override
  Future<List<HabitModel>> getHabitsByPriority() async {
    try {
      final habits = await getAllHabits();
      habits.sort((a, b) => b.priority.compareTo(a.priority));
      return habits;
    } catch (e) {
      throw CacheException('Error al obtener hábitos por prioridad: $e');
    }
  }

  @override
  Future<void> createHabit(HabitModel habit) async {
    try {
      await _habitsBox.put(habit.id, habit);
    } catch (e) {
      throw CacheException('Error al crear hábito: $e');
    }
  }

  @override
  Future<void> updateHabit(HabitModel habit) async {
    try {
      if (!_habitsBox.containsKey(habit.id)) {
        throw CacheException('Hábito no existe, no se puede actualizar');
      }
      await _habitsBox.put(habit.id, habit);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al actualizar hábito: $e');
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    try {
      if (!_habitsBox.containsKey(id)) {
        throw CacheException('Hábito no existe, no se puede eliminar');
      }
      await _habitsBox.delete(id);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al eliminar hábito: $e');
    }
  }

  @override
  Future<void> toggleHabitActive(String id, bool isActive) async {
    try {
      final habit = await getHabitById(id);
      final updatedHabit = habit.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      );
      await updateHabit(updatedHabit);
    } catch (e) {
      throw CacheException('Error al cambiar estado de hábito: $e');
    }
  }

  @override
  Future<void> updateStreak(
    String id,
    int currentStreak,
    int longestStreak,
  ) async {
    try {
      final habit = await getHabitById(id);
      final updatedHabit = habit.copyWith(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        updatedAt: DateTime.now(),
      );
      await updateHabit(updatedHabit);
    } catch (e) {
      throw CacheException('Error al actualizar racha: $e');
    }
  }

  @override
  Future<void> incrementCompletions(String id) async {
    try {
      final habit = await getHabitById(id);
      final updatedHabit = habit.copyWith(
        totalCompletions: habit.totalCompletions + 1,
        updatedAt: DateTime.now(),
      );
      await updateHabit(updatedHabit);
    } catch (e) {
      throw CacheException('Error al incrementar completados: $e');
    }
  }

  @override
  Future<void> incrementFailures(String id) async {
    try {
      final habit = await getHabitById(id);
      final updatedHabit = habit.copyWith(
        totalFailures: habit.totalFailures + 1,
        updatedAt: DateTime.now(),
      );
      await updateHabit(updatedHabit);
    } catch (e) {
      throw CacheException('Error al incrementar fallos: $e');
    }
  }

  @override
  Future<void> clearAllHabits() async {
    try {
      await _habitsBox.clear();
    } catch (e) {
      throw CacheException('Error al limpiar todos los hábitos: $e');
    }
  }
}
