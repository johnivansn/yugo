package io.github.johnivansn.yugo.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.github.johnivansn.yugo.macros.MacroAutomationExecutor
import io.github.johnivansn.yugo.macros.MacroScheduler

class MacroTickReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val pending = goAsync()
    Thread {
      try {
        MacroAutomationExecutor.run(context)
      } finally {
        MacroScheduler.schedule(context)
        pending.finish()
      }
    }.start()
  }
}







