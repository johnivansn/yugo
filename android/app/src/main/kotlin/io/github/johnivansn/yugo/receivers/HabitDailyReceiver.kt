package io.github.johnivansn.yugo.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.github.johnivansn.yugo.macros.HabitScheduler
import io.github.johnivansn.yugo.macros.MacroAutomationExecutor

class HabitDailyReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    val pending = goAsync()
    Thread {
      try {
        MacroAutomationExecutor.runDailyHabitValidation(context)
      } finally {
        HabitScheduler.schedule(context)
        pending.finish()
      }
    }.start()
  }
}







