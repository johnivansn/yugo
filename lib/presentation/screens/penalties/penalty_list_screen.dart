import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/penalty_model.dart';
import 'penalty_detail_screen.dart';

class PenaltyListScreen extends StatefulWidget {
  const PenaltyListScreen({super.key});

  @override
  State<PenaltyListScreen> createState() => _PenaltyListScreenState();
}

class _PenaltyListScreenState extends State<PenaltyListScreen> {
  bool _showOnlyActive = false;
  PenaltyType? _selectedType;
  int? _minIntensity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Penalizaciones'),
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
            tooltip: 'Filtros',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedType != null || _minIntensity != null)
            _buildActiveFilters(),
          Expanded(child: _buildPenaltiesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crear penalización - En desarrollo (Sprint 4)'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Penalización'),
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 20, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                if (_selectedType != null)
                  Chip(
                    label: Text('Tipo: ${_selectedType!.name}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _selectedType = null),
                  ),
                if (_minIntensity != null)
                  Chip(
                    label: Text('Intensidad ≥ $_minIntensity'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _minIntensity = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltiesList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<PenaltyModel>(
        StorageKeys.penaltiesBox,
      ).listenable(),
      builder: (context, Box<PenaltyModel> box, _) {
        if (box.isEmpty) {
          return _buildEmptyState();
        }

        var penalties = box.values.toList();

        if (_showOnlyActive) {
          penalties = penalties.where((p) => p.isActive).toList();
        }

        if (_selectedType != null) {
          penalties = penalties.where((p) => p.type == _selectedType).toList();
        }

        if (_minIntensity != null) {
          penalties = penalties
              .where((p) => p.intensity >= _minIntensity!)
              .toList();
        }

        penalties.sort((a, b) => b.intensity.compareTo(a.intensity));

        if (penalties.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: penalties.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final penalty = penalties[index];
            return _buildPenaltyCard(penalty);
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
            Icons.warning_amber_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay penalizaciones registradas',
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
            'No hay penalizaciones con estos filtros',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPenaltyCard(PenaltyModel penalty) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PenaltyDetailScreen(penalty: penalty),
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
                      penalty.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusBadge(penalty.isActive),
                  const SizedBox(width: 8),
                  _buildIntensityBadge(penalty.intensity),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                penalty.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.category,
                    'Tipo: ${penalty.type.name}',
                    Colors.purple,
                  ),
                  if (penalty.durationMinutes != null)
                    _buildInfoChip(
                      Icons.timer,
                      '${penalty.durationMinutes}min',
                      Colors.blue,
                    ),
                  if (penalty.isRevertible)
                    _buildInfoChip(Icons.undo, 'Revertible', Colors.green),
                  if (penalty.isCustom)
                    _buildInfoChip(Icons.edit, 'Personalizada', Colors.orange),
                  if (penalty.targetApps.isNotEmpty)
                    _buildInfoChip(
                      Icons.apps,
                      '${penalty.targetApps.length} apps',
                      Colors.teal,
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

  Widget _buildIntensityBadge(int intensity) {
    Color color;
    String label;

    if (intensity >= 4) {
      color = Colors.red;
      label = 'MUY ALTA';
    } else if (intensity >= 3) {
      color = Colors.deepOrange;
      label = 'ALTA';
    } else if (intensity >= 2) {
      color = Colors.orange;
      label = 'MEDIA';
    } else {
      color = Colors.yellow.shade700;
      label = 'BAJA';
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
          Icon(Icons.local_fire_department, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
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
        title: const Text('Filtrar Penalizaciones'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: PenaltyType.values.map((type) {
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
              const SizedBox(height: 16),
              const Text(
                'Intensidad mínima:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [1, 2, 3, 4].map((intensity) {
                  return FilterChip(
                    label: Text('≥ $intensity'),
                    selected: _minIntensity == intensity,
                    onSelected: (selected) {
                      setState(() {
                        _minIntensity = selected ? intensity : null;
                      });
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = null;
                _minIntensity = null;
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
}
