package io.github.johnivansn.yugo.database

import androidx.room.*

@Dao
interface AppBlockDao {
  @Query("SELECT * FROM app_blocks") suspend fun getAll(): List<AppBlock>

  @Query("SELECT * FROM app_blocks WHERE packageName = :packageName LIMIT 1")
  suspend fun getByPackage(packageName: String): AppBlock?

  @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insert(block: AppBlock)

  @Update suspend fun update(block: AppBlock)

  @Delete suspend fun delete(block: AppBlock)

  @Query("SELECT * FROM app_blocks WHERE isEnabled = 1")
  suspend fun getEnabled(): List<AppBlock>
}








