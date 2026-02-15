package io.github.johnivansn.yugo.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface MacroLibraryDao {
  @Query("SELECT * FROM macro_library ORDER BY createdAt DESC")
  fun getAll(): List<MacroLibraryEntry>

  @Insert(onConflict = OnConflictStrategy.REPLACE)
  fun insert(entry: MacroLibraryEntry)

  @Update
  fun update(entry: MacroLibraryEntry)

  @Query("DELETE FROM macro_library WHERE id = :id")
  fun deleteById(id: String)
}







