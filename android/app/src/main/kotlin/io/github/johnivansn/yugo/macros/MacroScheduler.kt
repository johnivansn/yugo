package io.github.johnivansn.yugo.macros

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.github.johnivansn.yugo.receivers.MacroTickReceiver

object MacroScheduler {
  private const val INTERVAL_MINUTES = 15L

  fun schedule(context: Context) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val intent = Intent(context, MacroTickReceiver::class.java)
    val flags =
      PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    val pending = PendingIntent.getBroadcast(context, 0, intent, flags)

    val triggerAt = System.currentTimeMillis() + INTERVAL_MINUTES * 60_000L
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending)
    } else {
      alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
    }
  }
}







