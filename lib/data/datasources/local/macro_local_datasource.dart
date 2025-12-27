import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/macro_model.dart';

abstract class MacroLocalDataSource {
  Future<List<MacroModel>> getAllMacros();

  Future<MacroModel> getMacroById(String id);

  Future<List<MacroModel>> getActiveMacros();

  Future<void> createMacro(MacroModel macro);

  Future<void> updateMacro(MacroModel macro);

  Future<void> deleteMacro(String id);

  Future<void> toggleMacroActive(String id, bool isActive);

  Future<List<MacroModel>> getMacrosByPriority();

  Future<void> clearAllMacros();
}

class MacroLocalDataSourceImpl implements MacroLocalDataSource {
  late Box<MacroModel> _macrosBox;

  Future<void> init() async {
    _macrosBox = await Hive.openBox<MacroModel>(StorageKeys.macrosBox);
  }

  @override
  Future<List<MacroModel>> getAllMacros() async {
    try {
      return _macrosBox.values.toList();
    } catch (e) {
      throw CacheException('Error al obtener todas las macros: $e');
    }
  }

  @override
  Future<MacroModel> getMacroById(String id) async {
    try {
      final macro = _macrosBox.get(id);
      if (macro == null) {
        throw CacheException('Macro no encontrada con ID: $id');
      }
      return macro;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al obtener macro por ID: $e');
    }
  }

  @override
  Future<List<MacroModel>> getActiveMacros() async {
    try {
      return _macrosBox.values.where((macro) => macro.isActive).toList();
    } catch (e) {
      throw CacheException('Error al obtener macros activas: $e');
    }
  }

  @override
  Future<void> createMacro(MacroModel macro) async {
    try {
      await _macrosBox.put(macro.id, macro);
    } catch (e) {
      throw CacheException('Error al crear macro: $e');
    }
  }

  @override
  Future<void> updateMacro(MacroModel macro) async {
    try {
      if (!_macrosBox.containsKey(macro.id)) {
        throw CacheException('Macro no existe, no se puede actualizar');
      }
      await _macrosBox.put(macro.id, macro);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al actualizar macro: $e');
    }
  }

  @override
  Future<void> deleteMacro(String id) async {
    try {
      if (!_macrosBox.containsKey(id)) {
        throw CacheException('Macro no existe, no se puede eliminar');
      }
      await _macrosBox.delete(id);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al eliminar macro: $e');
    }
  }

  @override
  Future<void> toggleMacroActive(String id, bool isActive) async {
    try {
      final macro = await getMacroById(id);
      final updatedMacro = macro.copyWith(isActive: isActive);
      await updateMacro(updatedMacro);
    } catch (e) {
      throw CacheException('Error al cambiar estado de macro: $e');
    }
  }

  @override
  Future<List<MacroModel>> getMacrosByPriority() async {
    try {
      final macros = await getAllMacros();
      macros.sort((a, b) => b.priority.compareTo(a.priority));
      return macros;
    } catch (e) {
      throw CacheException('Error al obtener macros por prioridad: $e');
    }
  }

  @override
  Future<void> clearAllMacros() async {
    try {
      await _macrosBox.clear();
    } catch (e) {
      throw CacheException('Error al limpiar todas las macros: $e');
    }
  }
}
