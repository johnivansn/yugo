import '../core/errors/exceptions.dart';
import '../core/platform/macro_platform_channel.dart';

/// Gestor del servicio de foreground
///
/// Responsable de:
/// - Iniciar/detener el servicio nativo
/// - Verificar estado del servicio
/// - Manejar errores de plataforma
class ForegroundServiceManager {
  final MacroServicePlatformChannel _platformChannel;

  ForegroundServiceManager({MacroServicePlatformChannel? platformChannel})
    : _platformChannel = platformChannel ?? MacroServicePlatformChannel();

  Future<bool> startService() async {
    try {
      print('Iniciando servicio de foreground...');

      final result = await _platformChannel.startService();

      if (result) {
        print('Servicio de foreground iniciado');
      } else {
        print('Servicio no pudo iniciarse');
      }

      return result;
    } on PlatformChannelException catch (e) {
      print('Error al iniciar servicio: ${e.message}');
      rethrow;
    } catch (e) {
      print('Error inesperado: $e');
      throw PlatformChannelException(
        'Error inesperado al iniciar servicio: $e',
      );
    }
  }

  Future<bool> stopService() async {
    try {
      print('Deteniendo servicio de foreground...');

      final result = await _platformChannel.stopService();

      if (result) {
        print('Servicio de foreground detenido');
      } else {
        print('Servicio no pudo detenerse');
      }

      return result;
    } on PlatformChannelException catch (e) {
      print('Error al detener servicio: ${e.message}');
      rethrow;
    } catch (e) {
      print('Error inesperado: $e');
      throw PlatformChannelException(
        'Error inesperado al detener servicio: $e',
      );
    }
  }

  Future<bool> isServiceRunning() async {
    try {
      return await _platformChannel.isServiceRunning();
    } on PlatformChannelException catch (e) {
      print('Error al verificar servicio: ${e.message}');
      return false;
    } catch (e) {
      print('Error inesperado: $e');
      return false;
    }
  }

  Future<bool> restartService() async {
    try {
      print('🔄 Reiniciando servicio...');

      await stopService();
      await Future.delayed(const Duration(milliseconds: 500));
      return await startService();
    } catch (e) {
      print('❌ Error al reiniciar servicio: $e');
      return false;
    }
  }

  Future<void> ensureServiceRunning() async {
    try {
      final isRunning = await isServiceRunning();

      if (!isRunning) {
        print('Servicio no está ejecutándose, iniciando...');
        await startService();
      } else {
        print('Servicio ya está ejecutándose');
      }
    } catch (e) {
      print('Error al asegurar servicio: $e');
    }
  }
}
