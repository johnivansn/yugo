import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/validator_model.dart';
import '../../../data/models/habit_model.dart';

class ValidatorDetailScreen extends StatelessWidget {
  final ValidatorModel validator;

  const ValidatorDetailScreen({super.key, required this.validator});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Validador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Editar validador - En desarrollo'),
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
            _buildUsageGuideCard(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _toggleActive(context),
        icon: Icon(validator.isActive ? Icons.pause : Icons.play_arrow),
        label: Text(validator.isActive ? 'Desactivar' : 'Activar'),
        backgroundColor: validator.isActive ? Colors.orange : Colors.green,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_getTypeIcon(validator.type), size: 32, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                validator.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusBadge(validator.isActive),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          validator.description,
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
            _buildInfoRow(Icons.fingerprint, 'ID', validator.id),
            _buildInfoRow(Icons.category, 'Tipo', validator.type.name),
            _buildInfoRow(
              Icons.edit,
              'Origen',
              validator.isCustom ? 'Personalizado' : 'Predefinido',
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Creado',
              _formatDate(validator.createdAt),
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
                const Icon(Icons.settings, color: Colors.blue),
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
            if (validator.config.isEmpty)
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
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: validator.config.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_right,
                                size: 20,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              entry.value.toString(),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (validator.metadata.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Metadata',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...validator.metadata.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(
                        '• ${entry.key}: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(fontSize: 12),
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
    );
  }

  Widget _buildAssociatedHabitsCard(BuildContext context) {
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);
    final associatedHabits = habitsBox.values
        .where((habit) => habit.validatorId == validator.id)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.task_alt, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Hábitos que usan este validador',
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
                    '${associatedHabits.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (associatedHabits.isEmpty)
              Text(
                'No está asignado a ningún hábito',
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
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
                              if (habit.validatorConfig.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Config: ${habit.validatorConfig.keys.join(", ")}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey.shade400,
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

  Widget _buildUsageGuideCard(BuildContext context) {
    final guide = _getUsageGuide(validator.type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Guía de Uso',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(
                        'Descripción:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guide['description']!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ejemplo de uso:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    guide['example']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
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

  IconData _getTypeIcon(ValidatorType type) {
    switch (type) {
      case ValidatorType.appUsage:
        return Icons.phone_android;
      case ValidatorType.deviceInactivity:
        return Icons.bedtime;
      case ValidatorType.location:
        return Icons.location_on;
      case ValidatorType.timeOfDay:
        return Icons.schedule;
      case ValidatorType.dataUsage:
        return Icons.data_usage;
      case ValidatorType.stepCount:
        return Icons.directions_walk;
      case ValidatorType.manual:
        return Icons.touch_app;
      case ValidatorType.custom:
        return Icons.code;
    }
  }

  Map<String, String> _getUsageGuide(ValidatorType type) {
    switch (type) {
      case ValidatorType.appUsage:
        return {
          'description':
              'Valida que el usuario haya usado una aplicación específica durante un tiempo mínimo.',
          'example':
              'Hábito "Leer 30 minutos" → Validador: App Kindle abierta ≥ 30 min',
        };
      case ValidatorType.deviceInactivity:
        return {
          'description':
              'Detecta cuando el dispositivo ha estado inactivo por un tiempo determinado.',
          'example':
              'Hábito "Descanso digital" → Validador: Dispositivo inactivo ≥ 2 horas',
        };
      case ValidatorType.location:
        return {
          'description':
              'Valida que el usuario haya estado en una ubicación específica.',
          'example':
              'Hábito "Ir al gym" → Validador: Ubicación = Gimnasio (GPS)',
        };
      case ValidatorType.timeOfDay:
        return {
          'description':
              'Verifica que una acción se haya realizado en un horario específico.',
          'example':
              'Hábito "Madrugar" → Validador: Acción realizada antes de las 7:00 AM',
        };
      case ValidatorType.dataUsage:
        return {
          'description': 'Valida el consumo de datos móviles o WiFi.',
          'example':
              'Hábito "Reducir datos móviles" → Validador: Consumo < 100 MB/día',
        };
      case ValidatorType.stepCount:
        return {
          'description':
              'Valida que se haya alcanzado un número mínimo de pasos.',
          'example': 'Hábito "Caminar 10k pasos" → Validador: Pasos ≥ 10,000',
        };
      case ValidatorType.manual:
        return {
          'description':
              'El usuario marca manualmente cuando completa el hábito.',
          'example': 'Hábito "Meditar" → Usuario marca manualmente al terminar',
        };
      case ValidatorType.custom:
        return {
          'description':
              'Validador personalizado con lógica definida por el usuario.',
          'example': 'Hábito personalizado con reglas específicas del usuario',
        };
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _toggleActive(BuildContext context) {
    final box = Hive.box<ValidatorModel>(StorageKeys.validatorsBox);
    final updatedValidator = validator.copyWith(isActive: !validator.isActive);
    box.put(validator.id, updatedValidator);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedValidator.isActive
              ? '✅ Validador activado'
              : '⏸️ Validador desactivado',
        ),
        backgroundColor: updatedValidator.isActive
            ? Colors.green
            : Colors.orange,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final habitsBox = Hive.box<HabitModel>(StorageKeys.habitsBox);
    final habitsUsing = habitsBox.values
        .where((habit) => habit.validatorId == validator.id)
        .length;
    if (habitsUsing > 0) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(
            'Este validador está siendo usado por $habitsUsing hábito(s).\n\nPrimero debes reasignar o eliminar esos hábitos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Validador'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${validator.name}"?\n\nEsta acción no se puede deshacer.',
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
      final box = Hive.box<ValidatorModel>(StorageKeys.validatorsBox);
      await box.delete(validator.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Validador eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
