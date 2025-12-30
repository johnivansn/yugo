import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/habit_model.dart';
import 'habit_detail_screen.dart';

class HabitListScreen extends StatefulWidget {
  const HabitListScreen({super.key});

  @override
  State<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends State<HabitListScreen> {
  bool _showOnlyActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hábitos'),
        actions: [
          IconButton(
            icon: Icon(_showOnlyActive ? Icons.toggle_on : Icons.toggle_off),
            onPressed: () {
              setState(() {
                _showOnlyActive = !_showOnlyActive;
              });
            },
            tooltip: _showOnlyActive ? 'Mostrar todos' : 'Solo activos',
          ),
        ],
      ),
      body: _buildHabitsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crear hábito - En desarrollo (Sprint 3)'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Hábito'),
      ),
    );
  }

  Widget _buildHabitsList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<HabitModel>(StorageKeys.habitsBox).listenable(),
      builder: (context, Box<HabitModel> box, _) {
        if (box.isEmpty) {
          return _buildEmptyState();
        }

        var habits = box.values.toList();

        if (_showOnlyActive) {
          habits = habits.where((habit) => habit.isActive).toList();
        }

        habits.sort((a, b) => b.priority.compareTo(a.priority));

        if (habits.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: habits.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final habit = habits[index];
            return _buildHabitCard(habit);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hay hábitos registrados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea datos de prueba desde la pantalla principal',
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
            'No hay hábitos activos',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(HabitModel habit) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HabitDetailScreen(habit: habit),
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
                  Expanded(
                    child: Text(
                      habit.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadge(habit.isActive),
                  const SizedBox(width: 8),
                  _buildPriorityBadge(habit.priority),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                habit.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStreakInfo(habit.currentStreak, habit.longestStreak),
                  const Spacer(),
                  _buildStatsInfo(habit.totalCompletions, habit.totalFailures),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(Icons.verified_user, 'Validador', Colors.blue),
                  if (habit.penaltyIds.isNotEmpty)
                    _buildInfoChip(
                      Icons.warning,
                      '${habit.penaltyIds.length} penalizaciones',
                      Colors.red,
                    ),
                  if (habit.autoExecutePenalties)
                    _buildInfoChip(Icons.bolt, 'Auto', Colors.orange),
                  if (habit.isDisciplineMode)
                    _buildInfoChip(
                      Icons.lock,
                      'Modo Disciplina',
                      Colors.purple,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.pause_circle,
            size: 14,
            color: isActive ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'ACTIVO' : 'INACTIVO',
            style: TextStyle(
              color: isActive ? Colors.green : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(int priority) {
    Color color;
    if (priority >= 3) {
      color = Colors.red;
    } else if (priority == 2) {
      color = Colors.orange;
    } else {
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'P$priority',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakInfo(int current, int longest) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 16,
            color: Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            '$current días',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (longest > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(máx: $longest)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsInfo(int completions, int failures) {
    final total = completions + failures;
    final successRate = total > 0 ? (completions / total * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            successRate >= 80
                ? Icons.trending_up
                : successRate >= 50
                ? Icons.remove
                : Icons.trending_down,
            size: 16,
            color: Colors.blue,
          ),
          const SizedBox(width: 6),
          Text(
            '$successRate% éxito',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(
            '($completions/$total)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
