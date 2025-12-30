import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/streak_model.dart';
import '../../../data/models/habit_model.dart';

class StreakDetailScreen extends StatelessWidget {
  final StreakModel streak;

  const StreakDetailScreen({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);
    final habit = habitsBox.get(streak.habitId);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Racha')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (habit != null) _buildHabitHeader(context, habit),
            const SizedBox(height: 24),
            _buildStreakStats(context),
            const SizedBox(height: 24),
            _buildStreakInfo(context),
            const SizedBox(height: 24),
            _buildCompletedDays(context),
            const SizedBox(height: 24),
            _buildFailedDays(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitHeader(BuildContext context, HabitModel habit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              habit.isActive ? Icons.check_circle : Icons.pause_circle,
              size: 32,
              color: habit.isActive ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    habit.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakStats(BuildContext context) {
    final total = streak.totalCompletions + streak.totalFailures;
    final successRate = total > 0
        ? (streak.totalCompletions / total * 100).toInt()
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLargeStat(
                  'Racha Actual',
                  streak.currentStreak.toString(),
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                _buildLargeStat(
                  'Mejor Racha',
                  streak.longestStreak.toString(),
                  Icons.star,
                  Colors.amber,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSmallStat(
                  'Completados',
                  streak.totalCompletions.toString(),
                  Colors.green,
                ),
                _buildSmallStat(
                  'Fallos',
                  streak.totalFailures.toString(),
                  Colors.red,
                ),
                _buildSmallStat('Tasa Éxito', '$successRate%', Colors.blue),
                _buildSmallStat('Total', total.toString(), Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSmallStat(String label, String value, Color color) {
    return Column(
      children: [
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

  Widget _buildStreakInfo(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fingerprint, 'ID', streak.id),
            _buildInfoRow(
              Icons.calendar_today,
              'Inicio',
              _formatDate(streak.startDate),
            ),
            if (streak.endDate != null)
              _buildInfoRow(Icons.event, 'Fin', _formatDate(streak.endDate!)),
            _buildInfoRow(
              Icons.toggle_on,
              'Estado',
              streak.isActive ? 'Activa' : 'Finalizada',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedDays(BuildContext context) {
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
                  'Días Completados',
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
                    '${streak.completedDates.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (streak.completedDates.isEmpty)
              Text(
                'No hay días completados aún',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: streak.completedDates.reversed.take(10).map((date) {
                  return Chip(
                    label: Text(
                      _formatDate(DateTime.parse(date)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    side: const BorderSide(color: Colors.green),
                  );
                }).toList(),
              ),
            if (streak.completedDates.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Y ${streak.completedDates.length - 10} días más...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedDays(BuildContext context) {
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
                  'Días Fallidos',
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
                    '${streak.failedDates.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (streak.failedDates.isEmpty)
              Text(
                '¡Perfecto! Sin fallos registrados',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: streak.failedDates.reversed.take(10).map((date) {
                  return Chip(
                    label: Text(
                      _formatDate(DateTime.parse(date)),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    side: const BorderSide(color: Colors.red),
                  );
                }).toList(),
              ),
            if (streak.failedDates.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Y ${streak.failedDates.length - 10} días más...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
