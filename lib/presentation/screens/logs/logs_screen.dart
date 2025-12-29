import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/execution_log_model.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel? _selectedLevel;
  LogType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de Ejecución'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtros',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmClearLogs,
            tooltip: 'Limpiar logs',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedLevel != null || _selectedType != null)
            _buildActiveFilters(),
          Expanded(child: _buildLogsList()),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                if (_selectedLevel != null)
                  Chip(
                    label: Text('Nivel: ${_selectedLevel!.name}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _selectedLevel = null),
                  ),
                if (_selectedType != null)
                  Chip(
                    label: Text('Tipo: ${_selectedType!.name}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _selectedType = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ExecutionLogModel>(
        StorageKeys.executionLogsBox,
      ).listenable(),
      builder: (context, Box<ExecutionLogModel> box, _) {
        if (box.isEmpty) {
          return _buildEmptyState();
        }

        var logs = box.values.toList();
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (_selectedLevel != null) {
          logs = logs.where((log) => log.level == _selectedLevel).toList();
        }

        if (_selectedType != null) {
          logs = logs.where((log) => log.type == _selectedType).toList();
        }

        if (logs.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final log = logs[index];
            return _buildLogCard(log);
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
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay logs registrados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Emite eventos para ver los logs',
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
            'No hay logs con estos filtros',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ExecutionLogModel log) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showLogDetails(log),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildLevelBadge(log.level),
                  const SizedBox(width: 8),
                  _buildTypeBadge(log.type),
                  const Spacer(),
                  Text(
                    _formatTime(log.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                log.message,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
              ),
              if (log.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (log.data.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.data_object,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${log.data.length} campos de datos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(LogLevel level) {
    Color color;
    IconData icon;

    switch (level) {
      case LogLevel.debug:
        color = Colors.grey;
        icon = Icons.bug_report;
        break;
      case LogLevel.info:
        color = Colors.blue;
        icon = Icons.info_outline;
        break;
      case LogLevel.warning:
        color = Colors.orange;
        icon = Icons.warning_amber;
        break;
      case LogLevel.error:
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      case LogLevel.critical:
        color = Colors.purple;
        icon = Icons.crisis_alert;
        break;
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            level.name.toUpperCase(),
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

  Widget _buildTypeBadge(LogType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.name,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'hace ${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'hace ${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Logs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nivel:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: LogLevel.values.map((level) {
                return FilterChip(
                  label: Text(level.name),
                  selected: _selectedLevel == level,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLevel = selected ? level : null;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: LogType.values.map((type) {
                return FilterChip(
                  label: Text(type.name),
                  selected: _selectedType == type,
                  onSelected: (selected) {
                    setState(() {
                      _selectedType = selected ? type : null;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedLevel = null;
                _selectedType = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar filtros'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showLogDetails(ExecutionLogModel log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildLevelBadge(log.level),
                    const SizedBox(width: 8),
                    _buildTypeBadge(log.type),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Detalles del Log',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetailRow('Timestamp', log.timestamp.toString()),
                      _buildDetailRow('ID', log.id),
                      _buildDetailRow('Entidad', log.entityType),
                      _buildDetailRow('Entity ID', log.entityId),
                      const Divider(height: 32),
                      Text(
                        'Mensaje',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(log.message),
                      if (log.errorMessage != null) ...[
                        const Divider(height: 32),
                        Text(
                          'Error',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            log.errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                      if (log.data.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text(
                          'Datos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: log.data.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.key}: ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value.toString(),
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Logs'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar todos los logs? Esta acción no se puede deshacer.',
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

    if (confirmed == true) {
      await _clearLogs();
    }
  }

  Future<void> _clearLogs() async {
    try {
      final box = Hive.box<ExecutionLogModel>(StorageKeys.executionLogsBox);
      await box.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logs eliminados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
