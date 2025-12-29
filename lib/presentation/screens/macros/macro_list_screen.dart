import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/macro_model.dart';
import 'macro_detail_screen.dart';

class MacroListScreen extends StatefulWidget {
  const MacroListScreen({super.key});

  @override
  State<MacroListScreen> createState() => _MacroListScreenState();
}

class _MacroListScreenState extends State<MacroListScreen> {
  bool _showOnlyActive = false;
  EventType? _selectedEventType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Macros'),
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
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtrar por evento',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedEventType != null) _buildActiveFilters(),
          Expanded(child: _buildMacrosList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crear macro - En desarrollo'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Macro'),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.purple.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 20, color: Colors.purple),
          const SizedBox(width: 8),
          Chip(
            label: Text('Evento: ${_selectedEventType!.name}'),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => setState(() => _selectedEventType = null),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<MacroModel>(StorageKeys.macrosBox).listenable(),
      builder: (context, Box<MacroModel> box, _) {
        if (box.isEmpty) {
          return _buildEmptyState();
        }

        var macros = box.values.toList();

        if (_showOnlyActive) {
          macros = macros.where((macro) => macro.isActive).toList();
        }

        if (_selectedEventType != null) {
          macros = macros
              .where((macro) => macro.event.type == _selectedEventType)
              .toList();
        }

        macros.sort((a, b) => b.priority.compareTo(a.priority));

        if (macros.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: macros.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final macro = macros[index];
            return _buildMacroCard(macro);
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
            Icons.dashboard_customize_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay macros registradas',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea datos de prueba desde la pantalla principal',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
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
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Sin resultados',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay macros con estos filtros',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCard(MacroModel macro) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MacroDetailScreen(macro: macro),
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
                      macro.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _buildStatusBadge(macro.isActive),
                  const SizedBox(width: 8),
                  _buildPriorityBadge(macro.priority),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                macro.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.flash_on,
                    'Evento: ${macro.event.type.name}',
                    Colors.blue,
                  ),
                  if (macro.conditions.isNotEmpty)
                    _buildInfoChip(
                      Icons.rule,
                      '${macro.conditions.length} condiciones',
                      Colors.orange,
                    ),
                  _buildInfoChip(
                    Icons.play_arrow,
                    '${macro.actions.length} acciones',
                    Colors.green,
                  ),
                  if (macro.isCustom)
                    _buildInfoChip(
                      Icons.edit,
                      'Personalizada',
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
            isActive ? 'ACTIVA' : 'INACTIVA',
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por Evento'),
       content: RadioGroup<EventType>(
          groupValue: _selectedEventType,
          onChanged: (value) {
            setState(() {
              _selectedEventType = value;
            });
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: EventType.values.map((eventType) {
              return RadioListTile<EventType>(
                title: Text(eventType.name),
                value: eventType,
              );
            }).toList(),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedEventType = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Limpiar filtro'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
