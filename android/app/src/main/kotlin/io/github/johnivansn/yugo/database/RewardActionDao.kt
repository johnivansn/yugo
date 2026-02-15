package io.github.johnivansn.yugo.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update

@Dao
interface RewardActionDao {
  @Query(
          "SELECT * FROM reward_actions WHERE packageName = :packageName " +
                  "AND isActive = 1 AND (expiresAt IS NULL OR expiresAt > :now)"
  )
  fun getActiveForApp(packageName: String, now: Long): List<RewardActionEntity>

  @Query(
          "SELECT * FROM reward_actions WHERE isActive = 1 AND (expiresAt IS NULL OR expiresAt > :now)"
  )
  fun getAllActive(now: Long): List<RewardActionEntity>

  @Insert
  fun insert(entity: RewardActionEntity)

  @Update
  fun update(entity: RewardActionEntity)

  @Query("UPDATE reward_actions SET isActive = 0 WHERE isActive = 1 AND expiresAt IS NOT NULL AND expiresAt <= :now")
  fun deactivateExpired(now: Long)

  @Query("DELETE FROM reward_actions WHERE id = :id")
  fun deleteById(id: String)
}







