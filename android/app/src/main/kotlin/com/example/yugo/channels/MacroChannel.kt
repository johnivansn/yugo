package com.example.yugo.channels

import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.yugo.services.MacroExecutorService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MacroChannel(private val context: Context) : MethodChannel.MethodCallHandler {

  companion object {
    const val CHANNEL_NAME = "com.example.yugo/macro_service"
    private const val TAG = "MacroChannel"
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    Log.d(TAG, "Method called: ${call.method}")

    try {
      when (call.method) {
        "startService" -> {
          startService()
          result.success(true)
        }
        "stopService" -> {
          stopService()
          result.success(true)
        }
        "isServiceRunning" -> {
          val isRunning = MacroExecutorService.isServiceEnabled(context)
          result.success(isRunning)
        }
        else -> {
          result.notImplemented()
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Error handling method call", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun startService() {
    Log.i(TAG, "Starting MacroExecutorService from Flutter")

    val intent = Intent(context, MacroExecutorService::class.java)
    intent.action = MacroExecutorService.ACTION_START
    context.startForegroundService(intent)
  }

  private fun stopService() {
    Log.i(TAG, "Stopping MacroExecutorService from Flutter")

    val intent = Intent(context, MacroExecutorService::class.java)
    intent.action = MacroExecutorService.ACTION_STOP
    context.startService(intent)
  }
}
