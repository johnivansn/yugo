package com.example.yugo.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.yugo.services.MacroExecutorService

/**
 * Boot Receiver - Reinicia el servicio tras boot del dispositivo
 *
 * Escucha:
 * - BOOT_COMPLETED: Reinicio normal
 * - QUICKBOOT_POWERON: Reinicio rápido (algunos dispositivos)
 * - MY_PACKAGE_REPLACED: App actualizada
 */
class BootReceiver : BroadcastReceiver() {

  companion object {
    private const val TAG = "YugoBootReceiver"
  }

  override fun onReceive(context: Context, intent: Intent) {
    Log.d(TAG, "Received intent: ${intent.action}")

    when (intent.action) {
      Intent.ACTION_BOOT_COMPLETED -> {
        Log.i(TAG, "Device boot completed, restarting service...")
        startMacroExecutorService(context)
      }
      "android.intent.action.QUICKBOOT_POWERON" -> {
        Log.i(TAG, "Quick boot completed, restarting service...")
        startMacroExecutorService(context)
      }
      Intent.ACTION_MY_PACKAGE_REPLACED -> {
        Log.i(TAG, "App updated, restarting service...")
        startMacroExecutorService(context)
      }
      else -> {
        Log.w(TAG, "Unknown action received: ${intent.action}")
      }
    }
  }

  private fun startMacroExecutorService(context: Context) {
    try {
      val serviceIntent = Intent(context, MacroExecutorService::class.java)
      serviceIntent.action = MacroExecutorService.ACTION_START

      context.startForegroundService(serviceIntent)

      Log.i(TAG, "MacroExecutorService started successfully")
    } catch (e: Exception) {
      Log.e(TAG, "Error starting MacroExecutorService", e)
    }
  }
}
