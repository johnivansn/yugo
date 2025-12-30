import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/penalty_model.dart';
import '../../../data/models/habit_model.dart';

class PenaltyDetailScreen extends StatelessWidget {
  final PenaltyModel penalty;

  const PenaltyDetailScreen({super.key, required this.penalty});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Penalización'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Editar penalización - En desarrollo'),
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
            _buildConfigCard(context),
            const SizedBox(height: 16),
            _buildAssociatedHabitsCard(context),
            const SizedBox(height: 16),
            _buildExecutionHistoryCard(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _toggleActive(context),
        icon: Icon(penalty.isActive ? Icons.pause : Icons.play_arrow),
        label: Text(penalty.isActive ? 'Desactivar' : 'Activar'),
        backgroundColor: penalty.isActive ? Colors.orange : Colors.green,
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
                penalty.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusBadge(penalty.isActive),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          penalty.description,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.fingerprint, 'ID', penalty.id),
            _buildInfoRow(Icons.category, 'Tipo', penalty.type.name),
            _buildInfoRow(
              Icons.local_fire_department,
              'Intensidad',
              _getIntensityLabel(penalty.intensity),
            ),
            if (penalty.durationMinutes != null)
              _buildInfoRow(
                Icons.timer,
                'Duración',
                '${penalty.durationMinutes} minutos',
              ),
            _buildInfoRow(
              Icons.undo,
              'Revertible',
              penalty.isRevertible ? 'Sí' : 'No',
            ),
            _buildInfoRow(
              Icons.edit,
              'Tipo',
              penalty.isCustom ? 'Personalizada' : 'Predefinida',
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Creada',
              _formatDate(penalty.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Configuración',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (penalty.config.isEmpty)
              Text(
                'Sin configuración adicional',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: penalty.config.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_right,
                            size: 20,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  entry.value.toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (penalty.targetApps.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.apps, size: 20, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'Apps objetivo (${penalty.targetApps.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: penalty.targetApps.map((app) {
                  return Chip(
                    label: Text(app),
                    avatar: const Icon(Icons.android, size: 16),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssociatedHabitsCard(BuildContext context) {
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);
    final associatedHabits = habitsBox.values
        .where((habit) => habit.penaltyIds.contains(penalty.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Hábitos Asociados',
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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${associatedHabits.length}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (associatedHabits.isEmpty)
              Text(
                'No está asignada a ningún hábito',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...associatedHabits.map((habit) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          habit.isActive
                              ? Icons.check_circle
                              : Icons.pause_circle,
                          size: 18,
                          color: habit.isActive ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 10),
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
                              if (habit.autoExecutePenalties)
                                const SizedBox(height: 2),
                              if (habit.autoExecutePenalties)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.bolt,
                                      size: 12,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ejecución automática',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionHistoryCard(BuildContext context) {
    final executionsBox = Hive.box<PenaltyExecutionModel>(
      StorageKeys.penaltyExecutionsBox,
    );
    final executions =
        executionsBox.values
            .where((exec) => exec.penaltyId == penalty.id)
            .toList()
          ..sort((a, b) => b.executedAt.compareTo(a.executedAt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Historial de Ejecución',
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
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${executions.length}',
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (executions.isEmpty)
              Text(
                'No se ha ejecutado aún',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...executions.take(5).map((execution) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildExecutionTile(execution),
                );
              }),
            if (executions.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ver historial completo - En desarrollo'),
                      ),
                    );
                  },
                  child: Text('Ver todas (${executions.length})'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionTile(PenaltyExecutionModel execution) {
    IconData icon;
    Color color;

    switch (execution.status) {
      case PenaltyExecutionStatus.executed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case PenaltyExecutionStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case PenaltyExecutionStatus.reverted:
        icon = Icons.undo;
        color = Colors.blue;
        break;
      case PenaltyExecutionStatus.executing:
        icon = Icons.pending;
        color = Colors.orange;
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  execution.status.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(execution.executedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (execution.revertedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Revertida: ${_formatDateTime(execution.revertedAt!)}',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                  ),
                ],
                if (execution.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${execution.errorMessage}',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
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
            width: 100,
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
            isActive ? 'ACTIVA' : 'INACTIVA',
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

  String _getIntensityLabel(int intensity) {
    if (intensity >= 4) return '$intensity - Muy Alta';
    if (intensity >= 3) return '$intensity - Alta';
    if (intensity >= 2) return '$intensity - Media';
    return '$intensity - Baja';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _toggleActive(BuildContext context) {
    final box = Hive.box<PenaltyModel>(StorageKeys.penaltiesBox);
    final updatedPenalty = penalty.copyWith(isActive: !penalty.isActive);
    box.put(penalty.id, updatedPenalty);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedPenalty.isActive
              ? '✅ Penalización activada'
              : '⏸️ Penalización desactivada',
        ),
        backgroundColor: updatedPenalty.isActive ? Colors.green : Colors.orange,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Penalización'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${penalty.name}"?\n\nEsta acción no se puede deshacer.',
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
      final box = Hive.box<PenaltyModel>(StorageKeys.penaltiesBox);
      await box.delete(penalty.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Penalización eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
