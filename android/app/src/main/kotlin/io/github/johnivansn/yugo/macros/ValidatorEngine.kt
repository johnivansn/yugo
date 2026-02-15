package io.github.johnivansn.yugo.macros

import android.content.Context
import android.os.BatteryManager
import io.github.johnivansn.yugo.database.AppDatabase
import io.github.johnivansn.yugo.database.DailyUsage
import io.github.johnivansn.yugo.monitoring.UsageStatsMonitor
import java.util.Calendar
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

class ValidatorEngine(
        private val context: Context,
        private val db: AppDatabase
) {
  private data class Node(val type: String, val params: Map<String, Any?>)

  fun triggersMatch(
          triggersJson: String,
          day: Int,
          minutesNow: Int,
          stateJson: String
  ): Boolean {
    val triggers = parseNodes(triggersJson)
    if (triggers.isEmpty()) return false
    val prefs = context.getSharedPreferences("macro_engine", Context.MODE_PRIVATE)
    val lastApp = prefs.getString("last_app_opened", null)
    val lastAppAt = prefs.getLong("last_app_opened_at", 0L)
    val lastInteraction = prefs.getLong("last_interaction_at", 0L)
    val now = System.currentTimeMillis()
    val battery = getBatteryLevel()
    val charging = isCharging()
    val state = parseState(stateJson)
    val manualAt = state.optLong("manualTriggerAt", 0L)
    fun eval(node: Node, depth: Int = 0): Boolean {
      if (depth > 3) return false
      return when (node.type) {
        "time_of_day" -> {
          val hour = (node.params["hour"] as? Number)?.toInt() ?: return false
          val minute = (node.params["minute"] as? Number)?.toInt() ?: 0
          val target = hour * 60 + minute
          kotlin.math.abs(target - minutesNow) <= 15
        }
        "day_of_week" -> {
          val days = (node.params["days"] as? List<*>)?.mapNotNull {
            (it as? Number)?.toInt() ?: it?.toString()?.toIntOrNull()
          } ?: return false
          days.contains(day)
        }
        "app_opened" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          lastApp == pkg && (now - lastAppAt) <= 15 * 60_000L
        }
        "screen_time_checkpoint" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val interval = (node.params["minutes"] as? Number)?.toInt() ?: 0
          if (interval <= 0) return false
          val usageMinutes = getUsageMinutesToday(pkg)
          if (usageMinutes <= 0) return false
          usageMinutes % interval <= 1
        }
        "usage_exceeded" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(pkg)
          usageMinutes >= limit
        }
        "usage_below" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(pkg)
          usageMinutes <= limit
        }
        "battery_level" -> {
          val percent = (node.params["percent"] as? Number)?.toInt() ?: return false
          val direction = node.params["direction"]?.toString() ?: "at_or_below"
          val level = battery ?: 100
          if (direction == "at_or_above") level >= percent else level <= percent
        }
        "is_charging" -> charging
        "device_inactive" -> {
          val minutes = (node.params["minutes"] as? Number)?.toInt() ?: 0
          if (minutes <= 0) return false
          now - lastInteraction >= minutes * 60_000L
        }
        "manual" -> {
          manualAt > 0 && (now - manualAt) <= 15 * 60_000L
        }
        "multi_trigger" -> {
          val op = node.params["operator"]?.toString()?.uppercase() ?: "OR"
          val items = parseTriggerItems(node.params["items"])
          if (items.isEmpty()) return false
          if (op == "AND") items.all { eval(it, depth + 1) } else items.any { eval(it, depth + 1) }
        }
        else -> false
      }
    }
    return triggers.any { eval(it) }
  }

  suspend fun conditionsMatch(
          conditionsJson: String,
          date: String,
          day: Int,
          minutesNow: Int,
          stateJson: String
  ): Boolean {
    val conditions = parseNodes(conditionsJson)
    if (conditions.isEmpty()) return true
    val battery = getBatteryLevel()
    val charging = isCharging()
    val state = parseState(stateJson)
    suspend fun eval(node: Node, depth: Int = 0): Boolean {
      if (depth > 3) return false
      return when (node.type) {
        "time_range" -> {
          val start = ((node.params["startHour"] as? Number)?.toInt() ?: 0) * 60 +
            ((node.params["startMinute"] as? Number)?.toInt() ?: 0)
          val end = ((node.params["endHour"] as? Number)?.toInt() ?: 0) * 60 +
            ((node.params["endMinute"] as? Number)?.toInt() ?: 0)
          if (start <= end) {
            minutesNow in start..end
          } else {
            minutesNow >= start || minutesNow <= end
          }
        }
        "usage_daily" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usage = ensureUsageRecord(pkg, date)
          (usage?.usedMinutes ?: 0) >= limit
        }
        "usage_below" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(pkg)
          usageMinutes <= limit
        }
        "today_screen_time" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(pkg)
          usageMinutes >= limit
        }
        "streak" -> {
          val required = (node.params["count"] as? Number)?.toInt() ?: return false
          val streak = state.optInt("currentStreak", 0)
          streak >= required
        }
        "consecutive_failures" -> {
          val required = (node.params["count"] as? Number)?.toInt() ?: return false
          val failures = state.optInt("consecutiveFailures", 0)
          failures >= required
        }
        "battery_level" -> {
          val limit = (node.params["percent"] as? Number)?.toInt() ?: return false
          val direction = node.params["direction"]?.toString() ?: "at_or_below"
          val level = battery ?: 100
          if (direction == "at_or_above") level >= limit else level <= limit
        }
        "is_charging" -> charging
        "is_weekend" -> day == Calendar.SATURDAY || day == Calendar.SUNDAY
        "multi_condition" -> {
          val op = node.params["operator"]?.toString()?.uppercase() ?: "OR"
          val items = parseTriggerItems(node.params["items"])
          if (items.isEmpty()) return false
          if (op == "AND") {
            for (item in items) {
              if (!eval(item, depth + 1)) return false
            }
            true
          } else {
            for (item in items) {
              if (eval(item, depth + 1)) return true
            }
            false
          }
        }
        else -> true
      }
    }
    for (condition in conditions) {
      if (!eval(condition)) return false
    }
    return true
  }

  private fun parseNodes(raw: String?): List<Node> {
    if (raw.isNullOrBlank()) return emptyList()
    return try {
      val arr = JSONArray(raw)
      (0 until arr.length()).mapNotNull { i ->
        val obj = arr.optJSONObject(i) ?: return@mapNotNull null
        val type = obj.optString("type", "custom")
        val paramsObj = obj.optJSONObject("params") ?: JSONObject()
        Node(type, jsonToMap(paramsObj))
      }
    } catch (_: Exception) {
      emptyList()
    }
  }

  private fun parseTriggerItems(raw: Any?): List<Node> {
    return when (raw) {
      is JSONArray -> {
        (0 until raw.length()).mapNotNull { i ->
          val obj = raw.optJSONObject(i)
          if (obj != null) {
            val type = obj.optString("type", "custom")
            val paramsObj = obj.optJSONObject("params") ?: JSONObject()
            Node(type, jsonToMap(paramsObj))
          } else {
            val map = raw.opt(i) as? Map<*, *> ?: return@mapNotNull null
            val type = map["type"]?.toString() ?: "custom"
            val params = mapToParams(map["params"])
            Node(type, params)
          }
        }
      }
      is List<*> -> {
        raw.mapNotNull { item ->
          when (item) {
            is JSONObject -> {
              val type = item.optString("type", "custom")
              val paramsObj = item.optJSONObject("params") ?: JSONObject()
              Node(type, jsonToMap(paramsObj))
            }
            is Map<*, *> -> {
              val type = item["type"]?.toString() ?: "custom"
              val params = mapToParams(item["params"])
              Node(type, params)
            }
            else -> null
          }
        }
      }
      else -> emptyList()
    }
  }

  private fun mapToParams(raw: Any?): Map<String, Any?> {
    return when (raw) {
      is JSONObject -> jsonToMap(raw)
      is Map<*, *> -> raw.entries.associate { it.key.toString() to it.value }
      else -> emptyMap()
    }
  }

  private fun jsonToMap(obj: JSONObject): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    val it = obj.keys()
    while (it.hasNext()) {
      val key = it.next()
      map[key] = obj.opt(key)
    }
    return map
  }

  private fun parseState(raw: String): JSONObject {
    return try {
      if (raw.isBlank()) JSONObject() else JSONObject(raw)
    } catch (_: Exception) {
      JSONObject()
    }
  }

  private suspend fun ensureUsageRecord(packageName: String, date: String): DailyUsage? {
    return try {
      val usageMillis = UsageStatsMonitor(context).getUsageToday(packageName)
      val minutes = (usageMillis / 60000).toInt()
      val existing = db.dailyUsageDao().getUsage(packageName, date)
      val now = System.currentTimeMillis()
      val record =
              existing?.copy(usedMinutes = minutes, lastUpdated = now)
                      ?: DailyUsage(
                              id = UUID.randomUUID().toString(),
                              packageName = packageName,
                              date = date,
                              usedMinutes = minutes,
                              isBlocked = false,
                              lastUpdated = now
                      )
      if (existing == null) {
        db.dailyUsageDao().insert(record)
      } else {
        db.dailyUsageDao().update(record)
      }
      record
    } catch (_: Exception) {
      db.dailyUsageDao().getUsage(packageName, date)
    }
  }

  private fun getUsageMinutesToday(packageName: String): Int {
    return try {
      val usageMillis = UsageStatsMonitor(context).getUsageToday(packageName)
      (usageMillis / 60000).toInt()
    } catch (_: Exception) {
      0
    }
  }

  private fun getBatteryLevel(): Int? {
    return try {
      val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
      val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
      if (level in 0..100) level else null
    } catch (_: Exception) {
      null
    }
  }

  private fun isCharging(): Boolean {
    return try {
      val intent =
        context.registerReceiver(
          null,
          android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED)
        )
      val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
      status == BatteryManager.BATTERY_STATUS_CHARGING ||
        status == BatteryManager.BATTERY_STATUS_FULL
    } catch (_: Exception) {
      false
    }
  }
}







