package io.github.johnivansn.yugo.macros

import android.content.Context
import android.os.BatteryManager
import android.util.Log
import io.github.johnivansn.yugo.database.AppDatabase
import io.github.johnivansn.yugo.database.AppBlock
import io.github.johnivansn.yugo.database.DailyUsage
import io.github.johnivansn.yugo.database.RewardActionEntity
import io.github.johnivansn.yugo.monitoring.UsageStatsMonitor
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject

object MacroAutomationExecutor {
  private const val TIME_WINDOW_MINUTES = 15

  fun run(context: Context) {
    runBlocking(Dispatchers.IO) {
      try {
        val db = AppDatabase.getDatabase(context)
        db.rewardActionDao().deactivateExpired(System.currentTimeMillis())
        runDisciplineMacros(db, context)
        runHabitMacros(db, context)
        runSimpleMacros(db)
      } catch (_: Exception) {
        // No-op for now. Avoid crashing background.
      }
    }
  }

  fun runDailyHabitValidation(context: Context) {
    runBlocking(Dispatchers.IO) {
      try {
        val db = AppDatabase.getDatabase(context)
        db.rewardActionDao().deactivateExpired(System.currentTimeMillis())
        val now = Calendar.getInstance()
        val day = now.get(Calendar.DAY_OF_WEEK)
        val minutesNow = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
        val validator = ValidatorEngine(context, db)

        val habits =
          db.habitMacroDao().getAll()
            .filter { it.isActive }
            .sortedByDescending { it.priority }
        for (macro in habits) {
          val stateObj = parseState(macro.stateJson)
          val lastCheck = stateObj.optString("lastDailyCheck", "")
          if (lastCheck == date) continue

          val conditionsJson = macro.conditionsJson
          val success =
            if (conditionsJson.isNotBlank() && conditionsJson != "[]") {
              validator.conditionsMatch(
                conditionsJson,
                date,
                day,
                minutesNow,
                stateObj.toString()
              )
            } else {
              val triggeredOn = stateObj.optString("triggeredOn", "")
              val completed = stateObj.optBoolean("completedToday", false)
              completed || triggeredOn == date
            }

          val updatedState = updateHabitDailyState(stateObj, success, date)
          db.habitMacroDao().update(
            macro.copy(stateJson = updatedState, updatedAt = System.currentTimeMillis())
          )
          if (success) {
            logExecution(context, macro.id, "Validación diaria", "Hábito cumplido")
          } else {
            logExecution(context, macro.id, "Validación diaria", "Hábito fallado")
          }
        }
      } catch (_: Exception) {
      }
    }
  }

  private suspend fun runSimpleMacros(db: AppDatabase) {
    val macros = db.macroDao().getActive()
    for (macro in macros) {
      applySimpleMacro(db, macro)
    }
  }

  private suspend fun runStructuredMacros(db: AppDatabase, context: Context) {
    val now = Calendar.getInstance()
    val day = now.get(Calendar.DAY_OF_WEEK) // 1=Sun..7=Sat
    val minutesNow = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
    val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
    val validator = ValidatorEngine(context, db)
    runHabitMacros(db, context, day, minutesNow, date, validator)
    runDisciplineMacros(db, context, day, minutesNow, date, validator)
  }

  private suspend fun runHabitMacros(
          db: AppDatabase,
          context: Context,
          day: Int? = null,
          minutesNow: Int? = null,
          date: String? = null,
          validator: ValidatorEngine? = null
  ) {
    val now = Calendar.getInstance()
    val currentDay = day ?: now.get(Calendar.DAY_OF_WEEK)
    val currentMinutes = minutesNow ?: (now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE))
    val currentDate = date ?: SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
    val engine = validator ?: ValidatorEngine(context, db)
    val contextualEvaluator = ContextualMacroEvaluator(context, db)

