package com.example.yugo.channels

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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

                "isBatteryOptimizationDisabled" -> {
                    val isDisabled = isBatteryOptimizationDisabled()
                    result.success(isDisabled)
                }

                "requestDisableBatteryOptimization" -> {
                    requestDisableBatteryOptimization()
                    result.success(true)
                }

                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
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

    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = context.packageName
            val isIgnoring = powerManager.isIgnoringBatteryOptimizations(packageName)

            Log.d(TAG, "Battery optimization disabled: $isIgnoring")
            return isIgnoring
        }
        return true
    }

    private fun requestDisableBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:${context.packageName}")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)

                Log.i(TAG, "Opened battery optimization dialog")
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting battery optimization disable", e)
                openBatteryOptimizationSettings()
            }
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)

            Log.i(TAG, "Opened battery optimization settings")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening battery optimization settings", e)
        }
    }
}
