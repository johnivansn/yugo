package io.github.johnivansn.yugo.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface MacroLogDao {
  @Insert
  fun insert(entity: MacroLogEntity)

  @Query(
          "SELECT * FROM macro_logs WHERE (:macroId = '' OR macroId = :macroId) " +
                  "ORDER BY timestamp DESC LIMIT :limit OFFSET :offset"
  )
  fun getLogs(macroId: String, limit: Int, offset: Int): List<MacroLogEntity>
}







