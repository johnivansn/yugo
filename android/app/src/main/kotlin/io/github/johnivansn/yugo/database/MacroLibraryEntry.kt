package io.github.johnivansn.yugo.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "macro_library")
data class MacroLibraryEntry(
  @PrimaryKey val id: String,
  val macroId: String,
  val title: String,
  val macroKind: String,
  val category: String,
  val tagsJson: String,
  val payloadJson: String,
  val isSystem: Boolean,
  val usageCount: Int,
  val createdAt: Long
)







