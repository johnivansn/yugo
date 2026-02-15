package io.github.johnivansn.yugo.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "macro_logs")
data class MacroLogEntity(
        @PrimaryKey val id: String,
        val macroId: String,
        val timestamp: Long,
        val title: String,
        val body: String,
        val level: String,
        val source: String
)







