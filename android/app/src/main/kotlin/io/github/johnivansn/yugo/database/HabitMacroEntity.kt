package io.github.johnivansn.yugo.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "habit_macros")
data class HabitMacroEntity(
  @PrimaryKey val id: String,
  val name: String,
  val isActive: Boolean,
  val macroType: String,
  val priority: Int,
  val triggersJson: String,
  val conditionsJson: String,
  val actionsJson: String,
  val stateJson: String,
  val createdAt: Long,
  val updatedAt: Long
)







