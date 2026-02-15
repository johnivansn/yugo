import 'package:flutter/services.dart';

class NativeService {
  static const _appInfoChannel =
      MethodChannel('io.github.johnivansn.yugo/app_info');
  static const _macroEngineChannel =
      MethodChannel('io.github.johnivansn.yugo/macro_engine');
  static const _macroServiceChannel =
      MethodChannel('io.github.johnivansn.yugo/macro_service');
  static const _accessibilityChannel =
      MethodChannel('io.github.johnivansn.yugo/accessibility');
  static const _usageStatsChannel =
      MethodChannel('io.github.johnivansn.yugo/usage_stats');
  static const _macroEventsChannel =
      EventChannel('io.github.johnivansn.yugo/macro_events');

  static Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      return await _channel.invokeMethod<Uint8List>('getAppIcon', packageName);
    } catch (_) {
      return null;
    }
  }

  static const _channel = MethodChannel('app.block/config');

  static Future<String?> getRuntimePackageName() async {
    return await _channel.invokeMethod<String>('getRuntimePackageName');
  }

  static Future<Uint8List?> getSelfAppIcon() async {
    try {
      return await _channel.invokeMethod<Uint8List>('getSelfAppIcon');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> checkUsagePermission() async {
    return await _channel.invokeMethod<bool>('checkUsagePermission') ?? false;
  }

  static Future<void> requestUsagePermission() async {
    await _channel.invokeMethod('requestUsagePermission');
  }

  static Future<bool> checkAccessibilityPermission() async {
    return await _channel.invokeMethod<bool>('checkAccessibilityPermission') ??
        false;
  }

  static Future<void> requestAccessibilityPermission() async {
    await _channel.invokeMethod('requestAccessibilityPermission');
  }

  static Future<bool> checkOverlayPermission() async {
    return await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
  }

  static Future<int> getMemoryClass() async {
    return await _channel.invokeMethod<int>('getMemoryClass') ?? 0;
  }

  static Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<String?> getAppName(String packageName) async {
    return await _channel.invokeMethod<String>('getAppName', packageName);
  }

  static Future<List<Map<String, dynamic>>> getBlocks() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getBlocks') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addBlock(Map<String, dynamic> data) async {
    await _channel.invokeMethod('addBlock', data);
  }

  static Future<void> updateBlock(Map<String, dynamic> data) async {
    await _channel.invokeMethod('updateBlock', data);
  }

  static Future<void> deleteBlock(String packageName) async {
    await _channel.invokeMethod('deleteBlock', packageName);
  }

  static Future<Map<String, dynamic>> getUsageToday(String packageName) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getUsageToday', packageName);
    return result?.map((k, v) => MapEntry(k.toString(), v)) ??
        {
          'usedMinutes': 0,
          'isBlocked': false,
          'usedMillis': 0,
          'usedMinutesWeek': 0
        };
  }

  static Future<List<Map<String, dynamic>>> getSchedules(
      String packageName) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
            'getSchedules', packageName) ??
        [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addSchedule(Map<String, dynamic> data) async {
    await _channel.invokeMethod('addSchedule', data);
  }

  static Future<void> updateSchedule(Map<String, dynamic> data) async {
    await _channel.invokeMethod('updateSchedule', data);
  }

  static Future<void> deleteSchedule(String scheduleId) async {
    await _channel.invokeMethod('deleteSchedule', scheduleId);
  }

  static Future<List<Map<String, dynamic>>> getDateBlocks(
      String packageName) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
            'getDateBlocks', packageName) ??
        [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addDateBlock(Map<String, dynamic> data) async {
    await _channel.invokeMethod('addDateBlock', data);
  }

  static Future<void> updateDateBlock(Map<String, dynamic> data) async {
    await _channel.invokeMethod('updateDateBlock', data);
  }

  static Future<void> deleteDateBlock(String blockId) async {
    await _channel.invokeMethod('deleteDateBlock', blockId);
  }

  static Future<List<String>> getDirectBlockPackages() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getDirectBlockPackages') ??
            [];
    return raw.map((e) => e.toString()).toList();
  }

  static Future<void> deleteDirectBlocks(String packageName) async {
    await _channel.invokeMethod('deleteDirectBlocks', packageName);
  }

  static Future<List<Map<String, dynamic>>> getBlockTemplates() async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getBlockTemplates') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> saveBlockTemplate(Map<String, dynamic> data) async {
    await _channel.invokeMethod('saveBlockTemplate', data);
  }

  static Future<void> deleteBlockTemplate(String templateId) async {
    await _channel.invokeMethod('deleteBlockTemplate', templateId);
  }

  static Future<int?> getBatteryLevel() async {
    return await _channel.invokeMethod<int>('getBatteryLevel');
  }

  static Future<Map<String, dynamic>> getAppVersion() async {
    final res =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getReleases() async {
    final res = await _channel.invokeMethod<List<dynamic>>('getReleases') ?? [];
    return res
        .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getMacroExecutionLogs({
    required String macroId,
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _macroEngineChannel.invokeMethod<List<dynamic>>(
          'getMacroExecutionLogs',
          {
            'macroId': macroId,
            'limit': limit,
            'offset': offset,
          },
        ) ??
        [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> getAppInfo() async {
    final res = await _appInfoChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getAppInfo');
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getAllMacros() async {
    final res =
        await _macroEngineChannel.invokeMethod<List<dynamic>>('getAllMacros') ??
            [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createMacro(
      Map<String, dynamic> macro) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'createMacro', macro);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> updateMacro(
      Map<String, dynamic> macro) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'updateMacro', macro);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> deleteMacro(String macroId) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'deleteMacro', {'macroId': macroId});
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> toggleMacroActive(
      String macroId, bool isActive) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'toggleMacroActive', {'macroId': macroId, 'isActive': isActive});
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> emitEvent(
      Map<String, dynamic> payload) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'emitEvent', payload);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> emitSystemEvent(
      Map<String, dynamic> payload) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'emitSystemEvent', payload);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getAllHabitMacros() async {
    final res = await _macroEngineChannel.invokeMethod<List<dynamic>>(
            'getAllHabitMacros') ??
        [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createHabitMacro(
      Map<String, dynamic> macro) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'createHabitMacro', macro);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> updateHabitMacro(
      Map<String, dynamic> macro) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'updateHabitMacro', macro);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> deleteHabitMacro(String id) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'deleteHabitMacro', {'id': id});
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getAllDisciplineMacros() async {
    final res = await _macroEngineChannel.invokeMethod<List<dynamic>>(
            'getAllDisciplineMacros') ??
        [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> createDisciplineMacro(
      Map<String, dynamic> macro) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'createDisciplineMacro', macro);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> updateDisciplineMacro(
      Map<String, dynamic> macro) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'updateDisciplineMacro', macro);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> deleteDisciplineMacro(String id) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'deleteDisciplineMacro', {'id': id});
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> exportHabitMacros() async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'exportHabitMacros');
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> importHabitMacros(
      Map<String, dynamic> payload) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'importHabitMacros', payload);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> exportDisciplineMacros() async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'exportDisciplineMacros');
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> importDisciplineMacros(
      Map<String, dynamic> payload) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'importDisciplineMacros', payload);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<List<Map<String, dynamic>>> getMacroLibrary() async {
    final res =
        await _macroEngineChannel.invokeMethod<List<dynamic>>('getMacroLibrary') ??
            [];
    return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> addMacroLibraryEntry(
      Map<String, dynamic> entry) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'addMacroLibraryEntry', entry);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> updateMacroLibraryEntry(
      Map<String, dynamic> entry) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'updateMacroLibraryEntry', entry);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> deleteMacroLibraryEntry(String id) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'deleteMacroLibraryEntry', {'id': id});
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> createMacroFromLibraryPayload(
      Map<String, dynamic> payload) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'createMacroFromLibraryPayload', payload);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> exportLibrary() async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'exportLibrary');
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> importLibrary(
      Map<String, dynamic> payload) async {
    final res = await _macroEngineChannel.invokeMethod<Map<dynamic, dynamic>>(
        'importLibrary', payload);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<void> startMacroService() async {
    await _macroServiceChannel.invokeMethod('startService');
  }

  static Future<bool> isMacroServiceRunning() async {
    return await _macroServiceChannel.invokeMethod<bool>('isServiceRunning') ??
        false;
  }

  static Future<bool> isBatteryOptimizationDisabled() async {
    return await _macroServiceChannel
            .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
        false;
  }

  static Future<void> requestDisableBatteryOptimization() async {
    await _macroServiceChannel
        .invokeMethod('requestDisableBatteryOptimization');
  }

  static Future<bool> isAccessibilityEnabled() async {
    return await _accessibilityChannel.invokeMethod<bool>(
            'isAccessibilityEnabled') ??
        false;
  }

  static Future<void> openAccessibilitySettings() async {
    await _accessibilityChannel.invokeMethod('openAccessibilitySettings');
  }

  static Future<Map<String, dynamic>> blockApp(String packageName) async {
    final res = await _accessibilityChannel
        .invokeMethod<Map<dynamic, dynamic>>('blockApp', packageName);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<Map<String, dynamic>> unblockApp(String packageName) async {
    final res = await _accessibilityChannel
        .invokeMethod<Map<dynamic, dynamic>>('unblockApp', packageName);
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<bool> hasUsageStatsPermission() async {
    return await _usageStatsChannel.invokeMethod<bool>('hasPermission') ??
        false;
  }

  static Future<void> openUsageStatsSettings() async {
    await _usageStatsChannel.invokeMethod('openPermissionSettings');
  }

  static Future<int> getAppUsageTime(
    String packageName,
    int startTime,
    int endTime,
  ) async {
    return await _usageStatsChannel.invokeMethod<int>('getAppUsageTime', {
          'package_name': packageName,
          'start_time': startTime,
          'end_time': endTime,
        }) ??
        0;
  }

  static Future<Map<String, dynamic>> getAppUsageStats(
    String packageName,
    int startTime,
    int endTime,
  ) async {
    final res = await _usageStatsChannel
        .invokeMethod<Map<dynamic, dynamic>>('getAppUsageStats', {
      'package_name': packageName,
      'start_time': startTime,
      'end_time': endTime,
    });
    return res?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Stream<dynamic> macroEventsStream() {
    return _macroEventsChannel.receiveBroadcastStream();
  }

  static Future<bool> canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
  }

  static Future<void> requestInstallPermission() async {
    await _channel.invokeMethod('requestInstallPermission');
  }

  static Future<bool> downloadAndInstallApk({
    required String url,
    String? shaUrl,
  }) async {
    return await _channel.invokeMethod<bool>('downloadAndInstallApk', {
          'url': url,
          'shaUrl': shaUrl,
        }) ??
        false;
  }

  static Future<bool> downloadApkOnly({
    required String url,
    String? fileName,
  }) async {
    return await _channel.invokeMethod<bool>('downloadApkOnly', {
          'url': url,
          'fileName': fileName,
        }) ??
        false;
  }

  static Future<bool> isAdminEnabled() async {
    return await _channel.invokeMethod<bool>('isAdminEnabled') ?? false;
  }

  static Future<bool> setupAdminPin(String pin) async {
    return await _channel.invokeMethod<bool>('setupAdminPin', pin) ?? false;
  }

  static Future<Map<String, dynamic>> verifyAdminPin(String pin) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'verifyAdminPin', pin);
    return result?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<bool> disableAdmin() async {
    return await _channel.invokeMethod<bool>('disableAdmin') ?? false;
  }

  static Future<String?> exportConfig() async {
    return await _channel.invokeMethod<String>('exportConfig');
  }

  static Future<Map<String, dynamic>> importConfig(String json) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'importConfig', json);
    return result?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<bool> isBatterySaverEnabled() async {
    return await _channel.invokeMethod<bool>('isBatterySaverEnabled') ?? false;
  }

  static Future<void> setBatterySaverMode(bool enabled) async {
    await _channel.invokeMethod('setBatterySaverMode', enabled);
  }

  static Future<Map<String, dynamic>> getOptimizationStats() async {
    final result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('getOptimizationStats');
    return result?.map((k, v) => MapEntry(k.toString(), v)) ?? {};
  }

  static Future<void> invalidateCache() async {
    await _channel.invokeMethod('invalidateCache');
  }

  static Future<void> forceCleanup() async {
    await _channel.invokeMethod('forceCleanup');
  }

  static Future<Map<dynamic, dynamic>?> getSharedPreferences(
      String prefsName) async {
    return await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getSharedPreferences', prefsName);
  }

  static Future<void> saveSharedPreference(Map<String, dynamic> data) async {
    await _channel.invokeMethod('saveSharedPreference', data);
  }

  static Future<void> startMonitoring() async {
    await _channel.invokeMethod('startMonitoring');
  }

  static Future<void> startMacroScheduler() async {
    await _channel.invokeMethod('startMacroScheduler');
  }

  static Future<void> refreshWidgetsNow() async {
    await _channel.invokeMethod('refreshWidgetsNow');
  }

  static Future<void> notifyOverlayThemeChanged() async {
    await _channel.invokeMethod('notifyOverlayThemeChanged');
  }

  static Future<bool> isDeviceAdminEnabled() async {
    return await _channel.invokeMethod<bool>('isDeviceAdminEnabled') ?? false;
  }

  static Future<void> enableDeviceAdmin() async {
    await _channel.invokeMethod('enableDeviceAdmin');
  }
}




