package io.github.johnivansn.yugo.rewards

import io.github.johnivansn.yugo.database.AppDatabase
import io.github.johnivansn.yugo.database.AppBlock

data class EffectiveLimit(
        val baseMinutes: Int,
        val rewardMinutes: Int,
        val effectiveMinutes: Int,
        val hasUnlock: Boolean
)

class EffectiveLimitCalculator(private val database: AppDatabase) {
  fun calculate(packageName: String, baseMinutes: Int, now: Long): EffectiveLimit {
    val rewards = database.rewardActionDao().getActiveForApp(packageName, now)
    val hasUnlock = rewards.any { it.type == "UNLOCK_WINDOW" }
    val rewardMinutes =
            rewards.filter {
                      it.type == "EXTEND_LIMIT" ||
                              it.type == "GRANT_REWARD" ||
                              it.type == "reduce_block"
                    }
                    .sumOf { it.minutes }
    val effectiveMinutes = (baseMinutes + rewardMinutes).coerceAtLeast(0)
    return EffectiveLimit(
            baseMinutes = baseMinutes,
            rewardMinutes = rewardMinutes,
            effectiveMinutes = effectiveMinutes,
            hasUnlock = hasUnlock
    )
  }

  fun calculateForblock(
          block: AppBlock,
          now: Long,
          baseMinutes: Int
  ): EffectiveLimit {
    return calculate(block.packageName, baseMinutes, now)
  }
}







