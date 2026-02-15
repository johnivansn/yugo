package io.github.johnivansn.yugo.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface HabitMacroDao {
  @Query("SELECT * FROM habit_macros ORDER BY priority DESC, createdAt DESC")
  fun getAll(): List<HabitMacroEntity>

  @Query("SELECT * FROM habit_macros WHERE id = :id LIMIT 1")
  fun getById(id: String): HabitMacroEntity?

  @Insert(onConflict = OnConflictStrategy.REPLACE)
  fun insert(entity: HabitMacroEntity)

  @Update
  fun update(entity: HabitMacroEntity)

  @Query("DELETE FROM habit_macros WHERE id = :id")
  fun deleteById(id: String)
}







