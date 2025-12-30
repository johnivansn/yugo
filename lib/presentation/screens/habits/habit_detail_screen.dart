import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/habit_model.dart';
import '../../../data/models/validator_model.dart';
import '../../../data/models/penalty_model.dart';
import '../../../data/models/streak_model.dart';

class HabitDetailScreen extends StatelessWidget {
  final HabitModel habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Hábito'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Editar hábito - En desarrollo'),
                ),
              );
            },
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
            tooltip: 'Eliminar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 16),
            _buildValidatorCard(context),
            const SizedBox(height: 16),
            _buildPenaltiesCard(context),
            const SizedBox(height: 16),
            _buildStreakCard(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _toggleActive(context),
        icon: Icon(habit.isActive ? Icons.pause : Icons.play_arrow),
        label: Text(habit.isActive ? 'Desactivar' : 'Activar'),
        backgroundColor: habit.isActive ? Colors.orange : Colors.green,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                habit.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            _buildStatusBadge(habit.isActive),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          habit.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade700,
              ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fingerprint, 'ID', habit.id),
            _buildInfoRow(
              Icons.priority_high,
              'Prioridad',
              habit.priority.toString(),
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Creado',
              _formatDate(habit.createdAt),
            ),
            _buildInfoRow(
              Icons.update,
              'Actualizado',
              _formatDate(habit.updatedAt),
            ),
            if (habit.scheduledTime != null)
              _buildInfoRow(
                Icons.schedule,
                'Hora programada',
                habit.scheduledTime!,
              ),
            _buildInfoRow(
              Icons.bolt,
              'Auto-penalización',
              habit.autoExecutePenalties ? 'Sí' : 'No',
            ),
            if (habit.isDisciplineMode)
              _buildInfoRow(
                Icons.lock,
                'Modo Disciplina',
                'Activo',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidatorCard(BuildContext context) {
    final validatorsBox = Hive.box<ValidatorModel>(StorageKeys.validatorsBox);
    final validator = validatorsBox.get(habit.validatorId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Validador',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (validator != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      validator.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      validator.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Tipo: ${validator.type.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (habit.validatorConfig.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Configuración:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...habit.validatorConfig.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Text(
                                '• ${entry.key}: ',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Text(
                'Validador no encontrado (ID: ${habit.validatorId})',
                style: const TextStyle(
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltiesCard(BuildContext context) {
    final penaltiesBox = Hive.box<PenaltyModel>(StorageKeys.penaltiesBox);
    final penalties = habit.penaltyIds
        .map((id) => penaltiesBox.get(id))
        .whereType<PenaltyModel>()
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Penalizaciones',
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
                    '${penalties.length}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (penalties.isEmpty)
              Text(
                'Sin penalizaciones asignadas',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...penalties.asMap().entries.map((entry) {
                final index = entry.key;
                final penalty = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildPenaltyTile(index + 1, penalty),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltyTile(int index, PenaltyModel penalty) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  penalty.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getIntensityColor(penalty.intensity)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Intensidad: ${penalty.intensity}',
                  style: TextStyle(
                    fontSize: 11,
                    color: _getIntensityColor(penalty.intensity),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            penalty.description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              _buildPenaltyChip('Tipo: ${penalty.type.name}'),
              if (penalty.durationMinutes != null)
                _buildPenaltyChip('${penalty.durationMinutes}min'),
              if (penalty.isRevertible)
                _buildPenaltyChip('Revertible'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Color _getIntensityColor(int intensity) {
    if (intensity >= 4) return Colors.red;
    if (intensity >= 3) return Colors.deepOrange;
    if (intensity >= 2) return Colors.orange;
    return Colors.yellow.shade700;
  }

  Widget _buildStreakCard(BuildContext context) {
    final streaksBox = Hive.box<StreakModel>(StorageKeys.streaksBox);
    final streak = streaksBox.values
        .where((s) => s.habitId == habit.id && s.isActive)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Racha Actual',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (streak != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStreakStat(
                    'Actual',
                    streak.currentStreak,
                    Colors.orange,
                  ),
                  _buildStreakStat(
                    'Mejor',
                    streak.longestStreak,
                    Colors.deepOrange,
                  ),
                  _buildStreakStat(
                    'Completados',
                    streak.totalCompletions,
                    Colors.green,
                  ),
                  _buildStreakStat(
                    'Fallos',
                    streak.totalFailures,
                    Colors.red,
                  ),
                ],
              ),
            ] else ...[
              Center(
                child: Text(
                  'Sin racha registrada aún',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStreakStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
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
            width: 120,
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

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.pause_circle,
            size: 16,
            color: isActive ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ACTIVO' : 'INACTIVO',
            style: TextStyle(
              color: isActive ? Colors.green : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

void _toggleActive(BuildContext context) {
    final box = Hive.box<HabitModel>(StorageKeys.habitsBox);
    final updatedHabit = habit.copyWith(
      isActive: !habit.isActive,
      updatedAt: DateTime.now(),
    );
    box.put(habit.id, updatedHabit);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedHabit.isActive ? '✅ Hábito activado' : '⏸️ Hábito desactivado',
        ),
        backgroundColor: updatedHabit.isActive ? Colors.green : Colors.orange,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Hábito'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${habit.name}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final box = Hive.box<HabitModel>(StorageKeys.habitsBox);
      await box.delete(habit.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Hábito eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
