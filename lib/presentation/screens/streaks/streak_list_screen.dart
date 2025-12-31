import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/streak_model.dart';
import '../../../data/models/habit_model.dart';
import 'streak_detail_screen.dart';

class StreakListScreen extends StatefulWidget {
  const StreakListScreen({super.key});

  @override
  State<StreakListScreen> createState() => _StreakListScreenState();
}

class _StreakListScreenState extends State<StreakListScreen> {
  bool _showOnlyActive = true;
  _SortBy _sortBy = _SortBy.currentStreak;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rachas'),
        actions: [
          IconButton(
            icon: Icon(_showOnlyActive ? Icons.toggle_on : Icons.toggle_off),
            onPressed: () {
              setState(() {
                _showOnlyActive = !_showOnlyActive;
              });
            },
            tooltip: _showOnlyActive ? 'Mostrar todas' : 'Solo activas',
          ),
          PopupMenuButton<_SortBy>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _SortBy.currentStreak,
                child: Text('Racha actual'),
              ),
              const PopupMenuItem(
                value: _SortBy.longestStreak,
                child: Text('Mejor racha'),
              ),
              const PopupMenuItem(
                value: _SortBy.totalCompletions,
                child: Text('Total completados'),
              ),
              const PopupMenuItem(
                value: _SortBy.successRate,
                child: Text('Tasa de éxito'),
              ),
            ],
          ),
        ],
      ),
      body: _buildStreaksList(),
    );
  }

  Widget _buildStreaksList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<StreakModel>(
        StorageKeys.streaksBox,
      ).listenable(),
      builder: (context, Box<StreakModel> box, _) {
        if (box.isEmpty) {
          return _buildEmptyState();
        }

        var streaks = box.values.toList();

        if (_showOnlyActive) {
          streaks = streaks.where((s) => s.isActive).toList();
        }

        _sortStreaks(streaks);

        if (streaks.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: streaks.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final streak = streaks[index];
            return _buildStreakCard(streak);
          },
        );
      },
    );
  }

  void _sortStreaks(List<StreakModel> streaks) {
    switch (_sortBy) {
      case _SortBy.currentStreak:
        streaks.sort((a, b) => b.currentStreak.compareTo(a.currentStreak));
        break;
      case _SortBy.longestStreak:
        streaks.sort((a, b) => b.longestStreak.compareTo(a.longestStreak));
        break;
      case _SortBy.totalCompletions:
        streaks.sort(
          (a, b) => b.totalCompletions.compareTo(a.totalCompletions),
        );
        break;
      case _SortBy.successRate:
        streaks.sort((a, b) {
          final totalA = a.totalCompletions + a.totalFailures;
          final totalB = b.totalCompletions + b.totalFailures;
          final rateA = totalA > 0 ? a.totalCompletions / totalA : 0;
          final rateB = totalB > 0 ? b.totalCompletions / totalB : 0;
          return rateB.compareTo(rateA);
        });
        break;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay rachas registradas',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Las rachas se crean automáticamente\ncuando completas hábitos',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Sin resultados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay rachas activas',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(StreakModel streak) {
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);
    final habit = habitsBox.get(streak.habitId);

    if (habit == null) {
      return const SizedBox.shrink();
    }

    final total = streak.totalCompletions + streak.totalFailures;
    final successRate = total > 0
        ? (streak.totalCompletions / total * 100).toInt()
        : 0;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StreakDetailScreen(streak: streak),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: _getStreakColor(streak.currentStreak),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Iniciada: ${_formatDate(streak.startDate)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  if (!streak.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: const Text(
                        'FINALIZADA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Actual',
                    streak.currentStreak.toString(),
                    Icons.local_fire_department,
                    Colors.orange,
                  ),
                  _buildStatColumn(
                    'Mejor',
                    streak.longestStreak.toString(),
                    Icons.star,
                    Colors.amber,
                  ),
                  _buildStatColumn(
                    'Éxito',
                    '$successRate%',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatColumn(
                    'Total',
                    '${streak.totalCompletions}/$total',
                    Icons.calendar_today,
                    Colors.blue,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Color _getStreakColor(int streak) {
    if (streak >= 30) return Colors.purple;
    if (streak >= 21) return Colors.red;
    if (streak >= 14) return Colors.deepOrange;
    if (streak >= 7) return Colors.orange;
    if (streak >= 3) return Colors.amber;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

enum _SortBy { currentStreak, longestStreak, totalCompletions, successRate }
