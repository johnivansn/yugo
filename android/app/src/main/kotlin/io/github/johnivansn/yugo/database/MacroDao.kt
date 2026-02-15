package io.github.johnivansn.yugo.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface MacroDao {
  @Query("SELECT * FROM macros ORDER BY createdAt DESC")
  fun getAll(): List<MacroEntity>

  @Query("SELECT * FROM macros WHERE id = :id LIMIT 1")
  fun getById(id: String): MacroEntity?

  @Query("SELECT * FROM macros WHERE isActive = 1 ORDER BY createdAt DESC")
  fun getActive(): List<MacroEntity>

  @Insert(onConflict = OnConflictStrategy.REPLACE)
  fun insert(entity: MacroEntity)

  @Update
  fun update(entity: MacroEntity)

  @Query("DELETE FROM macros WHERE id = :id")
  fun deleteById(id: String)
}







