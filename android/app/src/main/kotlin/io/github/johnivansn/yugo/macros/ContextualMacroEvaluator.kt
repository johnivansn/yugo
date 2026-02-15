package io.github.johnivansn.yugo.macros

import android.content.Context
import io.github.johnivansn.yugo.database.AppDatabase
import io.github.johnivansn.yugo.database.DisciplineMacroEntity

class ContextualMacroEvaluator(
    context: Context,
    private val db: AppDatabase
) {
    private val validator = ValidatorEngine(context, db)

    suspend fun shouldExecute(
        macro: DisciplineMacroEntity,
        day: Int,
        minutesNow: Int,
        date: String
    ): Boolean {
        if (!macro.isActive) return false
        if (!validator.triggersMatch(macro.triggersJson, day, minutesNow, macro.stateJson)) {
            return false
        }
        return validator.conditionsMatch(
            macro.conditionsJson,
            date,
            day,
            minutesNow,
            macro.stateJson
        )
    }
}







