package io.github.johnivansn.yugo.macros

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.github.johnivansn.yugo.receivers.HabitDailyReceiver
import java.util.Calendar

object HabitScheduler {
  fun schedule(context: Context) {
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    val intent = Intent(context, HabitDailyReceiver::class.java)
    val flags =
      PendingIntent.FLAG_UPDATE_CURRENT or
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
    val pending = PendingIntent.getBroadcast(context, 1, intent, flags)

    val next =
      Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 23)
        set(Calendar.MINUTE, 59)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
        if (timeInMillis <= System.currentTimeMillis()) {
          add(Calendar.DAY_OF_MONTH, 1)
        }
      }

    val triggerAt = next.timeInMillis
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        if (alarmManager.canScheduleExactAlarms()) {
          alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            pending
          )
        } else {
          alarmManager.setWindow(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            15 * 60 * 1000L,
            pending
          )
        }
      } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        alarmManager.setExactAndAllowWhileIdle(
          AlarmManager.RTC_WAKEUP,
          triggerAt,
          pending
        )
      } else {
        alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
      }
    } catch (_: SecurityException) {
      alarmManager.setWindow(
        AlarmManager.RTC_WAKEUP,
        triggerAt,
        15 * 60 * 1000L,
        pending
      )
    }
  }
}







