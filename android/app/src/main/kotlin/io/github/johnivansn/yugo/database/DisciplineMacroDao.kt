package io.github.johnivansn.yugo.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface DisciplineMacroDao {
  @Query("SELECT * FROM discipline_macros ORDER BY priority DESC, createdAt DESC")
  fun getAll(): List<DisciplineMacroEntity>

  @Query("SELECT * FROM discipline_macros WHERE id = :id LIMIT 1")
  fun getById(id: String): DisciplineMacroEntity?

  @Insert(onConflict = OnConflictStrategy.REPLACE)
  fun insert(entity: DisciplineMacroEntity)

  @Update
  fun update(entity: DisciplineMacroEntity)

  @Query("DELETE FROM discipline_macros WHERE id = :id")
  fun deleteById(id: String)
}







