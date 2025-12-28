import 'package:flutter/services.dart';

import '../errors/exceptions.dart';

class MacroServicePlatformChannel {
  static const MethodChannel _channel = MethodChannel(
    'com.example.yugo/macro_service',
  );

  Future<bool> startService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startService');
      return result ?? false;
    } on PlatformException catch (e) {
      throw PlatformChannelException(
        'Error al iniciar servicio: ${e.message}',
        e.code,
      );
    } catch (e) {
      throw PlatformChannelException(
        'Error inesperado al iniciar servicio: $e',
      );
    }
  }

  Future<bool> stopService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopService');
      return result ?? false;
    } on PlatformException catch (e) {
      throw PlatformChannelException(
        'Error al detener servicio: ${e.message}',
        e.code,
      );
    } catch (e) {
      throw PlatformChannelException(
        'Error inesperado al detener servicio: $e',
      );
    }
  }

  Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      throw PlatformChannelException(
        'Error al verificar estado del servicio: ${e.message}',
        e.code,
      );
    } catch (e) {
      throw PlatformChannelException(
        'Error inesperado al verificar servicio: $e',
      );
    }
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isBatteryOptimizationDisabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw PlatformChannelException(
        'Error al verificar optimización de batería: ${e.message}',
        e.code,
      );
    } catch (e) {
      throw PlatformChannelException('Error inesperado: $e');
    }
  }

  Future<bool> requestDisableBatteryOptimization() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestDisableBatteryOptimization',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw PlatformChannelException(
        'Error al solicitar deshabilitación: ${e.message}',
        e.code,
      );
    } catch (e) {
      throw PlatformChannelException('Error inesperado: $e');
    }
  }

  Future<bool> openBatteryOptimizationSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openBatteryOptimizationSettings',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw PlatformChannelException(
        'Error al abrir configuración: ${e.message}',
        e.code,
      );
    } catch (e) {
      throw PlatformChannelException('Error inesperado: $e');
    }
  }
}
