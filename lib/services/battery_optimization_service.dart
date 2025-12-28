import '../core/platform/macro_platform_channel.dart';

class BatteryOptimizationService {
  final MacroServicePlatformChannel _platformChannel;

  BatteryOptimizationService({MacroServicePlatformChannel? platformChannel})
    : _platformChannel = platformChannel ?? MacroServicePlatformChannel();

  Future<bool> isOptimizationDisabled() async {
    try {
      return await _platformChannel.isBatteryOptimizationDisabled();
    } catch (e) {
      print('Error al verificar optimización de batería: $e');
      return false;
    }
  }

  Future<bool> requestDisableOptimization() async {
    try {
      print('Solicitando deshabilitar optimización de batería...');
      return await _platformChannel.requestDisableBatteryOptimization();
    } catch (e) {
      print('Error al solicitar deshabilitación: $e');
      return false;
    }
  }

  Future<bool> openSettings() async {
    try {
      print('Abriendo configuración de batería...');
      return await _platformChannel.openBatteryOptimizationSettings();
    } catch (e) {
      print('Error al abrir configuración: $e');
      return false;
    }
  }

  Future<BatteryOptimizationStatus> checkAndRequest() async {
    try {
      final isDisabled = await isOptimizationDisabled();

      if (isDisabled) {
        print('Optimización de batería ya está deshabilitada');
        return BatteryOptimizationStatus.disabled;
      }

      print('Optimización de batería está activa');
      return BatteryOptimizationStatus.enabled;
    } catch (e) {
      print('Error al verificar optimización: $e');
      return BatteryOptimizationStatus.unknown;
    }
  }
}

enum BatteryOptimizationStatus {
  disabled,
  enabled,
  unknown,
}
