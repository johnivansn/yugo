import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/validator_model.dart';

abstract class ValidatorLocalDataSource {
  Future<List<ValidatorModel>> getAllValidators();
  Future<ValidatorModel> getValidatorById(String id);
  Future<List<ValidatorModel>> getActiveValidators();
  Future<List<ValidatorModel>> getValidatorsByType(ValidatorType type);
  Future<List<ValidatorModel>> getPredefinedValidators();
  Future<List<ValidatorModel>> getCustomValidators();
  Future<void> createValidator(ValidatorModel validator);
  Future<void> updateValidator(ValidatorModel validator);
  Future<void> deleteValidator(String id);
  Future<void> toggleValidatorActive(String id, bool isActive);
  Future<void> clearAllValidators();
}

class ValidatorLocalDataSourceImpl implements ValidatorLocalDataSource {
  late Box<ValidatorModel> _validatorsBox;

  Future<void> init() async {
    _validatorsBox = await Hive.openBox<ValidatorModel>(
      StorageKeys.validatorsBox,
    );
  }

  @override
  Future<List<ValidatorModel>> getAllValidators() async {
    try {
      return _validatorsBox.values.toList();
    } catch (e) {
      throw CacheException('Error al obtener todos los validadores: $e');
    }
  }

  @override
  Future<ValidatorModel> getValidatorById(String id) async {
    try {
      final validator = _validatorsBox.get(id);
      if (validator == null) {
        throw CacheException('Validador no encontrado con ID: $id');
      }
      return validator;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al obtener validador por ID: $e');
    }
  }

  @override
  Future<List<ValidatorModel>> getActiveValidators() async {
    try {
      return _validatorsBox.values
          .where((validator) => validator.isActive)
          .toList();
    } catch (e) {
      throw CacheException('Error al obtener validadores activos: $e');
    }
  }

  @override
  Future<List<ValidatorModel>> getValidatorsByType(ValidatorType type) async {
    try {
      return _validatorsBox.values
          .where((validator) => validator.type == type)
          .toList();
    } catch (e) {
      throw CacheException('Error al obtener validadores por tipo: $e');
    }
  }

  @override
  Future<List<ValidatorModel>> getPredefinedValidators() async {
    try {
      return _validatorsBox.values
          .where((validator) => !validator.isCustom)
          .toList();
    } catch (e) {
      throw CacheException('Error al obtener validadores predefinidos: $e');
    }
  }

  @override
  Future<List<ValidatorModel>> getCustomValidators() async {
    try {
      return _validatorsBox.values
          .where((validator) => validator.isCustom)
          .toList();
    } catch (e) {
      throw CacheException('Error al obtener validadores personalizados: $e');
    }
  }

  @override
  Future<void> createValidator(ValidatorModel validator) async {
    try {
      await _validatorsBox.put(validator.id, validator);
    } catch (e) {
      throw CacheException('Error al crear validador: $e');
    }
  }

  @override
  Future<void> updateValidator(ValidatorModel validator) async {
    try {
      if (!_validatorsBox.containsKey(validator.id)) {
        throw CacheException('Validador no existe, no se puede actualizar');
      }
      await _validatorsBox.put(validator.id, validator);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al actualizar validador: $e');
    }
  }

  @override
  Future<void> deleteValidator(String id) async {
    try {
      if (!_validatorsBox.containsKey(id)) {
        throw CacheException('Validador no existe, no se puede eliminar');
      }
      await _validatorsBox.delete(id);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Error al eliminar validador: $e');
    }
  }

  @override
  Future<void> toggleValidatorActive(String id, bool isActive) async {
    try {
      final validator = await getValidatorById(id);
      final updatedValidator = validator.copyWith(isActive: isActive);
      await updateValidator(updatedValidator);
    } catch (e) {
      throw CacheException('Error al cambiar estado de validador: $e');
    }
  }

  @override
  Future<void> clearAllValidators() async {
    try {
      await _validatorsBox.clear();
    } catch (e) {
      throw CacheException('Error al limpiar todos los validadores: $e');
    }
  }
}
