package io.github.johnivansn.yugo.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "macros")
data class MacroEntity(
  @PrimaryKey val id: String,
  val name: String,
  val description: String,
  val isActive: Boolean,
  val macroType: String,
  val actionType: String,
  val packageName: String?,
  val appName: String?,
  val minutes: Int,
  val createdAt: Long,
  val updatedAt: Long
)







