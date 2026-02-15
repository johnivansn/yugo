package io.github.johnivansn.yugo.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "reward_actions")
data class RewardActionEntity(
        @PrimaryKey val id: String,
        val packageName: String,
        val type: String,
        val minutes: Int,
        val grantedBy: String,
        val grantedAt: Long,
        val expiresAt: Long?,
        val isActive: Boolean
)







