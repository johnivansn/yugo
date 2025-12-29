import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/execution_log_model.dart';
import '../../../data/models/macro_model.dart';

class MacroDetailScreen extends StatelessWidget {
  final MacroModel macro;

  const MacroDetailScreen({super.key, required this.macro});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Macro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Editar macro - En desarrollo')),
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
            _buildEventCard(context),
            const SizedBox(height: 16),
            _buildConditionsCard(context),
            const SizedBox(height: 16),
            _buildActionsCard(context),
            const SizedBox(height: 16),
            _buildExecutionHistoryCard(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _toggleActive(context),
        icon: Icon(macro.isActive ? Icons.pause : Icons.play_arrow),
        label: Text(macro.isActive ? 'Desactivar' : 'Activar'),
        backgroundColor: macro.isActive ? Colors.orange : Colors.green,
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
                macro.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildStatusBadge(macro.isActive),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          macro.description,
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
            _buildInfoRow(Icons.fingerprint, 'ID', macro.id),
            _buildInfoRow(
              Icons.priority_high,
              'Prioridad',
              macro.priority.toString(),
            ),
            _buildInfoRow(
              Icons.edit,
              'Tipo',
              macro.isCustom ? 'Personalizada' : 'Predefinida',
            ),
            _buildInfoRow(
              Icons.calendar_today,
              'Creada',
              _formatDate(macro.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Evento Disparador',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    macro.event.type.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (macro.event.config.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Config: ${macro.event.config}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rule, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Condiciones',
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
                    '${macro.conditions.length}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (macro.conditions.isEmpty)
              Text(
                'Sin condiciones - Se ejecuta siempre',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...macro.conditions.asMap().entries.map((entry) {
                final index = entry.key;
                final condition = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildConditionTile(index + 1, condition),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionTile(int index, MacroCondition condition) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
                  color: Colors.orange,
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
                  condition.type.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Operador: ${condition.operator}'),
          if (condition.value != null) Text('Valor: ${condition.value}'),
          if (condition.config.isNotEmpty)
            Text(
              'Config: ${condition.config}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Acciones',
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
                    '${macro.actions.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...macro.actions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildActionTile(index + 1, action),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(int index, MacroAction action) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
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
                  color: Colors.green,
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
                  action.type.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (action.delaySeconds > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '${action.delaySeconds}s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (action.config.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...action.config.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key}: ',
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
    );
  }

  Widget _buildExecutionHistoryCard(BuildContext context) {
    final logsBox = Hive.box<ExecutionLogModel>(StorageKeys.executionLogsBox);
    final macroLogs =
        logsBox.values.where((log) => log.entityId == macro.id).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.purple),
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
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${macroLogs.length}',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (macroLogs.isEmpty)
              Text(
                'No se ha ejecutado aún',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...macroLogs.take(5).map((log) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildLogTile(log),
                );
              }),
            if (macroLogs.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ver todos los logs - En desarrollo'),
                      ),
                    );
                  },
                  child: Text('Ver todos (${macroLogs.length})'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogTile(ExecutionLogModel log) {
    IconData icon;
    Color color;

    switch (log.level) {
      case LogLevel.error:
        icon = Icons.error;
        color = Colors.red;
        break;
      case LogLevel.warning:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      default:
        icon = Icons.check_circle;
        color = Colors.green;
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDateTime(log.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _toggleActive(BuildContext context) {
    final box = Hive.box<MacroModel>(StorageKeys.macrosBox);
    final updatedMacro = macro.copyWith(isActive: !macro.isActive);
    box.put(macro.id, updatedMacro);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedMacro.isActive ? '✅ Macro activada' : '⏸️ Macro desactivada',
        ),
        backgroundColor: updatedMacro.isActive ? Colors.green : Colors.orange,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Macro'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${macro.name}"?\n\nEsta acción no se puede deshacer.',
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
      final box = Hive.box<MacroModel>(StorageKeys.macrosBox);
      await box.delete(macro.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Macro eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }
}
