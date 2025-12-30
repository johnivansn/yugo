import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../data/models/validator_model.dart';
import 'validator_detail_screen.dart';

class ValidatorListScreen extends StatefulWidget {
  const ValidatorListScreen({super.key});

  @override
  State<ValidatorListScreen> createState() => _ValidatorListScreenState();
}

class _ValidatorListScreenState extends State<ValidatorListScreen> {
  bool _showOnlyActive = false;
  ValidatorType? _selectedType;
  bool? _showOnlyCustom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validadores'),
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
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filtros',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedType != null || _showOnlyCustom != null)
            _buildActiveFilters(),
          Expanded(child: _buildValidatorsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Crear validador - En desarrollo (Sprint 3)'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Validador'),
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
                if (_selectedType != null)
                  Chip(
                    label: Text('Tipo: ${_selectedType!.name}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _selectedType = null),
                  ),
                if (_showOnlyCustom != null)
                  Chip(
                    label: Text(
                      _showOnlyCustom! ? 'Personalizados' : 'Predefinidos',
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _showOnlyCustom = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidatorsList() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ValidatorModel>(
        StorageKeys.validatorsBox,
      ).listenable(),
      builder: (context, Box<ValidatorModel> box, _) {
        if (box.isEmpty) {
          return _buildEmptyState();
        }

        var validators = box.values.toList();

        if (_showOnlyActive) {
          validators = validators.where((v) => v.isActive).toList();
        }

        if (_selectedType != null) {
          validators = validators
              .where((v) => v.type == _selectedType)
              .toList();
        }

        if (_showOnlyCustom != null) {
          validators = validators
              .where((v) => v.isCustom == _showOnlyCustom)
              .toList();
        }

        if (validators.isEmpty) {
          return _buildNoResultsState();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: validators.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final validator = validators[index];
            return _buildValidatorCard(validator);
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
            Icons.verified_user_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay validadores registrados',
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
            'No hay validadores con estos filtros',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildValidatorCard(ValidatorModel validator) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ValidatorDetailScreen(validator: validator),
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
                      validator.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                    _getTypeIcon(validator.type),
                    'Tipo: ${validator.type.name}',
                    Colors.blue,
                  ),
                  if (validator.isCustom)
                    _buildInfoChip(Icons.edit, 'Personalizado', Colors.purple),
                  if (validator.config.isNotEmpty)
                    _buildInfoChip(
                      Icons.settings,
                      '${validator.config.length} configuraciones',
                      Colors.orange,
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Validadores'),
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
                children: ValidatorType.values.map((type) {
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
                'Origen:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Predefinidos'),
                    selected: _showOnlyCustom == false,
                    onSelected: (selected) {
                      setState(() {
                        _showOnlyCustom = selected ? false : null;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  FilterChip(
                    label: const Text('Personalizados'),
                    selected: _showOnlyCustom == true,
                    onSelected: (selected) {
                      setState(() {
                        _showOnlyCustom = selected ? true : null;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = null;
                _showOnlyCustom = null;
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
