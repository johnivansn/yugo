import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/habit_model.dart';
import '../../../data/models/streak_model.dart';
import '../../../data/models/penalty_model.dart';

class DayDetailScreen extends StatelessWidget {
  final DateTime date;

  const DayDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Día')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildSummaryCard(context),
            const SizedBox(height: 16),
            _buildCompletedHabits(context),
            const SizedBox(height: 16),
            _buildFailedHabits(context),
            const SizedBox(height: 16),
            _buildPenaltiesCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _formatDayHeader(date),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          _isToday(date)
              ? 'Hoy'
              : _isYesterday(date)
              ? 'Ayer'
              : '${_daysAgo(date)} días atrás',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final streaks = Hive.box<StreakModel>(StorageKeys.streaksBox).values;
    final dayData = _getDayData(date, streaks.toList());

    final total = dayData.completedHabits.length + dayData.failedHabits.length;
    final successRate = total > 0
        ? (dayData.completedHabits.length / total * 100).toInt()
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del Día',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  'Completados',
                  dayData.completedHabits.length.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildSummaryStat(
                  'Fallidos',
                  dayData.failedHabits.length.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
                _buildSummaryStat(
                  'Tasa Éxito',
                  '$successRate%',
                  Icons.trending_up,
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildCompletedHabits(BuildContext context) {
    final streaks = Hive.box<StreakModel>(StorageKeys.streaksBox).values;
    final dayData = _getDayData(date, streaks.toList());
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Hábitos Completados',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayData.completedHabits.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dayData.completedHabits.isEmpty)
              Text(
                'No hay hábitos completados este día',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...dayData.completedHabits.map((habitId) {
                final habit = habitsBox.get(habitId);
                if (habit == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildHabitTile(habit, true),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedHabits(BuildContext context) {
    final streaks = Hive.box<StreakModel>(StorageKeys.streaksBox).values;
    final dayData = _getDayData(date, streaks.toList());
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Hábitos Fallidos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayData.failedHabits.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dayData.failedHabits.isEmpty)
              Text(
                '¡Perfecto! Sin fallos este día',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...dayData.failedHabits.map((habitId) {
                final habit = habitsBox.get(habitId);
                if (habit == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildHabitTile(habit, false),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitTile(HabitModel habit, bool completed) {
    final color = completed ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(completed ? Icons.check_circle : Icons.cancel, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  habit.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltiesCard(BuildContext context) {
    final executionsBox = Hive.box<PenaltyExecutionModel>(
      StorageKeys.penaltyExecutionsBox,
    );

    final dayExecutions = executionsBox.values.where((exec) {
      return _isSameDay(exec.executedAt, date);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Penalizaciones Ejecutadas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayExecutions.length}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dayExecutions.isEmpty)
              Text(
                'Sin penalizaciones este día',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...dayExecutions.map((execution) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildPenaltyTile(execution),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltyTile(PenaltyExecutionModel execution) {
    final penaltiesBox = Hive.box<PenaltyModel>(StorageKeys.penaltiesBox);
    final penalty = penaltiesBox.get(execution.penaltyId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  penalty?.name ?? 'Penalización eliminada',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(execution.executedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(execution.status).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              execution.status.name,
              style: TextStyle(
                fontSize: 11,
                color: _getStatusColor(execution.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _DayData _getDayData(DateTime day, List<StreakModel> streaks) {
    final dayStr = _formatDateForComparison(day);
    final completedHabits = <String>[];
    final failedHabits = <String>[];

    for (final streak in streaks) {
      if (streak.completedDates.contains(dayStr)) {
        completedHabits.add(streak.habitId);
      }
      if (streak.failedDates.contains(dayStr)) {
        failedHabits.add(streak.habitId);
      }
    }

    return _DayData(
      completedHabits: completedHabits,
      failedHabits: failedHabits,
    );
  }

  String _formatDateForComparison(DateTime date) {
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }

  String _formatDayHeader(DateTime date) {
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];

    return '$weekday, ${date.day} de $month ${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  int _daysAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    return difference.inDays;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Color _getStatusColor(PenaltyExecutionStatus status) {
    switch (status) {
      case PenaltyExecutionStatus.executed:
        return Colors.green;
      case PenaltyExecutionStatus.failed:
        return Colors.red;
      case PenaltyExecutionStatus.reverted:
        return Colors.blue;
      case PenaltyExecutionStatus.executing:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _DayData {
  final List<String> completedHabits;
  final List<String> failedHabits;
  _DayData({required this.completedHabits, required this.failedHabits});
}
