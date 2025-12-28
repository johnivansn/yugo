package com.example.yugo

import com.example.yugo.channels.MacroChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

  private var macroChannel: MethodChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    macroChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MacroChannel.CHANNEL_NAME)

    val handler = MacroChannel(applicationContext)
    macroChannel?.setMethodCallHandler(handler)
  }

  override fun onDestroy() {
    macroChannel?.setMethodCallHandler(null)
    super.onDestroy()
  }
}
