package io.github.johnivansn.yugo.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
        entities =
                [
                        AppBlock::class,
                        DailyUsage::class,
                        AdminSettings::class,
                        AppSchedule::class,
                        DateBlock::class,
                        BlockTemplate::class,
                        MacroEntity::class,
                        HabitMacroEntity::class,
                        DisciplineMacroEntity::class,
                        MacroLibraryEntry::class,
                        RewardActionEntity::class,
                        MacroLogEntity::class],
        version = 21,
        exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
  abstract fun appBlockDao(): AppBlockDao
  abstract fun dailyUsageDao(): DailyUsageDao
  abstract fun adminSettingsDao(): AdminSettingsDao
  abstract fun appScheduleDao(): AppScheduleDao
  abstract fun dateBlockDao(): DateBlockDao
  abstract fun blockTemplateDao(): BlockTemplateDao
  abstract fun macroDao(): MacroDao
  abstract fun habitMacroDao(): HabitMacroDao
  abstract fun disciplineMacroDao(): DisciplineMacroDao
  abstract fun macroLibraryDao(): MacroLibraryDao
  abstract fun rewardActionDao(): RewardActionDao
  abstract fun macroLogDao(): MacroLogDao

  companion object {
    @Volatile private var INSTANCE: AppDatabase? = null

    fun getDatabase(context: Context): AppDatabase {
      return INSTANCE
              ?: synchronized(this) {
                val instance =
                        Room.databaseBuilder(
                                        context.applicationContext,
                                        AppDatabase::class.java,
                                "app_time_control_db"
                        )
                        .build()
                INSTANCE = instance
                instance
              }
    }
  }
}








