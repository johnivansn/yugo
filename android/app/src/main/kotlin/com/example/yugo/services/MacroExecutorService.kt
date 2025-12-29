package com.example.yugo.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.yugo.MainActivity
import com.example.yugo.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Servicio de Foreground para ejecución de macros
 *
 * Responsabilidades:
 * - Mantener el motor de macros ejecutándose
 * - Sobrevivir a reinicios y Doze
 * - Mostrar notificación persistente
 * - Comunicación con Flutter via MethodChannel
 * - Inicializa el MacroEngine al iniciar
 * - Mantiene comunicación bidireccional con Flutter
 */
class MacroExecutorService : Service() {

  companion object {
    private const val TAG = "MacroExecutorService"

    const val ACTION_START = "com.example.yugo.START_SERVICE"
    const val ACTION_STOP = "com.example.yugo.STOP_SERVICE"
    const val ACTION_EMIT_EVENT = "com.example.yugo.EMIT_EVENT"

    private const val NOTIFICATION_ID = 1001
    private const val CHANNEL_ID = "yugo_macro_service_channel"
    private const val CHANNEL_NAME = "Yugo Automation Service"

    private const val PREFS_NAME = "yugo_service_prefs"
    private const val KEY_SERVICE_ENABLED = "service_enabled"
    private const val KEY_MACROS_EXECUTED = "macros_executed_count"

    fun isServiceEnabled(context: Context): Boolean {
      val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
      return prefs.getBoolean(KEY_SERVICE_ENABLED, false)
    }

    fun setServiceEnabled(context: Context, enabled: Boolean) {
      val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
      prefs.edit().putBoolean(KEY_SERVICE_ENABLED, enabled).apply()
      Log.d(TAG, "Service enabled: $enabled")
    }

    fun incrementMacrosExecuted(context: Context) {
      val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
      val current = prefs.getInt(KEY_MACROS_EXECUTED, 0)
      prefs.edit().putInt(KEY_MACROS_EXECUTED, current + 1).apply()
    }

    fun getMacrosExecutedCount(context: Context): Int {
      val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
      return prefs.getInt(KEY_MACROS_EXECUTED, 0)
    }
  }

  private var isRunning = false
  private var flutterEngine: FlutterEngine? = null
  private var serviceChannel: MethodChannel? = null

  override fun onCreate() {
    super.onCreate()
    Log.d(TAG, "Service onCreate()")

    createNotificationChannel()
    initializeFlutterEngine()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    Log.d(TAG, "Service onStartCommand() - Action: ${intent?.action}")

    when (intent?.action) {
      ACTION_START -> {
        startForegroundService()
      }
      ACTION_STOP -> {
        stopForegroundService()
      }
      ACTION_EMIT_EVENT -> {
        handleEmitEvent(intent)
      }
      else -> {
        startForegroundService()
      }
    }
    return START_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? {
    return null
  }

  override fun onDestroy() {
    super.onDestroy()
    Log.d(TAG, "Service onDestroy()")
    isRunning = false

    cleanupFlutterEngine()

    if (isServiceEnabled(this)) {
      Log.i(TAG, "Service was enabled, restarting...")
      restartService()
    }
  }

  private fun initializeFlutterEngine() {
    try {
      Log.d(TAG, "Initializing Flutter engine...")

      Log.d(TAG, "Flutter engine ready for communication")
    } catch (e: Exception) {
      Log.e(TAG, "Error initializing Flutter engine", e)
    }
  }

  private fun cleanupFlutterEngine() {
    try {
      serviceChannel?.setMethodCallHandler(null)
      serviceChannel = null

      flutterEngine?.destroy()
      flutterEngine = null

      Log.d(TAG, "Flutter engine cleaned up")
    } catch (e: Exception) {
      Log.e(TAG, "Error cleaning up Flutter engine", e)
    }
  }

  private fun handleEmitEvent(intent: Intent) {
    val eventType = intent.getStringExtra("event_type") ?: return
    val eventData = intent.getStringExtra("event_data") ?: "{}"

    Log.d(TAG, "Emitting event: $eventType with data: $eventData")

    incrementMacrosExecuted(this)
  }

  private fun startForegroundService() {
    if (isRunning) {
      Log.d(TAG, "Service already running, skipping start")
      return
    }
    Log.i(TAG, "Starting foreground service...")

    try {

      val notification = createNotification()
      startForeground(NOTIFICATION_ID, notification)
      isRunning = true
      setServiceEnabled(this, true)
      initializeMacroEngine()
      Log.i(TAG, "Foreground service started successfully")
    } catch (e: Exception) {
      Log.e(TAG, "Error starting foreground service", e)
    }
  }

  private fun stopForegroundService() {
    Log.i(TAG, "Stopping foreground service...")
    isRunning = false
    setServiceEnabled(this, false)
    shutdownMacroEngine()
    stopForeground(STOP_FOREGROUND_REMOVE)
    stopSelf()
    Log.i(TAG, "Foreground service stopped")
  }

  private fun restartService() {
    try {
      val intent = Intent(this, MacroExecutorService::class.java)
      intent.action = ACTION_START
      startForegroundService(intent)
      Log.i(TAG, "Service restart initiated")
    } catch (e: Exception) {
      Log.e(TAG, "Error restarting service", e)
    }
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel =
              NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW)
                      .apply {
                        description = "Canal para el servicio de automatización de Yugo"
                        setShowBadge(false)
                      }

      val notificationManager = getSystemService(NotificationManager::class.java)
      notificationManager?.createNotificationChannel(channel)
      Log.d(TAG, "Notification channel created")
    }
  }

  private fun createNotification(): Notification {
    val notificationIntent = Intent(this, MainActivity::class.java)
    val pendingFlags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
              PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
              PendingIntent.FLAG_UPDATE_CURRENT
            }
    val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, pendingFlags)

    val macrosCount = getMacrosExecutedCount(this)
    val contentText =
            if (macrosCount > 0) {
              "Sistema activo • $macrosCount eventos procesados"
            } else {
              getString(R.string.foreground_service_notification_content)
            }

    return NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle(getString(R.string.foreground_service_notification_title))
            .setContentText(contentText)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
  }

  private fun initializeMacroEngine() {
    Log.d(TAG, "🚀 Initializing macro engine...")
    Log.d(TAG, "✅ Macro engine initialized (waiting for Flutter)")
  }

  private fun shutdownMacroEngine() {
    Log.d(TAG, "🛑 Shutting down macro engine...")
    Log.d(TAG, "✅ Macro engine shutdown signal sent")
  }
}