    val habits =
      db.habitMacroDao().getAll()
        .filter { it.isActive }
        .sortedByDescending { it.priority }
    for (macro in habits) {
      val actions = parseNodes(macro.actionsJson)
      if (!engine.triggersMatch(macro.triggersJson, currentDay, currentMinutes, macro.stateJson)) continue
      val manualUsed = containsManualTrigger(parseNodes(macro.triggersJson))
      var workingState = updateStateJson(macro.stateJson, "triggeredOn", currentDate)
      val conditionsOk =
        engine.conditionsMatch(
          macro.conditionsJson,
          currentDate,
          currentDay,
          currentMinutes,
          workingState
        )
      if (conditionsOk) {
        workingState = updateStateJson(workingState, "completedToday", true)
        val nextState =
          applyActions(actions, db, macro.id, workingState, manualUsed, null)
        db.habitMacroDao().update(
          macro.copy(stateJson = nextState, updatedAt = System.currentTimeMillis())
        )
        logExecution(context, macro.id, "Macro hábito ejecutada", "Acciones aplicadas")
      } else {
        db.habitMacroDao().update(
          macro.copy(stateJson = workingState, updatedAt = System.currentTimeMillis())
        )
        logExecution(context, macro.id, "Macro hábito evaluada", "Condiciones no cumplidas")
      }
    }
  }

  private suspend fun runDisciplineMacros(
          db: AppDatabase,
          context: Context,
          day: Int? = null,
          minutesNow: Int? = null,
          date: String? = null,
          validator: ValidatorEngine? = null
  ) {
    val now = Calendar.getInstance()
    val currentDay = day ?: now.get(Calendar.DAY_OF_WEEK)
    val currentMinutes = minutesNow ?: (now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE))
    val currentDate = date ?: SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now.time)
    val engine = validator ?: ValidatorEngine(context, db)
    val contextualEvaluator = ContextualMacroEvaluator(context, db)

    val disciplines =
      db.disciplineMacroDao().getAll()
        .filter { it.isActive }
        .sortedByDescending { it.priority }
    for (macro in disciplines) {
      val actions = parseNodes(macro.actionsJson)
      if (!contextualEvaluator.shouldExecute(macro, currentDay, currentMinutes, currentDate)) continue
      val manualUsed = containsManualTrigger(parseNodes(macro.triggersJson))
      val nextState = applyActions(actions, db, macro.id, macro.stateJson, manualUsed, null)
      if (nextState != macro.stateJson) {
        db.disciplineMacroDao().update(
          macro.copy(stateJson = nextState, updatedAt = System.currentTimeMillis())
        )
      }
      logExecution(context, macro.id, "Macro disciplina ejecutada", "Acciones aplicadas")
    }
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

  private fun triggersMatch(
          triggers: List<Node>,
          day: Int,
          minutesNow: Int,
          context: Context,
          stateJson: String
  ): Boolean {
    if (triggers.isEmpty()) return false
    val prefs = context.getSharedPreferences("macro_engine", Context.MODE_PRIVATE)
    val lastApp = prefs.getString("last_app_opened", null)
    val lastAppAt = prefs.getLong("last_app_opened_at", 0L)
    val lastInteraction = prefs.getLong("last_interaction_at", 0L)
    val now = System.currentTimeMillis()
    val battery = getBatteryLevel(context)
    val charging = isCharging(context)
    val state = try {
      if (stateJson.isBlank()) JSONObject() else JSONObject(stateJson)
    } catch (_: Exception) {
      JSONObject()
    }
    val manualAt = state.optLong("manualTriggerAt", 0L)
    fun evalTrigger(node: Node, depth: Int = 0): Boolean {
      if (depth > 3) return false
      return when (node.type) {
        "time_of_day" -> {
          val hour = (node.params["hour"] as? Number)?.toInt() ?: return false
          val minute = (node.params["minute"] as? Number)?.toInt() ?: 0
          val target = hour * 60 + minute
          kotlin.math.abs(target - minutesNow) <= TIME_WINDOW_MINUTES
        }
        "day_of_week" -> {
          val days = (node.params["days"] as? List<*>)?.mapNotNull {
            (it as? Number)?.toInt() ?: it?.toString()?.toIntOrNull()
          } ?: return false
          days.contains(day)
        }
        "app_opened" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          lastApp == pkg && (now - lastAppAt) <= TIME_WINDOW_MINUTES * 60_000L
        }
        "screen_time_checkpoint" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val interval = (node.params["minutes"] as? Number)?.toInt() ?: 0
          if (interval <= 0) return false
          val usageMinutes = getUsageMinutesToday(context, pkg)
          if (usageMinutes <= 0) return false
          val remainder = usageMinutes % interval
          remainder <= 1
        }
        "usage_exceeded" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(context, pkg)
          usageMinutes >= limit
        }
        "usage_below" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(context, pkg)
          usageMinutes <= limit
        }
        "battery_level" -> {
          val percent = (node.params["percent"] as? Number)?.toInt() ?: return false
          val direction = node.params["direction"]?.toString() ?: "at_or_below"
          val level = battery ?: 100
          if (direction == "at_or_above") level >= percent else level <= percent
        }
        "device_inactive" -> {
          val minutes = (node.params["minutes"] as? Number)?.toInt() ?: 0
          if (minutes <= 0) return false
          now - lastInteraction >= minutes * 60_000L
        }
        "manual" -> {
          manualAt > 0 && (now - manualAt) <= TIME_WINDOW_MINUTES * 60_000L
        }
        "multi_trigger" -> {
          val op = node.params["operator"]?.toString()?.uppercase() ?: "OR"
          val items = parseTriggerItems(node.params["items"])
          if (items.isEmpty()) return false
          if (op == "AND") {
            items.all { evalTrigger(it, depth + 1) }
          } else {
            items.any { evalTrigger(it, depth + 1) }
          }
        }
        else -> false
      }
    }
    return triggers.any { node -> evalTrigger(node) }
  }

  private suspend fun conditionsMatch(
          conditions: List<Node>,
          db: AppDatabase,
          context: Context,
          date: String,
          day: Int,
          minutesNow: Int,
          battery: Int?,
          charging: Boolean,
          stateJson: String
  ): Boolean {
    if (conditions.isEmpty()) return true
    val state = try {
      if (stateJson.isBlank()) JSONObject() else JSONObject(stateJson)
    } catch (_: Exception) {
      JSONObject()
    }
    suspend fun evalCondition(node: Node, depth: Int = 0): Boolean {
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
          val usage = ensureUsageRecord(context, db, pkg, date)
          (usage?.usedMinutes ?: 0) >= limit
        }
        "usage_below" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(context, pkg)
          usageMinutes <= limit
        }
        "today_screen_time" -> {
          val pkg = node.params["packageName"]?.toString() ?: return false
          val limit = (node.params["minutes"] as? Number)?.toInt() ?: return false
          val usageMinutes = getUsageMinutesToday(context, pkg)
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
              if (!evalCondition(item, depth + 1)) return false
            }
            true
          } else {
            for (item in items) {
              if (evalCondition(item, depth + 1)) return true
            }
            false
          }
        }
        else -> true
      }
    }
    for (condition in conditions) {
      if (!evalCondition(condition)) return false
    }
    return true
  }

  private suspend fun applyActions(
          actions: List<Node>,
          db: AppDatabase,
          macroId: String,
          stateJson: String,
          manualUsed: Boolean,
          onStateUpdated: ((String) -> Unit)?,
          depth: Int = 0
  ): String {
    var state = stateJson
    val stateObj = parseState(stateJson)
    actions.forEach { node ->
      when (node.type) {
        "block_apps" -> {
          val pkg = node.params["packageName"]?.toString() ?: return@forEach
          val name = node.params["appName"]?.toString() ?: pkg
          val minutes = (node.params["minutes"] as? Number)?.toInt() ?: 30
          val existing = db.appBlockDao().getByPackage(pkg)
          if (existing == null) {
            val block =
              AppBlock(
                id = UUID.randomUUID().toString(),
                packageName = pkg,
                appName = name,
                dailyQuotaMinutes = minutes,
                isEnabled = true,
                macroType = "BLOCK",
                limitType = "daily",
                dailyMode = "same",
                dailyQuotas = "",
                weeklyQuotaMinutes = 0,
                weeklyResetDay = 2,
                weeklyResetHour = 0,
                weeklyResetMinute = 0,
                expiresAt = null,
                createdAt = System.currentTimeMillis()
              )
            db.appBlockDao().insert(block)
          } else {
            db.appBlockDao().update(
              existing.copy(
                appName = name,
                dailyQuotaMinutes = minutes,
                isEnabled = true,
                macroType = "BLOCK"
              )
            )
          }
          state = updateStateList(state, "activeBlocks", pkg, true)
        }
        "unblock_apps" -> {
          val pkg = node.params["packageName"]?.toString() ?: return@forEach
          val existing = db.appBlockDao().getByPackage(pkg)
          if (existing != null) {
            db.appBlockDao().delete(existing)
          }
          state = updateStateList(state, "activeBlocks", pkg, false)
        }
        "extend_limit" -> {
          val pkg = node.params["packageName"]?.toString() ?: return@forEach
          val minutes = (node.params["minutes"] as? Number)?.toInt() ?: 10
          val existing = db.appBlockDao().getByPackage(pkg)
          if (existing != null) {
            db.appBlockDao().update(
              existing.copy(
                dailyQuotaMinutes = existing.dailyQuotaMinutes + minutes,
                isEnabled = true,
                macroType = "REWARD"
              )
            )
          }
          state = updateStateMapInt(state, "dailyTimeAllowed", pkg, minutes, true)
        }
        "grant_reward" -> {
          val pkg = node.params["packageName"]?.toString() ?: return@forEach
          val minutes = computeRewardMinutes(node.params, stateObj, 15)
          if (minutes <= 0) return@forEach
          val expiresAt = rewardExpiresAt(node.params)
          val reward =
            RewardActionEntity(
              id = UUID.randomUUID().toString(),
              packageName = pkg,
              type = "GRANT_REWARD",
              minutes = minutes,
              grantedBy = macroId,
              grantedAt = System.currentTimeMillis(),
              expiresAt = expiresAt,
              isActive = true
            )
          db.rewardActionDao().insert(reward)
          state = updateStateMapInt(state, "dailyTimeAllowed", pkg, minutes, true)
        }
        "unlock_window" -> {
          val pkg = node.params["packageName"]?.toString() ?: return@forEach
          val minutes = computeRewardMinutes(node.params, stateObj, 30)
          if (minutes <= 0) return@forEach
          val expiresAt = System.currentTimeMillis() + minutes * 60_000L
          val reward =
            RewardActionEntity(
              id = UUID.randomUUID().toString(),
              packageName = pkg,
              type = "UNLOCK_WINDOW",
              minutes = minutes,
              grantedBy = macroId,
              grantedAt = System.currentTimeMillis(),
              expiresAt = expiresAt,
              isActive = true
            )
          db.rewardActionDao().insert(reward)
        }
        "run_macro" -> {
          val targetId = node.params["macroId"]?.toString() ?: return@forEach
          if (depth > 2) return@forEach
          executeMacroById(db, targetId, depth + 1)
        }
        "reduce_block" -> {
          val pkg = node.params["packageName"]?.toString() ?: return@forEach
          val minutes = (node.params["minutes"] as? Number)?.toInt() ?: 10
          val existing = db.appBlockDao().getByPackage(pkg)
          if (existing != null) {
            val next = (existing.dailyQuotaMinutes - minutes).coerceAtLeast(0)
            db.appBlockDao().update(
              existing.copy(
                dailyQuotaMinutes = next,
                isEnabled = next > 0,
                macroType = "BLOCK"
              )
            )
          }
          state = updateStateMapInt(state, "dailyTimeAllowed", pkg, -minutes, true)
        }
        "send_notification" -> {
          Log.i("MacroEngine", "Notify $macroId: ${node.params["message"]}")
        }
        "update_state" -> {
          val key = node.params["key"]?.toString() ?: return@forEach
          val value = node.params["value"]
          state = updateStateJson(state, key, value)
          onStateUpdated?.invoke(state)
        }
      }
    }
    if (manualUsed) {
      state = updateStateJson(state, "manualTriggerAt", 0)
      onStateUpdated?.invoke(state)
    }
    return state
  }

  private fun updateStateJson(raw: String, key: String, value: Any?): String {
    return try {
      val obj = if (raw.isBlank()) JSONObject() else JSONObject(raw)
      obj.put(key, value)
      obj.toString()
    } catch (_: Exception) {
      "{}"
    }
  }

  private fun updateHabitDailyState(
          state: JSONObject,
          success: Boolean,
          date: String
  ): String {
    return try {
      val currentStreak = state.optInt("currentStreak", 0)
      val longestStreak = state.optInt("longestStreak", 0)
      val consecutiveFailures = state.optInt("consecutiveFailures", 0)
      val totalCompletions = state.optInt("totalCompletions", 0)
      val totalFailures = state.optInt("totalFailures", 0)

      if (success) {
        val nextStreak = currentStreak + 1
        state.put("currentStreak", nextStreak)
        state.put("longestStreak", maxOf(longestStreak, nextStreak))
        state.put("consecutiveFailures", 0)
        state.put("totalCompletions", totalCompletions + 1)
        state.put("lastCompletionDate", date)
        state.put("recidivismLevel", 0)
      } else {
        state.put("currentStreak", 0)
        val nextFailures = consecutiveFailures + 1
        state.put("consecutiveFailures", nextFailures)
        state.put("totalFailures", totalFailures + 1)
        state.put("lastFailureDate", date)
        state.put("recidivismLevel", computeRecidivismLevel(nextFailures))
      }

      appendHistory(state, date, success)
      state.put("lastDailyCheck", date)
      state.remove("completedToday")
      state.remove("triggeredOn")
      state.toString()
    } catch (_: Exception) {
      state.toString()
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

  private fun updateStateList(raw: String, key: String, value: String, add: Boolean): String {
    return try {
      val obj = if (raw.isBlank()) JSONObject() else JSONObject(raw)
      val arr = obj.optJSONArray(key) ?: JSONArray()
      val list = mutableListOf<String>()
      for (i in 0 until arr.length()) {
        val item = arr.optString(i)
        if (item.isNotBlank()) list.add(item)
      }
      val updated =
        if (add) {
          if (!list.contains(value)) list.add(value)
          list
        } else {
          list.filter { it != value }
        }
      obj.put(key, JSONArray(updated))
      obj.toString()
    } catch (_: Exception) {
      raw
    }
  }

  private fun updateStateMapInt(
          raw: String,
          key: String,
          entryKey: String,
          delta: Int,
          clampNonNegative: Boolean
  ): String {
    return try {
      val obj = if (raw.isBlank()) JSONObject() else JSONObject(raw)
      val mapObj = obj.optJSONObject(key) ?: JSONObject()
      val current = mapObj.optInt(entryKey, 0)
      var next = current + delta
      if (clampNonNegative) next = next.coerceAtLeast(0)
      mapObj.put(entryKey, next)
      obj.put(key, mapObj)
      obj.toString()
    } catch (_: Exception) {
      raw
    }
  }

  private fun appendHistory(state: JSONObject, date: String, success: Boolean) {
    val history = state.optJSONArray("history") ?: JSONArray()
    val entry = JSONObject()
    entry.put("date", date)
    entry.put("success", success)
    entry.put("streak", state.optInt("currentStreak", 0))
    entry.put("failures", state.optInt("consecutiveFailures", 0))
    history.put(entry)
    val trimmed = JSONArray()
    val max = 90
    val start = (history.length() - max).coerceAtLeast(0)
    for (i in start until history.length()) {
      trimmed.put(history.get(i))
    }
    state.put("history", trimmed)
  }

  private fun computeRecidivismLevel(consecutiveFailures: Int): Int {
    return when {
      consecutiveFailures <= 0 -> 0
      consecutiveFailures == 1 -> 1
      consecutiveFailures == 2 -> 2
      consecutiveFailures <= 4 -> 3
      consecutiveFailures <= 7 -> 4
      else -> 5
    }
  }

  private fun computeRewardMinutes(
          params: Map<String, Any?>,
          state: JSONObject,
          fallback: Int
  ): Int {
    val policy = params["policy"]?.toString() ?: "fixed"
    val base =
      (params["baseMinutes"] as? Number)?.toInt()
        ?: (params["minutes"] as? Number)?.toInt()
        ?: fallback
    val step = (params["stepMinutes"] as? Number)?.toInt() ?: 5
    val max = (params["maxMinutes"] as? Number)?.toInt() ?: (base + step * 5)
    val blockStep = (params["recidivismBlockStep"] as? Number)?.toInt() ?: 0
    val streak = state.optInt("currentStreak", 0)
    val recidivism = state.optInt("recidivismLevel", 0)

    return when (policy) {
      "streak_progressive" -> {
        val raw = base + (streak * step) - (recidivism * blockStep)
        raw.coerceIn(0, max)
      }
      "recidivism_relief" -> {
        val raw = base + (recidivism * step)
        raw.coerceIn(0, max)
      }
      else -> base.coerceAtLeast(0)
    }
  }

  private fun rewardExpiresAt(params: Map<String, Any?>): Long? {
    val duration =
      (params["durationMinutes"] as? Number)?.toInt()
        ?: (params["expiresMinutes"] as? Number)?.toInt()
        ?: 0
    if (duration <= 0) return null
    return System.currentTimeMillis() + duration * 60_000L
  }

  private suspend fun applySimpleMacro(db: AppDatabase, macro: io.github.johnivansn.yugo.database.MacroEntity) {
    val type = macro.actionType
    val pkg = macro.packageName ?: ""
    val appName = macro.appName ?: pkg
    if (pkg.isBlank()) return
    if (type == "unblock" || type == "unlock") {
      val existing = db.appBlockDao().getByPackage(pkg)
      if (existing != null) {
        db.appBlockDao().delete(existing)
      }
      return
    }
    val minutes = macro.minutes
    val existing = db.appBlockDao().getByPackage(pkg)
    if (type == "extend" && existing != null) {
      val updated =
        existing.copy(
          appName = appName,
          dailyQuotaMinutes = existing.dailyQuotaMinutes + minutes,
          isEnabled = true,
          macroType = "REWARD",
          limitType = "daily",
          dailyMode = "same",
          dailyQuotas = "",
          weeklyQuotaMinutes = 0,
          weeklyResetDay = 2,
          weeklyResetHour = 0,
          weeklyResetMinute = 0,
          expiresAt = null
        )
      db.appBlockDao().update(updated)
      return
    }
    if (existing == null) {
      val block =
        AppBlock(
          id = UUID.randomUUID().toString(),
          packageName = pkg,
          appName = appName,
          dailyQuotaMinutes = minutes,
          isEnabled = true,
          macroType = "BLOCK",
          limitType = "daily",
          dailyMode = "same",
          dailyQuotas = "",
          weeklyQuotaMinutes = 0,
          weeklyResetDay = 2,
          weeklyResetHour = 0,
          weeklyResetMinute = 0,
          expiresAt = null,
          createdAt = System.currentTimeMillis()
        )
      db.appBlockDao().insert(block)
    } else {
      val updated =
        existing.copy(
          appName = appName,
          dailyQuotaMinutes = minutes,
          isEnabled = true,
          macroType = "BLOCK",
          limitType = "daily",
          dailyMode = "same",
          dailyQuotas = "",
          weeklyQuotaMinutes = 0,
          weeklyResetDay = 2,
          weeklyResetHour = 0,
          weeklyResetMinute = 0,
          expiresAt = null
        )
      db.appBlockDao().update(updated)
    }
  }

  private suspend fun executeMacroById(db: AppDatabase, macroId: String, depth: Int) {
    if (depth > 2) return
    val simple = db.macroDao().getById(macroId)
    if (simple != null && simple.isActive) {
      applySimpleMacro(db, simple)
      return
    }
    val habit = db.habitMacroDao().getById(macroId)
    if (habit != null && habit.isActive) {
      val actions = parseNodes(habit.actionsJson)
      applyActions(actions, db, habit.id, habit.stateJson, false, null, depth)
      return
    }
    val discipline = db.disciplineMacroDao().getById(macroId)
    if (discipline != null && discipline.isActive) {
      val actions = parseNodes(discipline.actionsJson)
      applyActions(actions, db, discipline.id, discipline.stateJson, false, null, depth)
    }
  }

  private fun mapToParams(raw: Any?): Map<String, Any?> {
    return when (raw) {
      is JSONObject -> jsonToMap(raw)
      is Map<*, *> -> raw.entries.associate { it.key.toString() to it.value }
      else -> emptyMap()
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

  private fun containsManualTrigger(triggers: List<Node>, depth: Int = 0): Boolean {
    if (depth > 3) return false
    return triggers.any { node ->
      when (node.type) {
        "manual" -> true
        "multi_trigger" -> {
          val items = parseTriggerItems(node.params["items"])
          containsManualTrigger(items, depth + 1)
        }
        else -> false
      }
    }
  }

  private fun getBatteryLevel(context: Context): Int? {
    return try {
      val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
      val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
      if (level in 0..100) level else null
    } catch (_: Exception) {
      null
    }
  }

  private fun isCharging(context: Context): Boolean {
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

  private data class Node(val type: String, val params: Map<String, Any?>)

  private suspend fun ensureUsageRecord(
          context: Context,
          db: AppDatabase,
          packageName: String,
          date: String
  ): DailyUsage? {
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

  private fun getUsageMinutesToday(context: Context, packageName: String): Int {
    return try {
      val usageMillis = UsageStatsMonitor(context).getUsageToday(packageName)
      (usageMillis / 60000).toInt()
    } catch (_: Exception) {
      0
    }
  }

  private suspend fun logExecution(context: Context, macroId: String, title: String, body: String) {
    try {
      val db = AppDatabase.getDatabase(context)
      val log =
        io.github.johnivansn.yugo.database.MacroLogEntity(
          id = UUID.randomUUID().toString(),
          macroId = macroId,
          timestamp = System.currentTimeMillis(),
          title = title,
          body = body,
          level = "info",
          source = "engine"
        )
      db.macroLogDao().insert(log)
    } catch (_: Exception) {
    }
  }
}







