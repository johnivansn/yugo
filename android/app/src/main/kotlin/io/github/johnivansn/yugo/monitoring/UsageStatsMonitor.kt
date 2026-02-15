package io.github.johnivansn.yugo.monitoring

import android.app.usage.UsageStatsManager
import android.content.Context
import android.util.Log
import io.github.johnivansn.yugo.database.AppDatabase
import io.github.johnivansn.yugo.database.DailyUsage
import io.github.johnivansn.yugo.database.getDailyQuotaForDay
import io.github.johnivansn.yugo.notifications.PillNotificationHelper
import io.github.johnivansn.yugo.rewards.EffectiveLimitCalculator
import io.github.johnivansn.yugo.utils.AppUtils
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.ceil
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class UsageStatsMonitor(private val context: Context) {
  private data class DateUpcomingCandidate(
          val key: String,
          val startMillis: Long,
          val notificationType: String,
          val label: String?,
          val appName: String,
          val packageName: String,
          val message: String
  )

  private val usageStatsManager =
          context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
  private val database = AppDatabase.getDatabase(context)
  private val limitCalculator = EffectiveLimitCalculator(database)
  private val dateFormat = AppUtils.newDateFormat()
  private val scope = CoroutineScope(Dispatchers.IO)
  private val pillNotification = PillNotificationHelper(context)

  private val notified50Percent = mutableSetOf<String>()
  private val notified75Percent = mutableSetOf<String>()
  private val notifiedLastMinute = mutableSetOf<String>()
  private val notifiedDateBlocks = mutableSetOf<String>()
  private val notifiedScheduleUpcoming = mutableSetOf<String>()
  private val notifiedDateUpcoming = mutableSetOf<String>()
  private val notifiedDateUpcomingGroups = mutableSetOf<String>()

  fun getUsageToday(packageName: String): Long {
    val calendar = Calendar.getInstance()
    calendar.set(Calendar.HOUR_OF_DAY, 0)
    calendar.set(Calendar.MINUTE, 0)
    calendar.set(Calendar.SECOND, 0)
    calendar.set(Calendar.MILLISECOND, 0)
    val startTime = calendar.timeInMillis
    val endTime = System.currentTimeMillis()

    val events = usageStatsManager.queryEvents(startTime, endTime)
    if (events == null) {
      Log.w(TAG, "queryEvents devolvió null - permiso denegado")
      return 0L
    }

    var appInForeground = false
    var lastForegroundTime = 0L
    var totalTime = 0L

    while (events.hasNextEvent()) {
      val event = android.app.usage.UsageEvents.Event()
      events.getNextEvent(event)

      if (event.packageName == packageName) {
        when (event.eventType) {
          android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED,
          android.app.usage.UsageEvents.Event.MOVE_TO_FOREGROUND -> {
            if (!appInForeground) {
              appInForeground = true
              lastForegroundTime = event.timeStamp
            }
          }
          android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED,
          android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED,
          android.app.usage.UsageEvents.Event.MOVE_TO_BACKGROUND -> {
            if (appInForeground) {
              val sessionTime = event.timeStamp - lastForegroundTime
              if (sessionTime > 0) {
                totalTime += sessionTime
              }
              appInForeground = false
            }
          }
        }
      }
    }

    if (appInForeground && lastForegroundTime > 0) {
      val currentSessionTime = endTime - lastForegroundTime
      if (currentSessionTime > 0) {
        totalTime += currentSessionTime
      }
    }

    Log.d(TAG, "$packageName: ${totalTime}ms total (${totalTime/60000} min)")
    return totalTime
  }

  fun updateAllUsage() {
    scope.launch {
      val blocks = database.appBlockDao().getEnabled()
      val today = dateFormat.format(Date())

      Log.d(TAG, "Actualizando uso para ${blocks.size} apps")
      val activeBlocks = mutableListOf<io.github.johnivansn.yugo.database.AppBlock>()

      for (block in blocks) {
        if (isExpired(block)) continue
        activeBlocks.add(block)
        val usageMillis = getUsageToday(block.packageName)
        val usageMinutes = (usageMillis / 60000).toInt()

        Log.d(
                TAG,
                "${block.packageName}: $usageMinutes min usados hoy (cuota: ${block.dailyQuotaMinutes} min)"
        )

        var dailyUsage = database.dailyUsageDao().getUsage(block.packageName, today)

        if (dailyUsage == null) {
          dailyUsage =
                  DailyUsage(
                          id = UUID.randomUUID().toString(),
                          packageName = block.packageName,
                          date = today,
                          usedMinutes = usageMinutes,
                          isBlocked = false,
                          lastUpdated = System.currentTimeMillis()
                  )
          database.dailyUsageDao().insert(dailyUsage)
          Log.d(TAG, "Creado nuevo registro de uso para ${block.packageName}")
        } else {
          dailyUsage =
                  dailyUsage.copy(
                          usedMinutes = usageMinutes,
                          lastUpdated = System.currentTimeMillis()
                  )
          database.dailyUsageDao().update(dailyUsage)
          Log.d(TAG, "Actualizado registro de uso para ${block.packageName}")
        }

        val quotaMinutes =
                if (block.limitType == "weekly") block.weeklyQuotaMinutes
                else block.getDailyQuotaForDay(Calendar.getInstance().get(Calendar.DAY_OF_WEEK))

        val now = System.currentTimeMillis()
        val effective = limitCalculator.calculateForblock(block, now, quotaMinutes)

        val usedForLimitMinutes =
                if (block.limitType == "weekly") {
                  val weekStart =
                          AppUtils.getWeekStartDate(
                                  block.weeklyResetDay,
                                  block.weeklyResetHour,
                                  block.weeklyResetMinute,
                                  dateFormat
                          )
                  val weekUsages =
                          database.dailyUsageDao()
                                  .getUsageSince(block.packageName, weekStart)
                  weekUsages.sumOf { it.usedMinutes }
                } else {
                  usageMinutes
                }

        if (effective.effectiveMinutes > 0) {
          val usedForLimitMillis =
                  if (block.limitType == "weekly") usedForLimitMinutes * 60000L
                  else usageMillis
          if (usedForLimitMillis < effective.effectiveMinutes * 60000L) {
            checkAndNotifyQuota(
                    block.packageName,
                    block.appName,
                    usedForLimitMillis,
                    effective.effectiveMinutes
            )
          }
        }

        checkAndNotifyDateBlock(block.packageName, block.appName, today)
        checkAndNotifyScheduleUpcoming(block.packageName, block.appName)

        val exceeded =
                if (block.limitType == "weekly") {
                  usedForLimitMinutes >= effective.effectiveMinutes
                } else {
                  usageMillis >= effective.effectiveMinutes * 60000L
                }

        if (!effective.hasUnlock && effective.effectiveMinutes > 0 && exceeded && !dailyUsage.isBlocked) {
          dailyUsage = dailyUsage.copy(isBlocked = true)
          database.dailyUsageDao().update(dailyUsage)
          pillNotification.notifyAppBlocked(
                  block.appName,
                  block.packageName,
                  PillNotificationHelper.BlockReason.QUOTA_EXCEEDED
          )
          Log.i(TAG, "${block.packageName} BLOQUEADA - cuota alcanzada")

          sendBlockSignal(block.packageName)
        }
      }
      checkAndNotifyDateBlockUpcomingForAll(activeBlocks)
    }
  }

  private fun sendBlockSignal(packageName: String) {
    try {
      val intent = android.content.Intent("io.github.johnivansn.yugo.BLOCK_APP")
      intent.putExtra("packageName", packageName)
      intent.setPackage("io.github.johnivansn.yugo")
      context.sendBroadcast(intent)
      Log.i(TAG, "Señal de bloqueo enviada para $packageName")
    } catch (e: Exception) {
      Log.e(TAG, "Error enviando señal de bloqueo", e)
    }
  }

  private fun checkAndNotifyQuota(
          packageName: String,
          appName: String,
          usedMillis: Long,
          quotaMinutes: Int
  ) {
    val quotaMillis = quotaMinutes * 60000L
    val remainingMillis = quotaMillis - usedMillis
    val remainingMinutes = ceil(remainingMillis / 60000.0).toInt()

    when {
      remainingMinutes == 1 && !notifiedLastMinute.contains(packageName) -> {
        pillNotification.notifyLastMinute(appName, packageName)
        notifiedLastMinute.add(packageName)
        Log.i(TAG, "Notificado último minuto para $packageName")
      }
      usedMillis >= (quotaMillis * 0.75).toLong() &&
              remainingMinutes > 1 &&
              !notified75Percent.contains(packageName) -> {
        pillNotification.notifyQuota75(appName, packageName, remainingMinutes)
        notified75Percent.add(packageName)
        Log.i(TAG, "Notificado 75% para $packageName")
      }
      usedMillis >= (quotaMillis * 0.5).toLong() &&
              usedMillis < (quotaMillis * 0.75).toLong() &&
              !notified50Percent.contains(packageName) -> {
        pillNotification.notifyQuota50(appName, packageName, remainingMinutes)
        notified50Percent.add(packageName)
        Log.i(TAG, "Notificado 50% para $packageName")
      }
    }
  }

  fun resetNotificationFlags() {
    notified50Percent.clear()
    notified75Percent.clear()
    notifiedLastMinute.clear()
    notifiedDateBlocks.clear()
    notifiedScheduleUpcoming.clear()
    notifiedDateUpcoming.clear()
    notifiedDateUpcomingGroups.clear()
    Log.i(TAG, "Flags de notificación reseteadas")
  }

  private suspend fun checkAndNotifyDateBlock(
          packageName: String,
          appName: String,
          today: String
  ) {
    val now = System.currentTimeMillis()
    val keyPrefix = "$packageName|$today|"
    val activeBlocks =
            database.dateBlockDao().getEnabledByPackage(packageName).filter { block ->
              val startMillis =
                      toDateTimeMillis(block.startDate, block.startHour, block.startMinute)
              val endMillis = toDateTimeMillis(block.endDate, block.endHour, block.endMinute)
              if (startMillis == null || endMillis == null) return@filter false
              now in startMillis..endMillis
            }
    if (activeBlocks.isEmpty()) return

    val minDaysRemaining =
            activeBlocks
                    .mapNotNull { block ->
                      val endMillis =
                              toDateTimeMillis(block.endDate, block.endHour, block.endMinute)
                                      ?: return@mapNotNull null
                      val diffMillis = endMillis - now
                      val days = (diffMillis / 86400000L).toInt().coerceAtLeast(0)
                      endMillis to days
                    }
                    .minByOrNull { it.second }
                    ?: return

    val key = keyPrefix + minDaysRemaining.first
    if (notifiedDateBlocks.contains(key)) return

    pillNotification.notifyDateBlockRemaining(appName, packageName, minDaysRemaining.second)
    notifiedDateBlocks.add(key)
    Log.i(TAG, "Notificado bloqueo por fechas para $packageName (${minDaysRemaining.second} días)")
  }

  private suspend fun computeDateBlockUpcomingCandidate(
          packageName: String,
          appName: String
  ): DateUpcomingCandidate? {
    val blocks = database.dateBlockDao().getEnabledByPackage(packageName)
    if (blocks.isEmpty()) return null

    val now = System.currentTimeMillis()
    var bestStartMillis: Long? = null
    var bestBlock: io.github.johnivansn.yugo.database.DateBlock? = null

    for (block in blocks) {
      val startMillis = toDateTimeMillis(block.startDate, block.startHour, block.startMinute) ?: continue
      if (startMillis < now) continue
      if (bestStartMillis == null || startMillis < bestStartMillis) {
        bestStartMillis = startMillis
        bestBlock = block
      }
    }

    val nextStart = bestStartMillis ?: return null
    val block = bestBlock ?: return null
    val minutesUntil = ceil((nextStart - now) / 60000.0).toInt()
    val startCal = Calendar.getInstance().apply { timeInMillis = nextStart }
    val nowCal = Calendar.getInstance()
    val startsTomorrow =
            startCal.get(Calendar.YEAR) == nowCal.get(Calendar.YEAR) &&
                    startCal.get(Calendar.DAY_OF_YEAR) == nowCal.get(Calendar.DAY_OF_YEAR) + 1

    val notificationType: String
    val message: String
    val startLabel = String.format("%02d:%02d", block.startHour, block.startMinute)
    val endLabel = String.format("%02d:%02d", block.endHour, block.endMinute)
    when {
      minutesUntil == 5 -> {
        notificationType = "soon"
        message = "En 5 min se activa Bloqueo ($startLabel a $endLabel)"
      }
      startsTomorrow && minutesUntil in 1435..1445 -> {
        notificationType = "tomorrow"
        message = "Mañana se activa Bloqueo ($startLabel a $endLabel)"
      }
      else -> return null
    }

    val key = "${block.id}|$nextStart|$notificationType"
    return DateUpcomingCandidate(
            key = key,
            startMillis = nextStart,
            notificationType = notificationType,
            label = block.label?.trim()?.takeIf { it.isNotEmpty() },
            appName = appName,
            packageName = packageName,
            message = message
    )
  }

  private suspend fun checkAndNotifyDateBlockUpcomingForAll(
          blocks: List<io.github.johnivansn.yugo.database.AppBlock>
  ) {
    if (blocks.isEmpty()) return
    val candidates =
            blocks.mapNotNull { computeDateBlockUpcomingCandidate(it.packageName, it.appName) }
    if (candidates.isEmpty()) return

    val groupedByLabel =
            candidates
                    .filter { it.label != null }
                    .groupBy {
                      "${it.label}|${it.notificationType}|${it.startMillis}|${it.message}"
                    }

    val consumedKeys = mutableSetOf<String>()

    groupedByLabel.forEach { (groupKey, group) ->
      if (group.size < 2) return@forEach
      if (notifiedDateUpcomingGroups.contains(groupKey)) return@forEach
      val first = group.first()
      val label = first.label ?: return@forEach
      val appNames = group.map { it.appName }
      pillNotification.notifyDateBlockUpcomingGrouped(
              label = label,
              message = first.message,
              appNames = appNames
      )
      notifiedDateUpcomingGroups.add(groupKey)
      group.forEach {
        notifiedDateUpcoming.add(it.key)
        consumedKeys.add(it.key)
      }
      Log.i(TAG, "Notificación agrupada por etiqueta '$label' (${group.size} apps)")
    }

    candidates.forEach { candidate ->
      if (consumedKeys.contains(candidate.key)) return@forEach
      if (notifiedDateUpcoming.contains(candidate.key)) return@forEach
      pillNotification.notifyDateBlockUpcoming(
              appName = candidate.appName,
              packageName = candidate.packageName,
              message = candidate.message
      )
      notifiedDateUpcoming.add(candidate.key)
      Log.i(
              TAG,
              "Notificado bloqueo por fecha próximo para ${candidate.packageName} [${candidate.notificationType}]"
      )
    }
  }

  private fun isExpired(block: io.github.johnivansn.yugo.database.AppBlock): Boolean {
    val expiresAt = block.expiresAt ?: return false
    if (expiresAt <= 0) return false
    return System.currentTimeMillis() > expiresAt
  }

  private fun toDateTimeMillis(dateValue: String, hour: Int, minute: Int): Long? {
    val date = dateFormat.parse(dateValue) ?: return null
    val cal = Calendar.getInstance().apply {
      time = date
      set(Calendar.HOUR_OF_DAY, hour)
      set(Calendar.MINUTE, minute)
      set(Calendar.SECOND, 0)
      set(Calendar.MILLISECOND, 0)
    }
    return cal.timeInMillis
  }

  private suspend fun checkAndNotifyScheduleUpcoming(
          packageName: String,
          appName: String
  ) {
    val schedules = database.appScheduleDao().getByPackage(packageName)
    if (schedules.isEmpty()) return

    val now = Calendar.getInstance()
    var best: Calendar? = null
    var bestSchedule: io.github.johnivansn.yugo.database.AppSchedule? = null

    for (schedule in schedules) {
      if (!schedule.isEnabled) continue
      for (offset in 0..7) {
        val candidate = (now.clone() as Calendar).apply {
          add(Calendar.DAY_OF_MONTH, offset)
          set(Calendar.HOUR_OF_DAY, schedule.startHour)
          set(Calendar.MINUTE, schedule.startMinute)
          set(Calendar.SECOND, 0)
          set(Calendar.MILLISECOND, 0)
        }
        val dayBit = 1 shl (candidate.get(Calendar.DAY_OF_WEEK) - 1)
        if ((schedule.daysOfWeek and dayBit) == 0) continue
        if (candidate.before(now)) continue
        if (best == null || candidate.before(best)) {
          best = candidate
          bestSchedule = schedule
        }
        break
      }
    }

    val next = best ?: return
    val nextSchedule = bestSchedule ?: return
    val diffMillis = next.timeInMillis - now.timeInMillis
    val minutesUntil = ceil(diffMillis / 60000.0).toInt()
    if (minutesUntil != 5) return

    val dayKey = dateFormat.format(next.time)
    val key = "$packageName|$dayKey|${next.get(Calendar.HOUR_OF_DAY)}:${next.get(Calendar.MINUTE)}"
    if (notifiedScheduleUpcoming.contains(key)) return

    val startLabel = String.format("%02d:%02d", nextSchedule.startHour, nextSchedule.startMinute)
    val endLabel = String.format("%02d:%02d", nextSchedule.endHour, nextSchedule.endMinute)
    pillNotification.notifyScheduleUpcoming(
            appName = appName,
            packageName = packageName,
            minutes = minutesUntil,
            startLabel = startLabel,
            endLabel = endLabel
    )
    notifiedScheduleUpcoming.add(key)
    Log.i(TAG, "Notificado horario próximo para $packageName ($minutesUntil min)")
  }

  companion object {
    private const val TAG = "UsageStatsMonitor"
  }
}








