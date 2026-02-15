package io.github.johnivansn.yugo

import android.app.AppOpsManager
import android.app.ActivityManager
import android.app.DownloadManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.os.BatteryManager
import android.content.IntentFilter
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.Environment
import android.provider.Settings
import android.util.Log
import android.webkit.URLUtil
import androidx.core.content.FileProvider
import io.github.johnivansn.yugo.admin.AdminManager
import io.github.johnivansn.yugo.database.AppDatabase
import io.github.johnivansn.yugo.database.BlockTemplate
import io.github.johnivansn.yugo.database.AppBlock
import io.github.johnivansn.yugo.database.AppSchedule
import io.github.johnivansn.yugo.database.DateBlock
import io.github.johnivansn.yugo.database.getDailyQuotaForDay
import io.github.johnivansn.yugo.database.MacroEntity
import io.github.johnivansn.yugo.database.MacroLibraryEntry
import io.github.johnivansn.yugo.optimization.AppCacheManager
import io.github.johnivansn.yugo.optimization.BatteryModeManager
import io.github.johnivansn.yugo.optimization.DataCleanupManager
import io.github.johnivansn.yugo.services.AppBlockAccessibilityService
import io.github.johnivansn.yugo.services.UsageMonitorService
import io.github.johnivansn.yugo.utils.AppUtils
import io.github.johnivansn.yugo.monitoring.UsageStatsMonitor
import io.github.johnivansn.yugo.blocking.BlockingEngine
import io.github.johnivansn.yugo.widget.AppDirectListWidget
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.github.johnivansn.yugo.macros.MacroScheduler
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.net.URL
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.*
import javax.net.ssl.SSLException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
  private val CHANNEL = "app.block/config"
  private val MACRO_EVENTS_CHANNEL = "io.github.johnivansn.yugo/macro_events"
  private lateinit var database: AppDatabase
  private lateinit var adminManager: AdminManager
  private lateinit var appCacheManager: AppCacheManager
  private lateinit var batteryModeManager: BatteryModeManager
  private lateinit var dataCleanupManager: DataCleanupManager
  private var macroEventsSink: EventChannel.EventSink? = null
  private val scope = CoroutineScope(Dispatchers.Main + Job())
  private val systemPackages =
          setOf(
                  "android",
                  "com.android.systemui",
                  "com.android.settings",
                  "com.google.android.gms",
                  "com.google.android.gsf",
                  "io.github.johnivansn.yugo"
          )

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    database = AppDatabase.getDatabase(this)
    adminManager = AdminManager(this)
    appCacheManager = AppCacheManager(this)
    batteryModeManager = BatteryModeManager(this)
    dataCleanupManager = DataCleanupManager(this)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call,
            result ->
      when (call.method) {
        "getInstalledApps" -> getInstalledAppsQuick(result)
        "getAppName" -> {
          val packageName = call.arguments as? String
          if (packageName != null) {
            result.success(getAppName(packageName))
          } else {
            result.error("INVALID_ARGUMENT", "packageName is required", null)
          }
        }
        "getAppIcon" -> {
          val packageName = call.arguments as? String
          if (packageName != null) {
            getAppIcon(packageName, result)
          } else {
            result.error("INVALID_ARGUMENT", "packageName is required", null)
          }
        }
        "checkUsagePermission" -> result.success(hasUsageStatsPermission())
        "requestUsagePermission" -> {
          requestUsageStatsPermission()
          result.success(null)
        }
        "checkAccessibilityPermission" -> result.success(isAccessibilityServiceEnabled())
        "requestAccessibilityPermission" -> {
          requestAccessibilityPermission()
          result.success(null)
        }
        "startMonitoring" -> {
          startMonitoringService()
          result.success(null)
        }
        "startMacroScheduler" -> {
          MacroScheduler.schedule(this)
          result.success(null)
        }
        "refreshWidgetsNow" -> {
          refreshWidgetsNow()
          result.success(null)
        }
        "notifyOverlayThemeChanged" -> {
          notifyOverlayThemeChanged()
          result.success(null)
        }
        "addBlock" -> {
          val args = call.arguments as Map<*, *>
          scope.launch {
            try {
              addBlock(args)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error adding block", e)
              withContext(Dispatchers.Main) {
                result.error("ADD_block_ERROR", e.message, null)
              }
            }
          }
        }
        "deleteBlock" -> {
          val packageName = call.arguments as String
          scope.launch {
            try {
              deleteBlock(packageName)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error deleting block", e)
              withContext(Dispatchers.Main) {
                result.error("DELETE_block_ERROR", e.message, null)
              }
            }
          }
        }
        "updateBlock" -> {
          val args = call.arguments as Map<*, *>
          scope.launch {
            try {
              updateBlock(args)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error updating block", e)
              withContext(Dispatchers.Main) {
                result.error("UPDATE_block_ERROR", e.message, null)
              }
            }
          }
        }
        "getBlocks" -> {
          scope.launch {
            try {
              val blocks = getBlocks()
              withContext(Dispatchers.Main) { result.success(blocks) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting blocks", e)
              withContext(Dispatchers.Main) {
                result.error("GET_blockS_ERROR", e.message, null)
              }
            }
          }
        }
        "getUsageToday" -> {
          val packageName = call.arguments as String
          scope.launch {
            try {
              val usage = getUsageToday(packageName)
              withContext(Dispatchers.Main) { result.success(usage) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting usage", e)
              withContext(Dispatchers.Main) { result.error("GET_USAGE_ERROR", e.message, null) }
            }
          }
        }
        "isAdminEnabled" -> {
          scope.launch {
            try {
              val enabled = adminManager.isAdminEnabled()
              withContext(Dispatchers.Main) { result.success(enabled) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        "setupAdminPin" -> {
          val pin = call.arguments as String
          scope.launch {
            try {
              val success = adminManager.setupPin(pin)
              withContext(Dispatchers.Main) { result.success(success) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        "verifyAdminPin" -> {
          val pin = call.arguments as String
          scope.launch {
            try {
              val verifyResult = adminManager.verifyPin(pin)
              val response =
                      when (verifyResult) {
                        is AdminManager.VerifyResult.SUCCESS -> mapOf("status" to "success")
                        is AdminManager.VerifyResult.NOT_ENABLED -> mapOf("status" to "not_enabled")
                        is AdminManager.VerifyResult.WrongPin ->
                                mapOf(
                                        "status" to "wrong_pin",
                                        "attemptsRemaining" to verifyResult.attemptsRemaining
                                )
                        is AdminManager.VerifyResult.Locked ->
                                mapOf(
                                        "status" to "locked",
                                        "remainingSeconds" to verifyResult.remainingSeconds
                                )
                      }
              withContext(Dispatchers.Main) { result.success(response) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        "disableAdmin" -> {
          scope.launch {
            try {
              val success = adminManager.disableAdmin()
              withContext(Dispatchers.Main) { result.success(success) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("ADMIN_ERROR", e.message, null) }
            }
          }
        }
        "exportConfig" -> {
          scope.launch {
            try {
              val config = exportConfig()
              withContext(Dispatchers.Main) { result.success(config) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error exporting config", e)
              withContext(Dispatchers.Main) { result.error("EXPORT_ERROR", e.message, null) }
            }
          }
        }
        "importConfig" -> {
          val json = call.arguments as String
          scope.launch {
            try {
              val importResult = importConfig(json)
              withContext(Dispatchers.Main) { result.success(importResult) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error importing config", e)
              withContext(Dispatchers.Main) { result.error("IMPORT_ERROR", e.message, null) }
            }
          }
        }
        "enableDeviceAdmin" -> {
          enableDeviceAdmin()
          result.success(null)
        }
        "isDeviceAdminEnabled" -> {
          result.success(isDeviceAdminEnabled())
        }
        "getDirectBlockPackages" -> {
          scope.launch {
            try {
              val packages = getDirectBlockPackages()
              withContext(Dispatchers.Main) { result.success(packages) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DIRECT_BLOCKS_ERROR", e.message, null)
              }
            }
          }
        }
        "deleteDirectBlocks" -> {
          val packageName = call.arguments as String
          scope.launch {
            try {
              deleteDirectBlocks(packageName)
              withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DELETE_DIRECT_BLOCKS_ERROR", e.message, null)
              }
            }
          }
        }
        "getAppVersion" -> {
          result.success(getAppVersion())
        }
        "getRuntimePackageName" -> {
          result.success(packageName)
        }
        "getSelfAppIcon" -> {
          getSelfAppIcon(result)
        }
        "getReleases" -> {
          scope.launch {
            try {
              val releases = withContext(Dispatchers.IO) { getReleases() }
              withContext(Dispatchers.Main) { result.success(releases) }
            } catch (e: Exception) {
              Log.e("MainActivity", "Error getting releases", e)
              withContext(Dispatchers.Main) {
                result.error(
                        "RELEASES_ERROR",
                        mapNetworkErrorMessage(
                                e,
                                "No se pudieron consultar las actualizaciones. Intenta de nuevo."
                        ),
                        null
                )
              }
            }
          }
        }
        "getMacroExecutionLogs" -> {
          // Placeholder for beta logs. Returns empty list until macro engine is wired.
          result.success(emptyList<Map<String, Any?>>())
        }
        "downloadAndInstallApk" -> {
          val args = call.arguments as Map<*, *>
          val url = args["url"] as String
          val shaUrl = args["shaUrl"] as? String
          scope.launch {
            try {
              val ok = downloadAndInstallApk(url, shaUrl)
              withContext(Dispatchers.Main) { result.success(ok) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error(
                        "APK_INSTALL_ERROR",
                        mapNetworkErrorMessage(
                                e,
                                "No se pudo instalar la versión seleccionada."
                        ),
                        null
                )
              }
            }
          }
        }
        "downloadApkOnly" -> {
          val args = call.arguments as Map<*, *>
          val url = args["url"] as String
          val fileName = args["fileName"] as? String
          try {
            val ok = downloadApkOnly(url, fileName)
            result.success(ok)
          } catch (e: Exception) {
            result.error("APK_DOWNLOAD_ERROR", e.message, null)
          }
        }
        "canInstallPackages" -> {
          result.success(canInstallPackages())
        }
        "requestInstallPermission" -> {
          requestInstallPermission()
          result.success(null)
        }
        "getBatteryLevel" -> {
          result.success(getBatteryLevel())
        }
        else -> {
          handleMethodCallPart2(call, result)
        }
      }
    }

    EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MACRO_EVENTS_CHANNEL
    ).setStreamHandler(
            object : EventChannel.StreamHandler {
              override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                macroEventsSink = events
              }

              override fun onCancel(arguments: Any?) {
                macroEventsSink = null
              }
            }
    )

    MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.johnivansn.yugo/app_info"
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "getAppInfo" -> {
          val info = mapOf(
                  "name" to "Yugo",
                  "version" to (getAppVersion()["versionName"] ?: ""),
                  "description" to "Motor de automatizacion conductual"
          )
          result.success(info)
        }
        else -> result.notImplemented()
      }
    }

    MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.johnivansn.yugo/macro_engine"
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "getAllMacros" -> {
          scope.launch {
            try {
              val macros = database.macroDao().getAll().map { macroToMap(it) }
              withContext(Dispatchers.Main) { result.success(macros) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("MACRO_ERROR", e.message, null) }
            }
          }
        }
        "syncInitialData" -> result.success(mapOf("success" to true))
        "createMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val entity = mapToMacro(args)
              database.macroDao().insert(entity)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to macroToMap(entity)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("MACRO_ERROR", e.message, null) }
            }
          }
        }
        "updateMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val id = args["id"]?.toString() ?: ""
              val existing = database.macroDao().getById(id) ?: run {
                withContext(Dispatchers.Main) {
                  result.success(mapOf("success" to false, "macro" to null))
                }
                return@launch
              }
              val updated = mapToMacro(args, existing)
              database.macroDao().update(updated)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to macroToMap(updated)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("MACRO_ERROR", e.message, null) }
            }
          }
        }
        "deleteMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          val macroId = args["macroId"]?.toString() ?: ""
          scope.launch {
            try {
              if (macroId.isNotBlank()) {
                database.macroDao().deleteById(macroId)
              }
              withContext(Dispatchers.Main) { result.success(mapOf("success" to true)) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("MACRO_ERROR", e.message, null) }
            }
          }
        }
        "toggleMacroActive" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          val macroId = args["macroId"]?.toString() ?: ""
          val isActive = args["isActive"] as? Boolean ?: true
          scope.launch {
            try {
              val existing = database.macroDao().getById(macroId)
              if (existing == null) {
                withContext(Dispatchers.Main) {
                  result.success(mapOf("success" to false, "macro" to null))
                }
                return@launch
              }
              val updated = existing.copy(isActive = isActive, updatedAt = System.currentTimeMillis())
              database.macroDao().update(updated)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to macroToMap(updated)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("MACRO_ERROR", e.message, null) }
            }
          }
        }
        "exportMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          val macroId = args["macroId"]?.toString() ?: ""
          scope.launch {
            try {
              val macro = database.macroDao().getById(macroId)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to (macro != null), "macro" to macro?.let { macroToMap(it) }))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("MACRO_ERROR", e.message, null) }
            }
          }
        }
        "importMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val entity = mapToMacro(args)
              database.macroDao().insert(entity)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to macroToMap(entity)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("MACRO_ERROR", e.message, null) }
            }
          }
        }
        "getAllHabitMacros" -> {
          scope.launch {
            try {
              val habits = database.habitMacroDao().getAll().map { habitToMap(it) }
              withContext(Dispatchers.Main) { result.success(habits) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("HABIT_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "createHabitMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val entity = mapToHabitMacro(args)
              database.habitMacroDao().insert(entity)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to habitToMap(entity)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("HABIT_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "updateHabitMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val id = args["id"]?.toString() ?: ""
              val existing = database.habitMacroDao().getById(id) ?: run {
                withContext(Dispatchers.Main) {
                  result.success(mapOf("success" to false, "macro" to null))
                }
                return@launch
              }
              val updated = mapToHabitMacro(args, existing)
              database.habitMacroDao().update(updated)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to habitToMap(updated)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("HABIT_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "deleteHabitMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          val id = args["id"]?.toString() ?: ""
          scope.launch {
            try {
              if (id.isNotBlank()) {
                database.habitMacroDao().deleteById(id)
              }
              withContext(Dispatchers.Main) { result.success(mapOf("success" to true)) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("HABIT_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "getAllDisciplineMacros" -> {
          scope.launch {
            try {
              val items = database.disciplineMacroDao().getAll().map { disciplineToMap(it) }
              withContext(Dispatchers.Main) { result.success(items) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("DISCIPLINE_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "createDisciplineMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val entity = mapToDisciplineMacro(args)
              database.disciplineMacroDao().insert(entity)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to disciplineToMap(entity)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("DISCIPLINE_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "updateDisciplineMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val id = args["id"]?.toString() ?: ""
              val existing = database.disciplineMacroDao().getById(id) ?: run {
                withContext(Dispatchers.Main) {
                  result.success(mapOf("success" to false, "macro" to null))
                }
                return@launch
              }
              val updated = mapToDisciplineMacro(args, existing)
              database.disciplineMacroDao().update(updated)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to disciplineToMap(updated)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DISCIPLINE_MACRO_ERROR", e.message, null)
              }
            }
          }
        }
        "deleteDisciplineMacro" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          val id = args["id"]?.toString() ?: ""
          scope.launch {
            try {
              if (id.isNotBlank()) {
                database.disciplineMacroDao().deleteById(id)
              }
              withContext(Dispatchers.Main) { result.success(mapOf("success" to true)) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DISCIPLINE_MACRO_ERROR", e.message, null)
              }
            }
          }
        }
        "exportHabitMacros" -> {
          scope.launch {
            try {
              val habits = database.habitMacroDao().getAll().map { habitToMap(it) }
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "habits" to habits))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("HABIT_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "importHabitMacros" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val habitsRaw = args["habits"] as? List<*> ?: emptyList<Any?>()
              habitsRaw.forEach { item ->
                val map = (item as? Map<*, *>) ?: return@forEach
                val entity = mapToHabitMacro(map)
                database.habitMacroDao().insert(entity)
              }
              withContext(Dispatchers.Main) { result.success(mapOf("success" to true)) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("HABIT_MACRO_ERROR", e.message, null) }
            }
          }
        }
        "exportDisciplineMacros" -> {
          scope.launch {
            try {
              val items =
                      database.disciplineMacroDao().getAll().map { disciplineToMap(it) }
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "disciplines" to items))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DISCIPLINE_MACRO_ERROR", e.message, null)
              }
            }
          }
        }
        "importDisciplineMacros" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val items = args["disciplines"] as? List<*> ?: emptyList<Any?>()
              items.forEach { item ->
                val map = (item as? Map<*, *>) ?: return@forEach
                val entity = mapToDisciplineMacro(map)
                database.disciplineMacroDao().insert(entity)
              }
              withContext(Dispatchers.Main) { result.success(mapOf("success" to true)) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) {
                result.error("DISCIPLINE_MACRO_ERROR", e.message, null)
              }
            }
          }
        }
        "emitEvent" -> {
          val payload = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          saveMacroLog(payload)
          macroEventsSink?.success(payload)
          result.success(mapOf("success" to true))
        }
        "emitSystemEvent" -> {
          val payload = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          saveMacroLog(payload)
          macroEventsSink?.success(payload)
          result.success(mapOf("success" to true))
        }
        "getMacroExecutionLogs" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          val macroId = args["macroId"]?.toString() ?: ""
          val limit = (args["limit"] as? Number)?.toInt() ?: 20
          val offset = (args["offset"] as? Number)?.toInt() ?: 0
          scope.launch {
            try {
              val logs =
                      database.macroLogDao().getLogs(macroId, limit, offset).map { log ->
                        mapOf(
                                "macroId" to log.macroId,
                                "timestamp" to log.timestamp.toString(),
                                "title" to log.title,
                                "body" to log.body,
                                "level" to log.level,
                                "source" to log.source
                        )
                      }
              withContext(Dispatchers.Main) { result.success(logs) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.success(emptyList<Map<String, Any?>>()) }
            }
          }
        }
        "getMacroLibrary" -> {
          scope.launch {
            try {
              val items = database.macroLibraryDao().getAll().map { libraryToMap(it) }
              withContext(Dispatchers.Main) { result.success(items) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIBRARY_ERROR", e.message, null) }
            }
          }
        }
        "addMacroLibraryEntry" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val entry = mapToLibraryEntry(args)
              database.macroLibraryDao().insert(entry)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "entry" to libraryToMap(entry)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIBRARY_ERROR", e.message, null) }
            }
          }
        }
        "updateMacroLibraryEntry" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val entry = mapToLibraryEntry(args)
              database.macroLibraryDao().update(entry)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "entry" to libraryToMap(entry)))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIBRARY_ERROR", e.message, null) }
            }
          }
        }
        "deleteMacroLibraryEntry" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          val id = args["id"]?.toString() ?: ""
          scope.launch {
            try {
              if (id.isNotBlank()) {
                database.macroLibraryDao().deleteById(id)
              }
              withContext(Dispatchers.Main) { result.success(mapOf("success" to true)) }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIBRARY_ERROR", e.message, null) }
            }
          }
        }
        "exportLibrary" -> {
          scope.launch {
            try {
              val entries = database.macroLibraryDao().getAll().map { libraryToMap(it) }
              val macros = database.macroDao().getAll().map { macroToMap(it) }
              val habits = database.habitMacroDao().getAll().map { habitToMap(it) }
              val disciplines = database.disciplineMacroDao().getAll().map { disciplineToMap(it) }
              withContext(Dispatchers.Main) {
                result.success(
                        mapOf(
                                "success" to true,
                                "schemaVersion" to 1,
                                "library" to entries,
                                "macros" to macros,
                                "habits" to habits,
                                "disciplines" to disciplines
                        )
                )
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIBRARY_ERROR", e.message, null) }
            }
          }
        }
        "importLibrary" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val schemaVersion = (args["schemaVersion"] as? Number)?.toInt() ?: 1
              if (schemaVersion > 1) {
                withContext(Dispatchers.Main) {
                  result.error("LIBRARY_ERROR", "Schema no soportado: $schemaVersion", null)
                }
                return@launch
              }
              val macrosRaw = args["macros"] as? List<*> ?: emptyList<Any?>()
              val habitsRaw = args["habits"] as? List<*> ?: emptyList<Any?>()
              val disciplinesRaw = args["disciplines"] as? List<*> ?: emptyList<Any?>()
              val libraryRaw = args["library"] as? List<*> ?: emptyList<Any?>()
              var imported = 0
              var skipped = 0
              macrosRaw.forEach { item ->
                val map = (item as? Map<*, *>) ?: return@forEach
                if (!isValidMacroMap(map)) {
                  skipped += 1
                  return@forEach
                }
                val entity = mapToMacro(map)
                database.macroDao().insert(entity)
                imported += 1
              }
              habitsRaw.forEach { item ->
                val map = (item as? Map<*, *>) ?: return@forEach
                if (!isValidStructuredMacroMap(map)) {
                  skipped += 1
                  return@forEach
                }
                val entity = mapToHabitMacro(map)
                database.habitMacroDao().insert(entity)
                imported += 1
              }
              disciplinesRaw.forEach { item ->
                val map = (item as? Map<*, *>) ?: return@forEach
                if (!isValidStructuredMacroMap(map)) {
                  skipped += 1
                  return@forEach
                }
                val entity = mapToDisciplineMacro(map)
                database.disciplineMacroDao().insert(entity)
                imported += 1
              }
              libraryRaw.forEach { item ->
                val map = (item as? Map<*, *>) ?: return@forEach
                if (!isValidLibraryEntry(map)) {
                  skipped += 1
                  return@forEach
                }
                val entry = mapToLibraryEntry(map)
                database.macroLibraryDao().insert(entry)
                imported += 1
              }
              withContext(Dispatchers.Main) {
                result.success(
                        mapOf("success" to true, "imported" to imported, "skipped" to skipped)
                )
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIBRARY_ERROR", e.message, null) }
            }
          }
        }
        "createMacroFromLibraryPayload" -> {
          val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
          scope.launch {
            try {
              val created = createMacroFromLibraryPayload(args)
              withContext(Dispatchers.Main) {
                result.success(mapOf("success" to true, "macro" to created))
              }
            } catch (e: Exception) {
              withContext(Dispatchers.Main) { result.error("LIBRARY_ERROR", e.message, null) }
            }
          }
        }
        else -> result.notImplemented()
      }
    }

    MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.johnivansn.yugo/macro_service"
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "startService" -> {
          startMonitoringService()
          result.success(null)
        }
        "isServiceRunning" -> {
          result.success(true)
        }
        "isBatteryOptimizationDisabled" -> {
          result.success(true)
        }
        "requestDisableBatteryOptimization" -> {
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }

    MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.johnivansn.yugo/accessibility"
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "isAccessibilityEnabled" -> result.success(isAccessibilityServiceEnabled())
        "openAccessibilitySettings" -> {
          requestAccessibilityPermission()
          result.success(null)
        }
        "blockApp" -> result.success(mapOf("success" to true))
        "unblockApp" -> result.success(mapOf("success" to true))
        else -> result.notImplemented()
      }
    }

    MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.johnivansn.yugo/usage_stats"
    ).setMethodCallHandler { call, result ->
      when (call.method) {
        "hasPermission" -> result.success(hasUsageStatsPermission())
        "openPermissionSettings" -> {
          requestUsageStatsPermission()
          result.success(null)
        }
        "getAppUsageTime" -> result.success(0L)
        "getAppUsageStats" -> result.success(emptyMap<String, Any?>())
        else -> result.notImplemented()
      }
    }
  }

  private fun handleMethodCallPart2(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getSchedules" -> {
        val packageName = call.arguments as String
        scope.launch {
          try {
            val schedules = getSchedules(packageName)
            withContext(Dispatchers.Main) { result.success(schedules) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error getting schedules", e)
            withContext(Dispatchers.Main) { result.error("GET_SCHEDULES_ERROR", e.message, null) }
          }
        }
      }
        "checkOverlayPermission" -> {
          result.success(android.provider.Settings.canDrawOverlays(this))
        }
        "getMemoryClass" -> {
          val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
          result.success(am.memoryClass)
        }
        "requestOverlayPermission" -> {
          val intent =
                  Intent(
                        android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:$packageName")
                )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        result.success(null)
      }
      "addSchedule" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            addSchedule(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error adding schedule", e)
            withContext(Dispatchers.Main) { result.error("ADD_SCHEDULE_ERROR", e.message, null) }
          }
        }
      }
      "updateSchedule" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            updateSchedule(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error updating schedule", e)
            withContext(Dispatchers.Main) { result.error("UPDATE_SCHEDULE_ERROR", e.message, null) }
          }
        }
      }
        "deleteSchedule" -> {
          val scheduleId = call.arguments as String
          scope.launch {
            try {
              deleteSchedule(scheduleId)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error deleting schedule", e)
            withContext(Dispatchers.Main) { result.error("DELETE_SCHEDULE_ERROR", e.message, null) }
            }
          }
        }
      "getDateBlocks" -> {
        val packageName = call.arguments as String
        scope.launch {
          try {
            val blocks = getDateBlocks(packageName)
            withContext(Dispatchers.Main) { result.success(blocks) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error getting date blocks", e)
            withContext(Dispatchers.Main) {
              result.error("GET_DATE_BLOCKS_ERROR", e.message, null)
            }
          }
        }
      }
      "addDateBlock" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            addDateBlock(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error adding date block", e)
            withContext(Dispatchers.Main) {
              result.error("ADD_DATE_BLOCK_ERROR", e.message, null)
            }
          }
        }
      }
      "updateDateBlock" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            updateDateBlock(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error updating date block", e)
            withContext(Dispatchers.Main) {
              result.error("UPDATE_DATE_BLOCK_ERROR", e.message, null)
            }
          }
        }
      }
      "deleteDateBlock" -> {
        val blockId = call.arguments as String
        scope.launch {
          try {
            deleteDateBlock(blockId)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error deleting date block", e)
            withContext(Dispatchers.Main) {
              result.error("DELETE_DATE_BLOCK_ERROR", e.message, null)
            }
          }
        }
      }
      "getBlockTemplates" -> {
        scope.launch {
          try {
            val templates = getBlockTemplates()
            withContext(Dispatchers.Main) { result.success(templates) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error getting templates", e)
            withContext(Dispatchers.Main) {
              result.error("GET_BLOCK_TEMPLATES_ERROR", e.message, null)
            }
          }
        }
      }
      "saveBlockTemplate" -> {
        val args = call.arguments as Map<*, *>
        scope.launch {
          try {
            saveBlockTemplate(args)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error saving template", e)
            withContext(Dispatchers.Main) {
              result.error("SAVE_BLOCK_TEMPLATE_ERROR", e.message, null)
            }
          }
        }
      }
      "deleteBlockTemplate" -> {
        val templateId = call.arguments as String
        scope.launch {
          try {
            deleteBlockTemplate(templateId)
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            Log.e("MainActivity", "Error deleting template", e)
            withContext(Dispatchers.Main) {
              result.error("DELETE_BLOCK_TEMPLATE_ERROR", e.message, null)
            }
          }
        }
      }
      "setBatterySaverMode" -> {
        val enabled = call.arguments as Boolean
        batteryModeManager.setBatterySaverEnabled(enabled)
        result.success(null)
      }
      "isBatterySaverEnabled" -> {
        result.success(batteryModeManager.isBatterySaverEnabled())
      }
      "getOptimizationStats" -> {
        scope.launch {
          try {
            val stats = getOptimizationStats()
            withContext(Dispatchers.Main) { result.success(stats) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("STATS_ERROR", e.message, null) }
          }
        }
      }
      "invalidateCache" -> {
        scope.launch {
          try {
            appCacheManager.invalidateCache()
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("CACHE_ERROR", e.message, null) }
          }
        }
      }
      "forceCleanup" -> {
        scope.launch {
          try {
            dataCleanupManager.forceCleanup()
            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("CLEANUP_ERROR", e.message, null) }
          }
        }
      }
      "getSharedPreferences" -> {
        val prefsName = call.arguments as String
        scope.launch {
          try {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val map = prefs.all.mapValues { (_, v) -> v }
            withContext(Dispatchers.Main) { result.success(map) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("PREFS_ERROR", e.message, null) }
          }
        }
      }
      "saveSharedPreference" -> {
        val args = call.arguments as Map<*, *>
        val prefsName = args["prefsName"] as String
        val key = args["key"] as String
        val value = args["value"]

        scope.launch {
          try {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val success =
                    prefs.edit().run {
              when (value) {
                is Boolean -> putBoolean(key, value)
                is String -> putString(key, value)
                is Int -> putInt(key, value)
                is Long -> putLong(key, value)
                is Float -> putFloat(key, value)
                else -> remove(key)
              }
              commit()
            }
            if (!success) {
              throw IllegalStateException("No se pudo guardar $prefsName.$key")
            }

            if (prefsName == "notification_prefs") {
              if (key == "notify_service_status") {
                val enabled = value as? Boolean ?: true
                if (enabled) {
                  startMonitoringService()
                } else {
                  stopMonitoringService()
                }
              } else if (isMonitoringEnabled()) {
                val intent = Intent(this@MainActivity, UsageMonitorService::class.java)
                intent.action = UsageMonitorService.ACTION_UPDATE_NOTIFICATION
                startService(intent)
              }
            }

            withContext(Dispatchers.Main) { result.success(null) }
          } catch (e: Exception) {
            withContext(Dispatchers.Main) { result.error("PREFS_ERROR", e.message, null) }
          }
        }
      }
      else -> result.notImplemented()
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    scope.cancel()
  }

  private suspend fun getSchedules(packageName: String): List<Map<String, Any>> {
    return database.appScheduleDao().getByPackage(packageName).map { schedule ->
      mapOf(
              "id" to schedule.id,
              "packageName" to schedule.packageName,
              "startHour" to schedule.startHour,
              "startMinute" to schedule.startMinute,
              "endHour" to schedule.endHour,
              "endMinute" to schedule.endMinute,
              "daysOfWeek" to schedule.getDaysOfWeekList().map { it + 1 },
              "isEnabled" to schedule.isEnabled
      )
    }
  }

  private suspend fun addSchedule(args: Map<*, *>) {
    val daysList = (args["daysOfWeek"] as? List<*>)?.map { it.toString().toInt() } ?: emptyList()
    val daysOfWeek = daysList.fold(0) { mask, day -> mask or (1 shl (day - 1)) }
    val schedule =
            io.github.johnivansn.yugo.database.AppSchedule(
                    id = java.util.UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    startHour = (args["startHour"] as? Number)?.toInt() ?: 0,
                    startMinute = (args["startMinute"] as? Number)?.toInt() ?: 0,
                    endHour = (args["endHour"] as? Number)?.toInt() ?: 0,
                    endMinute = (args["endMinute"] as? Number)?.toInt() ?: 0,
                    daysOfWeek = daysOfWeek,
                    isEnabled = args["isEnabled"] as? Boolean ?: true,
                    createdAt = System.currentTimeMillis()
            )
    database.appScheduleDao().insert(schedule)
    Log.i("MainActivity", "Schedule added for ${schedule.packageName}")
  }

  private suspend fun updateSchedule(args: Map<*, *>) {
    val id = args["id"] as String
    val existing = database.appScheduleDao().getById(id) ?: return

    val daysList =
            (args["daysOfWeek"] as? List<*>)?.map { it.toString().toInt() }
                    ?: existing.getDaysOfWeekList()
    val daysOfWeek = daysList.fold(0) { mask, day -> mask or (1 shl (day - 1)) }
    val updated =
            existing.copy(
                    startHour = (args["startHour"] as? Number)?.toInt() ?: existing.startHour,
                    startMinute = (args["startMinute"] as? Number)?.toInt() ?: existing.startMinute,
                    endHour = (args["endHour"] as? Number)?.toInt() ?: existing.endHour,
                    endMinute = (args["endMinute"] as? Number)?.toInt() ?: existing.endMinute,
                    daysOfWeek = daysOfWeek,
                    isEnabled = args["isEnabled"] as? Boolean ?: existing.isEnabled
            )
    database.appScheduleDao().update(updated)
    Log.i("MainActivity", "Schedule updated: $id")
  }

  private suspend fun deleteSchedule(scheduleId: String) {
    val schedule = database.appScheduleDao().getById(scheduleId) ?: return
    database.appScheduleDao().delete(schedule)
    Log.i("MainActivity", "Schedule deleted: $scheduleId")
  }

  private suspend fun getDateBlocks(packageName: String): List<Map<String, Any?>> {
    return database.dateBlockDao().getByPackage(packageName).map { block ->
      mapOf(
              "id" to block.id,
              "packageName" to block.packageName,
              "startDate" to block.startDate,
              "endDate" to block.endDate,
              "startHour" to block.startHour,
              "startMinute" to block.startMinute,
              "endHour" to block.endHour,
              "endMinute" to block.endMinute,
              "isEnabled" to block.isEnabled,
              "label" to block.label
      )
    }
  }

  private suspend fun addDateBlock(args: Map<*, *>) {
    val startHour = (args["startHour"] as? Number)?.toInt() ?: 0
    val startMinute = (args["startMinute"] as? Number)?.toInt() ?: 0
    val endHour = (args["endHour"] as? Number)?.toInt() ?: 23
    val endMinute = (args["endMinute"] as? Number)?.toInt() ?: 59
    val block =
            DateBlock(
                    id = UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    startDate = args["startDate"] as String,
                    endDate = args["endDate"] as String,
                    startHour = startHour,
                    startMinute = startMinute,
                    endHour = endHour,
                    endMinute = endMinute,
                    isEnabled = args["isEnabled"] as? Boolean ?: true,
                    label = args["label"] as? String,
                    createdAt = System.currentTimeMillis()
            )
    database.dateBlockDao().insert(block)
    Log.i("MainActivity", "Date block added for ${block.packageName}")
  }

  private suspend fun updateDateBlock(args: Map<*, *>) {
    val id = args["id"] as String
    val existing = database.dateBlockDao().getById(id) ?: return

    val label =
            if (args.containsKey("label")) {
              args["label"] as? String
            } else {
              existing.label
            }

    val updated =
            existing.copy(
                    startDate = (args["startDate"] as? String) ?: existing.startDate,
                    endDate = (args["endDate"] as? String) ?: existing.endDate,
                    startHour = (args["startHour"] as? Number)?.toInt() ?: existing.startHour,
                    startMinute = (args["startMinute"] as? Number)?.toInt() ?: existing.startMinute,
                    endHour = (args["endHour"] as? Number)?.toInt() ?: existing.endHour,
                    endMinute = (args["endMinute"] as? Number)?.toInt() ?: existing.endMinute,
                    isEnabled = (args["isEnabled"] as? Boolean) ?: existing.isEnabled,
                    label = label
            )
    database.dateBlockDao().update(updated)
    Log.i("MainActivity", "Date block updated: $id")
  }

  private suspend fun deleteDateBlock(blockId: String) {
    val block = database.dateBlockDao().getById(blockId) ?: return
    database.dateBlockDao().delete(block)
    Log.i("MainActivity", "Date block deleted: $blockId")
  }

  private suspend fun getBlockTemplates(): List<Map<String, Any?>> {
    return database.blockTemplateDao().getAll().map { template ->
      mapOf(
              "id" to template.id,
              "name" to template.name,
              "type" to template.type,
              "payloadJson" to template.payloadJson,
              "createdAt" to template.createdAt
      )
    }
  }

  private suspend fun saveBlockTemplate(args: Map<*, *>) {
    val id = args["id"] as? String ?: UUID.randomUUID().toString()
    val existing = database.blockTemplateDao().getById(id)

    val name = (args["name"] as? String) ?: existing?.name ?: ""
    val type = (args["type"] as? String) ?: existing?.type ?: ""
    val payloadJson = (args["payloadJson"] as? String) ?: existing?.payloadJson ?: ""
    if (name.isBlank() || type.isBlank() || payloadJson.isBlank()) {
      throw IllegalArgumentException("name, type y payloadJson son obligatorios")
    }

    val template =
            BlockTemplate(
                    id = id,
                    name = name,
                    type = type,
                    payloadJson = payloadJson,
                    createdAt = existing?.createdAt ?: System.currentTimeMillis()
            )
    database.blockTemplateDao().insert(template)
    Log.i("MainActivity", "Block template saved: $id")
  }

  private suspend fun deleteBlockTemplate(templateId: String) {
    database.blockTemplateDao().deleteById(templateId)
    Log.i("MainActivity", "Block template deleted: $templateId")
  }

  private suspend fun exportConfig(): String {
    val blocks = database.appBlockDao().getAll()
    val adminSettings = database.adminSettingsDao().get()
    val schedules = database.appScheduleDao().getAll()
    val dateBlocks = database.dateBlockDao().getAll()
    val blockTemplates = database.blockTemplateDao().getAll()

    val blocksData =
            blocks.map { r ->
              mapOf(
                      "packageName" to r.packageName,
                      "appName" to r.appName,
                      "dailyQuotaMinutes" to r.dailyQuotaMinutes,
                      "isEnabled" to r.isEnabled,
                      "limitType" to r.limitType,
                      "dailyMode" to r.dailyMode,
                      "dailyQuotas" to r.dailyQuotas,
                      "weeklyQuotaMinutes" to r.weeklyQuotaMinutes,
                      "weeklyResetDay" to r.weeklyResetDay,
                      "weeklyResetHour" to r.weeklyResetHour,
                      "weeklyResetMinute" to r.weeklyResetMinute,
                      "expiresAt" to r.expiresAt
                )
              }

    val dateBlocksData =
            dateBlocks.map { b ->
              mapOf(
                      "id" to b.id,
                      "packageName" to b.packageName,
                      "startDate" to b.startDate,
                      "endDate" to b.endDate,
                      "startHour" to b.startHour,
                      "startMinute" to b.startMinute,
                      "endHour" to b.endHour,
                      "endMinute" to b.endMinute,
                      "isEnabled" to b.isEnabled,
                      "label" to b.label
              )
            }

    val schedulesData =
            schedules.map { s ->
              mapOf(
                      "id" to s.id,
                      "packageName" to s.packageName,
                      "startHour" to s.startHour,
                      "startMinute" to s.startMinute,
                      "endHour" to s.endHour,
                      "endMinute" to s.endMinute,
                      "daysOfWeek" to s.daysOfWeek,
                      "isEnabled" to s.isEnabled,
                      "createdAt" to s.createdAt
              )
            }

    val blockTemplatesData =
            blockTemplates.map { t ->
              mapOf(
                      "id" to t.id,
                      "name" to t.name,
                      "type" to t.type,
                      "payloadJson" to t.payloadJson,
                      "createdAt" to t.createdAt
              )
            }

    val exportMap =
            mutableMapOf<String, Any>(
                    "version" to 6,
                    "exportedAt" to System.currentTimeMillis(),
                    "blocks" to blocksData,
                    "schedules" to schedulesData,
                    "dateBlocks" to dateBlocksData,
                    "blockTemplates" to blockTemplatesData
            )

    if (adminSettings != null && adminSettings.isEnabled) {
      exportMap["adminMode"] = mapOf("enabled" to true)
    }

    return com.google.gson.Gson().toJson(exportMap)
  }

  private suspend fun importConfig(json: String): Map<String, Any> {
    val gson = com.google.gson.Gson()
    val type = object : com.google.gson.reflect.TypeToken<Map<String, Any>>() {}.type
    val data =
            gson.fromJson<Map<String, Any>>(json, type)
                    ?: return mapOf("success" to false, "error" to "JSON inválido")

    val version = (data["version"] as? Number)?.toInt() ?: 0
    if (version != 6) {
      return mapOf("success" to false, "error" to "Versión no soportada: $version")
    }

    @Suppress("UNCHECKED_CAST")
    val blocks =
            (data["blocks"] as? List<Map<String, Any>>)
                    ?: return mapOf("success" to false, "error" to "Sin bloqueos en archivo")

    var imported = 0
    var skipped = 0
    var schedulesImported = 0
    var schedulesSkipped = 0
    var expiredAdjusted = 0
    var usageMarked = 0
    val today = AppUtils.newDateFormat().format(java.util.Date())
    val now = System.currentTimeMillis()
    val importPrefs = getSharedPreferences("import_prefs", Context.MODE_PRIVATE)
    importPrefs.edit().putLong("suppress_overlay_until", now + 30_000L).apply()

    for (item in blocks) {
      val pkg = item["packageName"] as? String ?: continue
      val existing = database.appBlockDao().getByPackage(pkg)
      if (existing != null) {
        skipped++
        continue
      }

        val rawExpiresAt = (item["expiresAt"] as? Number)?.toLong()
        val expiredOnImport = rawExpiresAt != null && rawExpiresAt > 0 && rawExpiresAt <= now
        if (expiredOnImport) {
          expiredAdjusted++
        }
        val limitType = item["limitType"] as? String ?: "daily"
        val weeklyResetDay = (item["weeklyResetDay"] as? Number)?.toInt() ?: 2
        val weeklyResetHour = (item["weeklyResetHour"] as? Number)?.toInt() ?: 0
        val weeklyResetMinute = (item["weeklyResetMinute"] as? Number)?.toInt() ?: 0
        val block =
                AppBlock(
                        id = java.util.UUID.randomUUID().toString(),
                        packageName = pkg,
                        appName = item["appName"] as? String ?: pkg,
                        dailyQuotaMinutes = (item["dailyQuotaMinutes"] as? Number)?.toInt() ?: 60,
                        isEnabled = if (expiredOnImport) false else (item["isEnabled"] as? Boolean ?: true),
                        limitType = limitType,
                        dailyMode = item["dailyMode"] as? String ?: "same",
                        dailyQuotas = item["dailyQuotas"] as? String ?: "",
                        weeklyQuotaMinutes =
                                (item["weeklyQuotaMinutes"] as? Number)?.toInt() ?: 0,
                        weeklyResetDay = weeklyResetDay,
                        weeklyResetHour = weeklyResetHour,
                        weeklyResetMinute = weeklyResetMinute,
                        expiresAt = if (expiredOnImport) null else rawExpiresAt,
                        createdAt = System.currentTimeMillis()
                )
      database.appBlockDao().insert(block)
      val usage = database.dailyUsageDao().getUsage(pkg, today)
      if (usage != null) {
        val quotaMinutes =
                if (limitType == "weekly") {
                  (item["weeklyQuotaMinutes"] as? Number)?.toInt() ?: 0
                } else {
                  val dayOfWeek = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
                  block.getDailyQuotaForDay(dayOfWeek)
                }
        val usedMinutes =
                if (limitType == "weekly") {
                  val weekStart =
                          AppUtils.getWeekStartDate(
                                  weeklyResetDay,
                                  weeklyResetHour,
                                  weeklyResetMinute,
                                  AppUtils.newDateFormat()
                          )
                  database.dailyUsageDao().getUsageSince(pkg, weekStart).sumOf { it.usedMinutes }
                } else {
                  usage.usedMinutes
                }
        if (quotaMinutes > 0 && usedMinutes >= quotaMinutes) {
          database.dailyUsageDao().setBlockedForPackageDate(pkg, today, true, now)
          usageMarked++
        }
      }
      imported++
    }

    var dateBlocksImported = 0
    var dateBlocksSkipped = 0
    var templatesImported = 0
    var templatesSkipped = 0

    if (version >= 2) {
      @Suppress("UNCHECKED_CAST")
      val schedules =
              data["schedules"] as? List<Map<String, Any>> ?: emptyList()
      for (item in schedules) {
        val id = item["id"] as? String ?: UUID.randomUUID().toString()
        val existing = database.appScheduleDao().getById(id)
        if (existing != null) {
          schedulesSkipped++
          continue
        }

        val pkg = item["packageName"] as? String ?: continue
        val startHour = (item["startHour"] as? Number)?.toInt() ?: continue
        val startMinute = (item["startMinute"] as? Number)?.toInt() ?: 0
        val endHour = (item["endHour"] as? Number)?.toInt() ?: continue
        val endMinute = (item["endMinute"] as? Number)?.toInt() ?: 0
        val daysOfWeek = (item["daysOfWeek"] as? Number)?.toInt() ?: 0
        val isEnabled = item["isEnabled"] as? Boolean ?: true
        val createdAt = (item["createdAt"] as? Number)?.toLong() ?: System.currentTimeMillis()

        val schedule =
                AppSchedule(
                        id = id,
                        packageName = pkg,
                        startHour = startHour,
                        startMinute = startMinute,
                        endHour = endHour,
                        endMinute = endMinute,
                        daysOfWeek = daysOfWeek,
                        isEnabled = isEnabled,
                        createdAt = createdAt
                )
        database.appScheduleDao().insert(schedule)
        schedulesImported++
      }

      @Suppress("UNCHECKED_CAST")
      val dateBlocks =
              data["dateBlocks"] as? List<Map<String, Any>> ?: emptyList()
      for (item in dateBlocks) {
        val id = item["id"] as? String ?: UUID.randomUUID().toString()
        val existing = database.dateBlockDao().getById(id)
        if (existing != null) {
          dateBlocksSkipped++
          continue
        }

        val pkg = item["packageName"] as? String ?: continue
        val startDate = item["startDate"] as? String ?: continue
        val endDate = item["endDate"] as? String ?: continue
        val startHour = (item["startHour"] as? Number)?.toInt() ?: 0
        val startMinute = (item["startMinute"] as? Number)?.toInt() ?: 0
        val endHour = (item["endHour"] as? Number)?.toInt() ?: 23
        val endMinute = (item["endMinute"] as? Number)?.toInt() ?: 59
        val isEnabled = item["isEnabled"] as? Boolean ?: true
        val label = item["label"] as? String

        val block =
                DateBlock(
                        id = id,
                        packageName = pkg,
                        startDate = startDate,
                        endDate = endDate,
                        startHour = startHour,
                        startMinute = startMinute,
                        endHour = endHour,
                        endMinute = endMinute,
                        isEnabled = isEnabled,
                        label = label,
                        createdAt = System.currentTimeMillis()
                )
        database.dateBlockDao().insert(block)
        dateBlocksImported++
      }

      @Suppress("UNCHECKED_CAST")
      val templates =
              data["blockTemplates"] as? List<Map<String, Any>> ?: emptyList()
      for (item in templates) {
        val id = item["id"] as? String ?: UUID.randomUUID().toString()
        val existing = database.blockTemplateDao().getById(id)
        if (existing != null) {
          templatesSkipped++
          continue
        }

        val name = item["name"] as? String ?: continue
        val typeValue = item["type"] as? String ?: continue
        val payloadJson = item["payloadJson"] as? String ?: continue
        val createdAt = (item["createdAt"] as? Number)?.toLong() ?: System.currentTimeMillis()

        val template =
                BlockTemplate(
                        id = id,
                        name = name,
                        type = typeValue,
                        payloadJson = payloadJson,
                        createdAt = createdAt
                )
        database.blockTemplateDao().insert(template)
        templatesImported++
      }
    }

    Log.i(
            "MainActivity",
            "Import: $imported imported, $skipped skipped, " +
                    "schedules $schedulesImported/$schedulesSkipped, " +
                    "dateBlocks $dateBlocksImported/$dateBlocksSkipped, " +
                    "templates $templatesImported/$templatesSkipped"
    )
    return mapOf(
            "success" to true,
            "imported" to imported,
            "skipped" to skipped,
            "expiredAdjusted" to expiredAdjusted,
            "usageMarked" to usageMarked,
            "schedulesImported" to schedulesImported,
            "schedulesSkipped" to schedulesSkipped,
            "dateBlocksImported" to dateBlocksImported,
            "dateBlocksSkipped" to dateBlocksSkipped,
            "templatesImported" to templatesImported,
            "templatesSkipped" to templatesSkipped
    )
  }

  private fun hasUsageStatsPermission(): Boolean {
    return try {
      val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
      val mode =
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        packageName
                )
              } else {
                appOps.checkOpNoThrow(
                        AppOpsManager.OPSTR_GET_USAGE_STATS,
                        Process.myUid(),
                        packageName
                )
              }
      if (mode == AppOpsManager.MODE_ALLOWED) {
        return true
      }
      if (mode != AppOpsManager.MODE_DEFAULT) {
        return false
      }

      val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
      val end = System.currentTimeMillis()
      val start = end - 60 * 60 * 1000L

      val stats =
              usageStatsManager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
      if (!stats.isNullOrEmpty()) {
        return true
      }

      val events = usageStatsManager.queryEvents(end - 60 * 1000L, end)
      val event = UsageEvents.Event()
      events != null && events.hasNextEvent().also { if (it) events.getNextEvent(event) }
    } catch (_: Exception) {
      false
    }
  }

  private fun getInstalledAppsQuick(result: MethodChannel.Result) {
    Thread {
              try {
                val pm = packageManager
                val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

                  val appList =
                          apps.mapNotNull { app ->
                            try {
                              val cachedIcon = appCacheManager.getCachedIconBytes(app.packageName)
                              mapOf(
                                      "appName" to pm.getApplicationLabel(app).toString(),
                                      "packageName" to app.packageName,
                                      "isSystem" to
                                              ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                                      "icon" to cachedIcon
                              )
                            } catch (e: Exception) {
                              null
                            }
                          }

                Handler(Looper.getMainLooper()).post { result.success(appList) }
              } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                  result.error("ERROR", "Error getting apps: ${e.message}", null)
                }
              }
            }
            .start()
  }

  private fun getAppIcon(packageName: String, result: MethodChannel.Result) {
      Thread {
                try {
                  val cached = appCacheManager.getCachedIconBytes(packageName)
                  if (cached != null && cached.isNotEmpty()) {
                    Handler(Looper.getMainLooper()).post { result.success(cached) }
                    return@Thread
                  }
                  val pm = packageManager
                  val app = pm.getApplicationInfo(packageName, 0)
                  val drawable = pm.getApplicationIcon(app)
  
                    val bitmap = AppUtils.drawableToBitmap(drawable, maxSize = 96)
                  val stream = ByteArrayOutputStream()
                  bitmap.compress(Bitmap.CompressFormat.PNG, 50, stream)
                  val iconBytes = stream.toByteArray()
  
                  appCacheManager.cacheIconBytes(packageName, iconBytes)
                  Handler(Looper.getMainLooper()).post { result.success(iconBytes) }
                } catch (e: Exception) {
                  if (packageName == this.packageName) {
                    getSelfAppIcon(result)
                  } else {
                    Handler(Looper.getMainLooper()).post { result.success(null) }
                  }
                }
              }
              .start()
    }

  private fun getSelfAppIcon(result: MethodChannel.Result) {
    Thread {
      try {
        val drawable = applicationInfo.loadIcon(packageManager)
        val bitmap = AppUtils.drawableToBitmap(drawable, maxSize = 96)
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        Handler(Looper.getMainLooper()).post { result.success(stream.toByteArray()) }
      } catch (e: Exception) {
        Handler(Looper.getMainLooper()).post { result.success(null) }
      }
    }.start()
  }

  private fun requestUsageStatsPermission() {
    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
  }

  private fun isAccessibilityServiceEnabled(): Boolean {
    val component = ComponentName(this, AppBlockAccessibilityService::class.java)
    val expected = component.flattenToString()
    val expectedShort = component.flattenToShortString()
    val enabledServices =
            Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
    return enabledServices
            .split(':')
            .map { it.trim() }
            .any { it.equals(expected, ignoreCase = true) || it.equals(expectedShort, ignoreCase = true) }
  }

  private fun requestAccessibilityPermission() {
    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
  }

  private fun startMonitoringService() {
    if (!isMonitoringEnabled()) {
      stopMonitoringService()
      return
    }
    val intent = Intent(this, UsageMonitorService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      startForegroundService(intent)
    } else {
      startService(intent)
    }
  }

  private fun stopMonitoringService() {
    val intent = Intent(this, UsageMonitorService::class.java)
    stopService(intent)
  }

  private fun isMonitoringEnabled(): Boolean {
    val prefs = getSharedPreferences("notification_prefs", Context.MODE_PRIVATE)
    return prefs.getBoolean("notify_service_status", true)
  }

  private fun refreshWidgetsNow() {
    AppDirectListWidget.updateWidget(this)
  }

  private fun notifyOverlayThemeChanged() {
    val intent = Intent(AppBlockAccessibilityService.ACTION_OVERLAY_THEME_CHANGED)
    sendBroadcast(intent)
  }

  private fun getInstalledApps(): List<Map<String, Any>> {
    val pm = packageManager

    val packages =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
              pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0L))
            } else {
              pm.getInstalledApplications(PackageManager.GET_META_DATA)
            }

    val coreSystemPackages =
            setOf(
                    "io.github.johnivansn.yugo",
                    "com.android.systemui",
                    "android",
                    "com.android.system",
                    "com.android.settings"
            )

    return packages
            .filter { it.packageName !in coreSystemPackages }
            .distinctBy { it.packageName }
            .map { appInfo ->
              val hasSystemFlag = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
              val hasUpdatedFlag = (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
              val sourceDir = appInfo.sourceDir ?: ""

              val isSystem =
                      when {
                        hasUpdatedFlag -> false
                        sourceDir.contains("/data/app/") -> false
                        hasSystemFlag -> true
                        sourceDir.contains("/system/") || sourceDir.contains("/product/") -> true
                        else -> false
                      }

              val appName =
                      try {
                        appInfo.loadLabel(pm).toString()
                      } catch (_: Exception) {
                        appInfo.packageName
                      }

              val iconBytes =
                      try {
                        val drawable = appInfo.loadIcon(pm)
                          val bitmap = AppUtils.drawableToBitmap(drawable)
                        val stream = java.io.ByteArrayOutputStream()
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                        stream.toByteArray()
                      } catch (_: Exception) {
                        null
                      }

              mapOf<String, Any>(
                      "packageName" to appInfo.packageName,
                      "appName" to appName,
                      "isSystem" to isSystem,
                      "icon" to (iconBytes ?: byteArrayOf())
              )
            }
            .sortedWith(
                    compareBy(
                            { (it["isSystem"] as? Boolean) ?: false },
                            { it["appName"]?.toString()?.lowercase() ?: "" }
                    )
            )
  }

  private fun getAppVersion(): Map<String, Any?> {
    return try {
      val pm = packageManager
      val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
      } else {
        @Suppress("DEPRECATION")
        pm.getPackageInfo(packageName, 0)
      }
      val versionCode =
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
              } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
              }
      mapOf(
              "versionName" to (info.versionName ?: ""),
              "versionCode" to versionCode
      )
    } catch (e: Exception) {
      mapOf("versionName" to "", "versionCode" to 0L)
    }
  }

  private fun getReleases(): List<Map<String, Any?>> {
    val url = URL("https://api.github.com/repos/johnivansn/Yugo/releases")
    val conn = url.openConnection() as HttpURLConnection
    conn.requestMethod = "GET"
    conn.setRequestProperty("Accept", "application/vnd.github+json")
    conn.setRequestProperty("User-Agent", "Yugo")
    conn.connectTimeout = 8000
    conn.readTimeout = 8000
    conn.connect()
    val code = conn.responseCode
    if (code !in 200..299) {
      throw IllegalStateException("GitHub API error: $code")
    }
    val body = conn.inputStream.bufferedReader().use { it.readText() }
    conn.disconnect()
    val json = org.json.JSONArray(body)
    val releases = mutableListOf<Map<String, Any?>>()
    for (i in 0 until json.length()) {
      val item = json.getJSONObject(i)
      if (item.optBoolean("draft", false)) continue
      val assetsJson = item.optJSONArray("assets") ?: org.json.JSONArray()
      val assets = mutableListOf<Map<String, Any?>>()
      for (j in 0 until assetsJson.length()) {
        val asset = assetsJson.getJSONObject(j)
        assets.add(
                mapOf(
                        "name" to asset.optString("name"),
                        "url" to asset.optString("browser_download_url"),
                        "size" to asset.optLong("size", 0L)
                )
        )
      }
      releases.add(
              mapOf(
                      "tagName" to item.optString("tag_name"),
                      "name" to item.optString("name"),
                      "body" to item.optString("body"),
                      "publishedAt" to item.optString("published_at"),
                      "assets" to assets,
                      "prerelease" to item.optBoolean("prerelease", false)
              )
      )
    }
    return releases
  }

  private fun canInstallPackages(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      packageManager.canRequestPackageInstalls()
    } else {
      true
    }
  }

  private fun requestInstallPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val intent =
              Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                      .setData(Uri.parse("package:$packageName"))
                      .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      startActivity(intent)
    }
  }

  private fun downloadAndInstallApk(url: String, shaUrl: String?): Boolean {
    val cacheDir = File(cacheDir, "apks").apply { mkdirs() }
    val apkFile = File(cacheDir, "update.apk")
    downloadToFile(url, apkFile)

    if (!shaUrl.isNullOrBlank()) {
      val expected = downloadSha256(shaUrl)
      if (expected != null) {
        val actual = sha256(apkFile)
        if (!expected.equals(actual, ignoreCase = true)) {
          apkFile.delete()
          throw IllegalStateException("SHA256 mismatch")
        }
      }
    }

    val uri =
            FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    apkFile
            )
    val intent =
            Intent(Intent.ACTION_VIEW).apply {
              setDataAndType(uri, "application/vnd.android.package-archive")
              addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
              addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
    startActivity(intent)
    return true
  }

  private fun downloadApkOnly(url: String, fileName: String?): Boolean {
    val request =
            DownloadManager.Request(Uri.parse(url)).apply {
              setTitle("Yugo")
              setDescription("Descargando APK")
              setNotificationVisibility(
                      DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
              )
              setMimeType("application/vnd.android.package-archive")
              setAllowedOverMetered(true)
              setAllowedOverRoaming(true)
              val safeName =
                      if (fileName.isNullOrBlank()) URLUtil.guessFileName(url, null, null)
                      else fileName
              setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, safeName)
            }

    val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    manager.enqueue(request)
    return true
  }

  private fun downloadToFile(url: String, dest: File) {
    val conn = URL(url).openConnection() as HttpURLConnection
    conn.connectTimeout = 10000
    conn.readTimeout = 20000
    conn.connect()
    if (conn.responseCode !in 200..299) {
      throw IllegalStateException("Download error: ${conn.responseCode}")
    }
    BufferedInputStream(conn.inputStream).use { input ->
      FileOutputStream(dest).use { output ->
        val buffer = ByteArray(8 * 1024)
        var read: Int
        while (input.read(buffer).also { read = it } != -1) {
          output.write(buffer, 0, read)
        }
      }
    }
    conn.disconnect()
  }

  private fun downloadSha256(url: String): String? {
    val conn = URL(url).openConnection() as HttpURLConnection
    conn.connectTimeout = 8000
    conn.readTimeout = 8000
    conn.connect()
    if (conn.responseCode !in 200..299) return null
    val text = conn.inputStream.bufferedReader().use { it.readText() }
    conn.disconnect()
    val regex = Regex("([A-Fa-f0-9]{64})")
    val match = regex.find(text) ?: return null
    return match.groupValues[1]
  }

  private fun sha256(file: File): String {
    val digest = MessageDigest.getInstance("SHA-256")
    file.inputStream().use { input ->
      val buffer = ByteArray(8 * 1024)
      var read: Int
      while (input.read(buffer).also { read = it } != -1) {
        digest.update(buffer, 0, read)
      }
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
  }

  private suspend fun getOptimizationStats(): Map<String, Any> {
    val cleanupStats = dataCleanupManager.getCleanupStats()
    val cacheSize = appCacheManager.getCacheSize()

    return mapOf(
            "batterySaverEnabled" to batteryModeManager.isBatterySaverEnabled(),
            "updateIntervalMs" to batteryModeManager.getUpdateInterval(),
            "cacheSizeKB" to (cacheSize / 1024),
            "databaseSizeMB" to cleanupStats["databaseSizeMB"]!!,
            "usageRecordCount" to cleanupStats["usageRecordCount"]!!,
            "lastCleanup" to cleanupStats["lastCleanup"]!!
    )
  }

  private suspend fun addBlock(args: Map<*, *>) {
    val macroType = (args["macroType"] as? String) ?: "LIMIT"
    val limitType = (args["limitType"] as? String) ?: "daily"
    val dailyMode = (args["dailyMode"] as? String) ?: "same"
    val dailyQuotas = parseDailyQuotas(args["dailyQuotas"])
    val weeklyQuotaMinutes = (args["weeklyQuotaMinutes"] as? Number)?.toInt() ?: 0
    val weeklyResetDay = (args["weeklyResetDay"] as? Number)?.toInt() ?: 2
    val weeklyResetHour = (args["weeklyResetHour"] as? Number)?.toInt() ?: 0
    val weeklyResetMinute = (args["weeklyResetMinute"] as? Number)?.toInt() ?: 0
    val expiresAt = (args["expiresAt"] as? Number)?.toLong()
    val block =
            AppBlock(
                    id = UUID.randomUUID().toString(),
                    packageName = args["packageName"] as String,
                    appName = args["appName"] as String,
                    dailyQuotaMinutes = args["dailyQuotaMinutes"] as Int,
                    isEnabled = args["isEnabled"] as Boolean,
                    macroType = macroType,
                    limitType = limitType,
                    dailyMode = dailyMode,
                    dailyQuotas = dailyQuotas,
            weeklyQuotaMinutes = weeklyQuotaMinutes,
            weeklyResetDay = weeklyResetDay,
            weeklyResetHour = weeklyResetHour,
            weeklyResetMinute = weeklyResetMinute,
            expiresAt = expiresAt,
            createdAt = System.currentTimeMillis()
    )
    database.appBlockDao().insert(block)
  }

  private fun getBatteryLevel(): Int? {
    val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    if (level in 0..100) return level
    val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    val rawLevel = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
    val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
    if (rawLevel < 0 || scale <= 0) return null
    return ((rawLevel * 100f) / scale).toInt().coerceIn(0, 100)
  }

  private fun getAppName(packageName: String): String? {
    return try {
      val pm = packageManager
      val appInfo = pm.getApplicationInfo(packageName, 0)
      pm.getApplicationLabel(appInfo).toString()
    } catch (_: Exception) {
      null
    }
  }

  private suspend fun updateBlock(args: Map<*, *>) {
    val packageName = args["packageName"] as String
    val block = database.appBlockDao().getByPackage(packageName) ?: return
    val expiresAt =
            if (args.containsKey("expiresAt")) {
              (args["expiresAt"] as? Number)?.toLong()
            } else {
              block.expiresAt
            }

    val updated =
            block.copy(
                    dailyQuotaMinutes =
                            (args["dailyQuotaMinutes"] as? Number)?.toInt()
                                    ?: block.dailyQuotaMinutes,
                    isEnabled = (args["isEnabled"] as? Boolean) ?: block.isEnabled,
                    macroType = (args["macroType"] as? String) ?: block.macroType,
                    limitType = (args["limitType"] as? String) ?: block.limitType,
                    dailyMode = (args["dailyMode"] as? String) ?: block.dailyMode,
                    dailyQuotas = parseDailyQuotas(args["dailyQuotas"], block.dailyQuotas),
                    weeklyQuotaMinutes =
                            (args["weeklyQuotaMinutes"] as? Number)?.toInt()
                                    ?: block.weeklyQuotaMinutes,
                    weeklyResetDay =
                            (args["weeklyResetDay"] as? Number)?.toInt()
                                    ?: block.weeklyResetDay,
                    weeklyResetHour =
                            (args["weeklyResetHour"] as? Number)?.toInt()
                                    ?: block.weeklyResetHour,
                    weeklyResetMinute =
                            (args["weeklyResetMinute"] as? Number)?.toInt()
                                    ?: block.weeklyResetMinute,
                    expiresAt = expiresAt
            )
    database.appBlockDao().update(updated)
  }

  private suspend fun deleteBlock(packageName: String) {
    val block = database.appBlockDao().getByPackage(packageName) ?: return
    database.appBlockDao().delete(block)
    database.appScheduleDao().deleteByPackage(packageName)
    database.dateBlockDao().deleteByPackage(packageName)
    Log.i("MainActivity", "Deleted block for $packageName")
  }

  private suspend fun getDirectBlockPackages(): List<String> {
    val schedules = database.appScheduleDao().getPackages()
    val dates = database.dateBlockDao().getPackages()
    return (schedules + dates).distinct()
  }

  private suspend fun deleteDirectBlocks(packageName: String) {
    database.appScheduleDao().deleteByPackage(packageName)
    database.dateBlockDao().deleteByPackage(packageName)
    Log.i("MainActivity", "Deleted direct blocks for $packageName")
  }

  private suspend fun getBlocks(): List<Map<String, Any?>> {
    return database.appBlockDao().getAll().map { block ->
      mapOf(
              "id" to block.id,
              "packageName" to block.packageName,
              "appName" to block.appName,
              "dailyQuotaMinutes" to block.dailyQuotaMinutes,
              "isEnabled" to block.isEnabled,
              "limitType" to block.limitType,
              "dailyMode" to block.dailyMode,
              "dailyQuotas" to block.dailyQuotas,
              "weeklyQuotaMinutes" to block.weeklyQuotaMinutes,
              "weeklyResetDay" to block.weeklyResetDay,
              "weeklyResetHour" to block.weeklyResetHour,
              "weeklyResetMinute" to block.weeklyResetMinute,
              "expiresAt" to block.expiresAt
      )
    }
  }

  private suspend fun getUsageToday(packageName: String): Map<String, Any> {
    val dateFormat = AppUtils.newDateFormat()
    val today = dateFormat.format(Date())
    val usage = database.dailyUsageDao().getUsage(packageName, today)
    val liveMillis = UsageStatsMonitor(this).getUsageToday(packageName)
    val block = database.appBlockDao().getByPackage(packageName)
              val weekStart =
                      if (block != null) AppUtils.getWeekStartDate(
                      block.weeklyResetDay,
                      block.weeklyResetHour,
                      block.weeklyResetMinute,
                      dateFormat
              )
              else today
    val weekUsages = database.dailyUsageDao().getUsageSince(packageName, weekStart)
    val weekMinutes = weekUsages.sumOf { it.usedMinutes }
    val blockReason = BlockingEngine(this).shouldBlockSync(packageName)
    return mapOf(
            "usedMinutes" to (usage?.usedMinutes ?: 0),
            "isBlocked" to ((usage?.isBlocked ?: false) || blockReason != null),
            "usedMillis" to liveMillis,
            "usedMinutesWeek" to weekMinutes,
            "weekStart" to weekStart
    )
  }

  private fun parseDailyQuotas(value: Any?, fallback: String = ""): String {
    if (value == null) return fallback
    if (value is String) return value
    if (value is Map<*, *>) {
      return value.entries
              .mapNotNull { (k, v) ->
                val day = k?.toString()?.toIntOrNull() ?: return@mapNotNull null
                val minutes = when (v) {
                  is Number -> v.toInt()
                  else -> v?.toString()?.toIntOrNull()
                } ?: return@mapNotNull null
                "$day:$minutes"
              }
              .joinToString(",")
    }
    return fallback
  }

  private fun enableDeviceAdmin() {
    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent =
            ComponentName(this, io.github.johnivansn.yugo.admin.DeviceAdminManager::class.java)

    if (!dpm.isAdminActive(adminComponent)) {
      val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
      intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
      intent.putExtra(
              DevicePolicyManager.EXTRA_ADD_EXPLANATION,
              "Protege contra desinstalación accidental de la app"
      )
      startActivityForResult(intent, REQUEST_ENABLE_ADMIN)
    }
  }

  private fun isDeviceAdminEnabled(): Boolean {
    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent =
            ComponentName(this, io.github.johnivansn.yugo.admin.DeviceAdminManager::class.java)
    return dpm.isAdminActive(adminComponent)
  }

  private fun macroPrefs() = getSharedPreferences("macro_engine", Context.MODE_PRIVATE)

  private fun readAllMacros(): List<Map<String, Any?>> {
    val raw = macroPrefs().getString("macros_json", null) ?: return emptyList()
    return try {
      val arr = org.json.JSONArray(raw)
      (0 until arr.length()).mapNotNull { i ->
        val obj = arr.optJSONObject(i) ?: return@mapNotNull null
        jsonObjectToMap(obj)
      }
    } catch (_: Exception) {
      emptyList()
    }
  }

  private fun findMacroById(macroId: String): Map<String, Any?>? {
    return readAllMacros().firstOrNull { it["id"]?.toString() == macroId }
  }

  private fun createMacro(args: Map<*, *>): Map<String, Any?> {
    val list = readAllMacros().toMutableList()
    val map = argsToMap(args).toMutableMap()
    val id = (map["id"]?.toString()?.takeIf { it.isNotBlank() }) ?: UUID.randomUUID().toString()
    map["id"] = id
    if (!map.containsKey("createdAt")) {
      map["createdAt"] = System.currentTimeMillis()
    }
    list.add(0, map)
    persistMacros(list)
    return map
  }

  private fun updateMacro(args: Map<*, *>): Map<String, Any?>? {
    val id = args["id"]?.toString() ?: return null
    val list = readAllMacros().toMutableList()
    val index = list.indexOfFirst { it["id"]?.toString() == id }
    if (index == -1) return null
    val merged = list[index].toMutableMap().apply {
      putAll(argsToMap(args))
    }
    list[index] = merged
    persistMacros(list)
    return merged
  }

  private fun deleteMacro(id: String): Boolean {
    if (id.isBlank()) return false
    val list = readAllMacros().toMutableList()
    val before = list.size
    list.removeAll { it["id"]?.toString() == id }
    if (list.size == before) return false
    persistMacros(list)
    return true
  }

  private fun toggleMacroActive(id: String, isActive: Boolean): Map<String, Any?>? {
    val list = readAllMacros().toMutableList()
    val index = list.indexOfFirst { it["id"]?.toString() == id }
    if (index == -1) return null
    val updated = list[index].toMutableMap()
    updated["isActive"] = isActive
    list[index] = updated
    persistMacros(list)
    return updated
  }

  private fun persistMacros(list: List<Map<String, Any?>>) {
    val arr = org.json.JSONArray()
    list.forEach { map -> arr.put(org.json.JSONObject(map)) }
    macroPrefs().edit().putString("macros_json", arr.toString()).apply()
  }

  private fun argsToMap(args: Map<*, *>): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    args.forEach { (k, v) ->
      val key = k?.toString() ?: return@forEach
      map[key] = v
    }
    return map
  }

  private fun jsonObjectToMap(obj: org.json.JSONObject): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    val it = obj.keys()
    while (it.hasNext()) {
      val key = it.next()
      val value = obj.opt(key)
      map[key] = value
    }
    return map
  }

  private fun saveMacroLog(payload: Map<*, *>) {
    val macroId = payload["macroId"]?.toString()
            ?: payload["macro_id"]?.toString()
            ?: payload["id"]?.toString()
    if (macroId.isNullOrBlank()) return
    val log = mutableMapOf<String, Any?>()
    log["macroId"] = macroId
    log["timestamp"] = payload["timestamp"]?.toString() ?: System.currentTimeMillis().toString()
    log["title"] = payload["title"]?.toString() ?: payload["type"]?.toString() ?: "evento"
    log["body"] = payload["message"]?.toString() ?: payload["body"]?.toString() ?: ""

    val prefs = macroPrefs()
    val raw = prefs.getString("macro_logs_json", null)
    val arr = if (raw.isNullOrBlank()) org.json.JSONArray() else org.json.JSONArray(raw)
    arr.put(org.json.JSONObject(log))
    prefs.edit().putString("macro_logs_json", arr.toString()).apply()
  }

  private fun readMacroLogs(macroId: String, limit: Int, offset: Int): List<Map<String, Any?>> {
    return emptyList()
  }

  private fun macroToMap(entity: MacroEntity): Map<String, Any?> {
    return mapOf(
            "id" to entity.id,
            "name" to entity.name,
            "description" to entity.description,
            "isActive" to entity.isActive,
            "macroType" to entity.macroType,
            "actionType" to entity.actionType,
            "packageName" to entity.packageName,
            "appName" to entity.appName,
            "minutes" to entity.minutes,
            "createdAt" to entity.createdAt,
            "updatedAt" to entity.updatedAt
    )
  }

  private fun habitToMap(entity: io.github.johnivansn.yugo.database.HabitMacroEntity): Map<String, Any?> {
    return mapOf(
            "id" to entity.id,
            "name" to entity.name,
            "isActive" to entity.isActive,
            "macroType" to entity.macroType,
            "priority" to entity.priority,
            "triggersJson" to entity.triggersJson,
            "conditionsJson" to entity.conditionsJson,
            "actionsJson" to entity.actionsJson,
            "stateJson" to entity.stateJson,
            "createdAt" to entity.createdAt,
            "updatedAt" to entity.updatedAt
    )
  }

  private fun disciplineToMap(entity: io.github.johnivansn.yugo.database.DisciplineMacroEntity): Map<String, Any?> {
    return mapOf(
            "id" to entity.id,
            "name" to entity.name,
            "isActive" to entity.isActive,
            "macroType" to entity.macroType,
            "priority" to entity.priority,
            "triggersJson" to entity.triggersJson,
            "conditionsJson" to entity.conditionsJson,
            "actionsJson" to entity.actionsJson,
            "stateJson" to entity.stateJson,
            "createdAt" to entity.createdAt,
            "updatedAt" to entity.updatedAt
    )
  }

  private fun mapToHabitMacro(
          args: Map<*, *>,
          existing: io.github.johnivansn.yugo.database.HabitMacroEntity? = null
  ): io.github.johnivansn.yugo.database.HabitMacroEntity {
    val now = System.currentTimeMillis()
    val id =
            (args["id"]?.toString()?.takeIf { it.isNotBlank() })
                    ?: existing?.id
                    ?: UUID.randomUUID().toString()
    val name = args["name"]?.toString() ?: existing?.name ?: "Hábito"
    val isActive = (args["isActive"] as? Boolean) ?: existing?.isActive ?: true
    val macroType = args["macroType"]?.toString() ?: existing?.macroType ?: "HABIT_PERSISTENT"
    val priority =
            (args["priority"] as? Number)?.toInt()
                    ?: existing?.priority
                    ?: 0
    val triggersJson = args["triggersJson"]?.toString() ?: existing?.triggersJson ?: "[]"
    val conditionsJson = args["conditionsJson"]?.toString() ?: existing?.conditionsJson ?: "[]"
    val actionsJson = args["actionsJson"]?.toString() ?: existing?.actionsJson ?: "[]"
    val stateJson = args["stateJson"]?.toString() ?: existing?.stateJson ?: "{}"
    val createdAt =
            (args["createdAt"] as? Number)?.toLong() ?: existing?.createdAt ?: now
    val updatedAt =
            (args["updatedAt"] as? Number)?.toLong() ?: now
    return io.github.johnivansn.yugo.database.HabitMacroEntity(
            id = id,
            name = name,
            isActive = isActive,
            macroType = macroType,
            priority = priority,
            triggersJson = triggersJson,
            conditionsJson = conditionsJson,
            actionsJson = actionsJson,
            stateJson = stateJson,
            createdAt = createdAt,
            updatedAt = updatedAt
    )
  }

  private fun mapToDisciplineMacro(
          args: Map<*, *>,
          existing: io.github.johnivansn.yugo.database.DisciplineMacroEntity? = null
  ): io.github.johnivansn.yugo.database.DisciplineMacroEntity {
    val now = System.currentTimeMillis()
    val id =
            (args["id"]?.toString()?.takeIf { it.isNotBlank() })
                    ?: existing?.id
                    ?: UUID.randomUUID().toString()
    val name = args["name"]?.toString() ?: existing?.name ?: "Disciplina"
    val isActive = (args["isActive"] as? Boolean) ?: existing?.isActive ?: true
    val macroType = args["macroType"]?.toString() ?: existing?.macroType ?: "DISCIPLINE"
    val priority =
            (args["priority"] as? Number)?.toInt()
                    ?: existing?.priority
                    ?: 0
    val triggersJson = args["triggersJson"]?.toString() ?: existing?.triggersJson ?: "[]"
    val conditionsJson = args["conditionsJson"]?.toString() ?: existing?.conditionsJson ?: "[]"
    val actionsJson = args["actionsJson"]?.toString() ?: existing?.actionsJson ?: "[]"
    val stateJson = args["stateJson"]?.toString() ?: existing?.stateJson ?: "{}"
    val createdAt =
            (args["createdAt"] as? Number)?.toLong() ?: existing?.createdAt ?: now
    val updatedAt =
            (args["updatedAt"] as? Number)?.toLong() ?: now
    return io.github.johnivansn.yugo.database.DisciplineMacroEntity(
            id = id,
            name = name,
            isActive = isActive,
            macroType = macroType,
            priority = priority,
            triggersJson = triggersJson,
            conditionsJson = conditionsJson,
            actionsJson = actionsJson,
            stateJson = stateJson,
            createdAt = createdAt,
            updatedAt = updatedAt
    )
  }

  private fun libraryToMap(entry: MacroLibraryEntry): Map<String, Any?> {
    return mapOf(
            "id" to entry.id,
            "macroId" to entry.macroId,
            "title" to entry.title,
            "macroKind" to entry.macroKind,
            "category" to entry.category,
            "tagsJson" to entry.tagsJson,
            "payloadJson" to entry.payloadJson,
            "isSystem" to entry.isSystem,
            "usageCount" to entry.usageCount,
            "createdAt" to entry.createdAt
    )
  }

  private fun mapToLibraryEntry(args: Map<*, *>): MacroLibraryEntry {
    val now = System.currentTimeMillis()
    val id =
            (args["id"]?.toString()?.takeIf { it.isNotBlank() })
                    ?: UUID.randomUUID().toString()
    val macroId = args["macroId"]?.toString() ?: ""
    val titleArg = args["title"]?.toString() ?: ""
    val macroKind = args["macroKind"]?.toString() ?: "simple"
    val category = args["category"]?.toString() ?: "general"
    val tagsJson = args["tagsJson"]?.toString() ?: "[]"
    val payloadJson = args["payloadJson"]?.toString() ?: "{}"
    val title = if (titleArg.isNotBlank()) titleArg else extractPayloadTitle(payloadJson)
    val isSystem = args["isSystem"] as? Boolean ?: false
    val usageCount = (args["usageCount"] as? Number)?.toInt() ?: 0
    val createdAt = (args["createdAt"] as? Number)?.toLong() ?: now
    return MacroLibraryEntry(
            id = id,
            macroId = macroId,
            title = title,
            macroKind = macroKind,
            category = category,
            tagsJson = tagsJson,
            payloadJson = payloadJson,
            isSystem = isSystem,
            usageCount = usageCount,
            createdAt = createdAt
    )
  }

  private fun extractPayloadTitle(payloadJson: String): String {
    return try {
      val obj = org.json.JSONObject(payloadJson)
      obj.optString("name", "")
    } catch (_: Exception) {
      ""
    }
  }

  private fun createMacroFromLibraryPayload(args: Map<*, *>): Map<String, Any?> {
    val payloadJson = args["payloadJson"]?.toString() ?: return emptyMap()
    val macroKind = args["macroKind"]?.toString() ?: "simple"
    return try {
      val obj = org.json.JSONObject(payloadJson)
      val map = jsonObjectToMap(obj)
      when (macroKind) {
        "habit" -> {
          val entity = mapToHabitMacro(map)
          database.habitMacroDao().insert(entity)
          habitToMap(entity)
        }
        "discipline" -> {
          val entity = mapToDisciplineMacro(map)
          database.disciplineMacroDao().insert(entity)
          disciplineToMap(entity)
        }
        else -> {
          val entity = mapToMacro(map)
          database.macroDao().insert(entity)
          macroToMap(entity)
        }
      }
    } catch (_: Exception) {
      emptyMap()
    }
  }

  private fun isValidMacroMap(map: Map<*, *>): Boolean {
    val name = map["name"]?.toString()?.trim() ?: ""
    if (name.isEmpty()) return false
    val macroType = map["macroType"]?.toString() ?: "CUSTOM"
    return macroType.isNotBlank()
  }

  private fun isValidStructuredMacroMap(map: Map<*, *>): Boolean {
    val name = map["name"]?.toString()?.trim() ?: ""
    if (name.isEmpty()) return false
    val triggers = map["triggersJson"]?.toString() ?: "[]"
    val conditions = map["conditionsJson"]?.toString() ?: "[]"
    val actions = map["actionsJson"]?.toString() ?: "[]"
    if (!isJsonArray(triggers) || !isJsonArray(conditions) || !isJsonArray(actions)) {
      return false
    }
    if (!validateNodeList(triggers, kTriggerTypes)) return false
    if (!validateNodeList(conditions, kConditionTypes)) return false
    if (!validateNodeList(actions, kActionTypes)) return false
    return true
  }

  private fun isValidLibraryEntry(map: Map<*, *>): Boolean {
    val category = map["category"]?.toString() ?: "general"
    val macroKind = map["macroKind"]?.toString() ?: "simple"
    val payloadJson = map["payloadJson"]?.toString() ?: "{}"
    if (category.isBlank()) return false
    if (macroKind !in listOf("simple", "habit", "discipline")) return false
    return isJsonObject(payloadJson)
  }

  private fun isJsonArray(value: String): Boolean {
    return try {
      val arr = org.json.JSONArray(value)
      arr.length() >= 0
    } catch (_: Exception) {
      false
    }
  }

  private fun isJsonObject(value: String): Boolean {
    return try {
      val obj = org.json.JSONObject(value)
      obj.length() >= 0
    } catch (_: Exception) {
      false
    }
  }

  private fun validateNodeList(raw: String, allowed: Set<String>): Boolean {
    return try {
      val arr = org.json.JSONArray(raw)
      for (i in 0 until arr.length()) {
        val obj = arr.optJSONObject(i) ?: return false
        val type = obj.optString("type", "").trim()
        if (type.isEmpty() || !allowed.contains(type)) return false
        val required = kRequiredParams[type]
        if (!required.isNullOrEmpty()) {
          val params = obj.optJSONObject("params") ?: return false
          for (key in required) {
            if (!params.has(key) || params.isNull(key)) return false
          }
        }
      }
      true
    } catch (_: Exception) {
      false
    }
  }

  private fun mapToMacro(args: Map<*, *>, existing: MacroEntity? = null): MacroEntity {
    val now = System.currentTimeMillis()
    val id =
            (args["id"]?.toString()?.takeIf { it.isNotBlank() })
                    ?: existing?.id
                    ?: UUID.randomUUID().toString()
    val name = args["name"]?.toString() ?: existing?.name ?: "Macro"
    val description = args["description"]?.toString() ?: existing?.description ?: ""
    val isActive = (args["isActive"] as? Boolean) ?: existing?.isActive ?: true
    val macroType = args["macroType"]?.toString() ?: existing?.macroType ?: "CUSTOM"
    val actionType = args["actionType"]?.toString() ?: existing?.actionType ?: "limit"
    val packageName = args["packageName"]?.toString() ?: existing?.packageName
    val appName = args["appName"]?.toString() ?: existing?.appName
    val minutes =
            when (val v = args["minutes"]) {
              is Number -> v.toInt()
              else -> v?.toString()?.toIntOrNull()
            } ?: existing?.minutes ?: 30
    val createdAt =
            (args["createdAt"] as? Number)?.toLong() ?: existing?.createdAt ?: now
    val updatedAt =
            (args["updatedAt"] as? Number)?.toLong() ?: now
    return MacroEntity(
            id = id,
            name = name,
            description = description,
            isActive = isActive,
            macroType = macroType,
            actionType = actionType,
            packageName = packageName,
            appName = appName,
            minutes = minutes,
            createdAt = createdAt,
            updatedAt = updatedAt
    )
  }

  companion object {
    private const val REQUEST_ENABLE_ADMIN = 1001
  }

  private val kTriggerTypes =
          setOf(
                  "multi_trigger",
                  "time_of_day",
                  "day_of_week",
                  "app_opened",
                  "screen_time_checkpoint",
                  "usage_exceeded",
                  "usage_below",
                  "battery_level",
                  "device_inactive",
                  "manual"
          )

  private val kConditionTypes =
          setOf(
                  "multi_condition",
                  "time_range",
                  "usage_daily",
                  "today_screen_time",
                  "usage_below",
                  "streak",
                  "consecutive_failures",
                  "battery_level",
                  "is_charging",
                  "is_weekend"
          )

  private val kActionTypes =
          setOf(
                  "block_apps",
                  "unblock_apps",
                  "extend_limit",
                  "reduce_block",
                  "grant_reward",
                  "unlock_window",
                  "run_macro",
                  "send_notification",
                  "update_state"
          )

  private val kRequiredParams =
          mapOf(
                  "time_of_day" to listOf("hour"),
                  "day_of_week" to listOf("days"),
                  "app_opened" to listOf("packageName"),
                  "screen_time_checkpoint" to listOf("packageName", "minutes"),
                  "usage_exceeded" to listOf("packageName", "minutes"),
                  "usage_below" to listOf("packageName", "minutes"),
                  "battery_level" to listOf("percent"),
                  "device_inactive" to listOf("minutes"),
                  "time_range" to listOf("startHour", "endHour"),
                  "usage_daily" to listOf("packageName", "minutes"),
                  "today_screen_time" to listOf("packageName", "minutes"),
                  "streak" to listOf("count"),
                  "consecutive_failures" to listOf("count"),
                  "block_apps" to listOf("packageName"),
                  "unblock_apps" to listOf("packageName"),
                  "extend_limit" to listOf("packageName", "minutes"),
                  "reduce_block" to listOf("packageName", "minutes"),
                  "grant_reward" to listOf("packageName", "baseMinutes"),
                  "unlock_window" to listOf("packageName", "baseMinutes"),
                  "run_macro" to listOf("macroId"),
                  "send_notification" to listOf("message"),
                  "update_state" to listOf("key")
          )

  private fun mapNetworkErrorMessage(error: Throwable, fallback: String): String {
    val root = rootCause(error)
    return when (root) {
      is UnknownHostException, is ConnectException ->
              "Sin conexión a internet. Revisa tu red e intenta de nuevo."
      is SocketTimeoutException ->
              "La conexión tardó demasiado. Verifica tu internet e intenta otra vez."
      is SSLException -> "No se pudo establecer una conexión segura."
      else -> fallback
    }
  }

  private fun rootCause(error: Throwable): Throwable {
    var current = error
    while (current.cause != null && current.cause !== current) {
      current = current.cause!!
    }
    return current
  }
}









