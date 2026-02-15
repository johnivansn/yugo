import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';
import 'package:yugo/utils/macro_schema.dart';
import 'package:yugo/widgets/app_picker_dialog.dart';

class MacroEditorScreen extends StatefulWidget {
  const MacroEditorScreen({
    super.key,
    this.macroName,
    this.initialMacroType = 'CUSTOM',
    this.initial,
  });

  final String? macroName;
  final String initialMacroType;
  final Map<String, dynamic>? initial;

  @override
  State<MacroEditorScreen> createState() => _MacroEditorScreenState();
}

class _MacroEditorScreenState extends State<MacroEditorScreen> {
  final List<Map<String, dynamic>> _triggers = [];
  final List<Map<String, dynamic>> _conditions = [];
  final List<Map<String, dynamic>> _actions = [];
  late String _macroType;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  int _priority = 0;
  bool _hasErrors = false;

  Future<void> _addItem(String section) async {
    final picked = await _pickNodeType(section);
    if (picked == null) return;
    setState(() {
      if (section == 'trigger') {
        _triggers.add(makeNode(type: picked.type, label: picked.label));
      } else if (section == 'condition') {
        _conditions.add(makeNode(type: picked.type, label: picked.label));
      } else if (section == 'action') {
        _actions.add(makeNode(type: picked.type, label: picked.label));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? {};
    _macroType = widget.initialMacroType;
    _priority = (init['priority'] as num?)?.toInt() ?? 0;
    _nameController = TextEditingController(
      text: init['name']?.toString() ?? widget.macroName ?? '',
    );
    _descController = TextEditingController(
      text: init['description']?.toString() ?? '',
    );
    final triggersRaw = init['triggersJson']?.toString();
    final conditionsRaw = init['conditionsJson']?.toString();
    final actionsRaw = init['actionsJson']?.toString();
    _triggers.addAll(decodeMacroList(triggersRaw));
    _conditions.addAll(decodeMacroList(conditionsRaw));
    _actions.addAll(decodeMacroList(actionsRaw));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showSnack('Nombre requerido', isError: true);
      return;
    }
    final validationError = _validateNodes();
    if (validationError != null) {
      context.showSnack(validationError, isError: true);
      setState(() => _hasErrors = true);
      return;
    }
    if (_hasErrors) setState(() => _hasErrors = false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final triggersJson = encodeMacroList(_triggers);
    final conditionsJson = encodeMacroList(_conditions);
    final actionsJson = encodeMacroList(_actions);
    final stateJson = encodeMacroList([]);
    final id = widget.initial?['id']?.toString();
    try {
      if (_macroType == 'HABIT_PERSISTENT') {
        final payload = {
          if (id != null) 'id': id,
          'name': name,
          'isActive': widget.initial?['isActive'] ?? true,
          'macroType': _macroType,
          'priority': _priority,
          'triggersJson': triggersJson,
          'conditionsJson': conditionsJson,
          'actionsJson': actionsJson,
          'stateJson': stateJson,
          'createdAt': widget.initial?['createdAt'] ?? now,
          'updatedAt': now,
        };
        if (id != null) {
          await NativeService.updateHabitMacro(payload);
        } else {
          await NativeService.createHabitMacro(payload);
        }
      } else if (_macroType == 'DISCIPLINE') {
        final payload = {
          if (id != null) 'id': id,
          'name': name,
          'isActive': widget.initial?['isActive'] ?? true,
          'macroType': _macroType,
          'priority': _priority,
          'triggersJson': triggersJson,
          'conditionsJson': conditionsJson,
          'actionsJson': actionsJson,
          'stateJson': stateJson,
          'createdAt': widget.initial?['createdAt'] ?? now,
          'updatedAt': now,
        };
        if (id != null) {
          await NativeService.updateDisciplineMacro(payload);
        } else {
          await NativeService.createDisciplineMacro(payload);
        }
      } else {
        final payload = {
          if (id != null) 'id': id,
          'name': name,
          'description': _descController.text.trim(),
          'isActive': widget.initial?['isActive'] ?? true,
          'macroType': _macroType,
          'priority': _priority,
          'actionType': 'custom',
          'minutes': 0,
          'createdAt': widget.initial?['createdAt'] ?? now,
          'updatedAt': now,
        };
        if (id != null) {
          await NativeService.updateMacro(payload);
        } else {
          await NativeService.createMacro(payload);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_hasErrors && _validateNodes() == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor de Macro'),
        actions: [
          TextButton(
            onPressed: _showSimulation,
            child: const Text('Probar'),
          ),
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _headerCard(),
          const SizedBox(height: AppSpacing.lg),
          _sectionCard(
            title: 'TRIGGERS',
            subtitle: 'Disparadores que activan la macro.',
            section: 'trigger',
            items: _triggers,
            emptyLabel: 'Agregar primer trigger',
            onAdd: () => _addItem('trigger'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _sectionCard(
            title: 'CONDICIONES',
            subtitle: 'Criterios que deben cumplirse.',
            section: 'condition',
            items: _conditions,
            emptyLabel: 'Agregar primera condición',
            onAdd: () => _addItem('condition'),
          ),
          const SizedBox(height: AppSpacing.lg),
          _sectionCard(
            title: 'ACCIONES',
            subtitle: 'Consecuencias cuando se activa la macro.',
            section: 'action',
            items: _actions,
            emptyLabel: 'Agregar primera acción',
            onAdd: () => _addItem('action'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _hintCard(),
          const SizedBox(height: AppSpacing.lg),
          _previewCard(),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.macroName ?? 'Nueva macro',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de macro',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Trigger → Condition → Action',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _macroType,
              decoration: const InputDecoration(
                labelText: 'Tipo de macro',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'CUSTOM',
                  child: Text('Custom'),
                ),
                DropdownMenuItem(
                  value: 'HABIT_PERSISTENT',
                  child: Text('Hábito persistente'),
                ),
                DropdownMenuItem(
                  value: 'DISCIPLINE',
                  child: Text('Disciplina'),
                ),
                DropdownMenuItem(
                  value: 'BLOCK',
                  child: Text('Bloqueo'),
                ),
                DropdownMenuItem(
                  value: 'REWARD',
                  child: Text('Recompensa'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _macroType = value);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Prioridad',
              ),
              items: List.generate(
                6,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text('P$index'),
                ),
              ),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _priority = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required String section,
    required List<Map<String, dynamic>> items,
    required String emptyLabel,
    required VoidCallback onAdd,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(emptyLabel),
              )
            else
              Column(
                children: List.generate(items.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _nodeCard(items[index], section, index),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VISTA PREVIA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _flowPreview(),
            const SizedBox(height: AppSpacing.sm),
            _flowTimeline(),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Triggers: ${_triggers.length}\n'
                'Condiciones: ${_conditions.length}\n'
                'Acciones: ${_actions.length}\n'
                '\nSecuencia:\n'
                '${_previewSequence()}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _previewSequence() {
    if (_triggers.isEmpty || _actions.isEmpty) {
      return 'Completa triggers y acciones.';
    }
    final triggerLabels = _triggers.map(_displayNodeLabel).join(', ');
    final conditionLabels = _conditions.isEmpty
        ? 'Sin condiciones'
        : _conditions.map(_displayNodeLabel).join(', ');
    final actionLabels = _actions.map(_displayNodeLabel).join(', ');
    return 'Si ($triggerLabels) y ($conditionLabels) entonces ($actionLabels).';
  }

  Widget _flowPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(child: _flowColumn('Triggers', _triggers)),
          _flowArrow(),
          Expanded(child: _flowColumn('Condiciones', _conditions)),
          _flowArrow(),
          Expanded(child: _flowColumn('Acciones', _actions)),
        ],
      ),
    );
  }

  Widget _flowTimeline() {
    final sections = [
      _FlowSection('Triggers', _triggers),
      _FlowSection('Condiciones', _conditions),
      _FlowSection('Acciones', _actions),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map(_buildFlowSection).toList(),
    );
  }

  Widget _buildFlowSection(_FlowSection section) {
    final items = section.items;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(
              'Sin elementos',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            )
          else
            Column(
              children: items
                  .map(
                    (node) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _flowTimelineNode(node),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _flowTimelineNode(Map<String, dynamic> node) {
    final type = node['type']?.toString() ?? 'custom';
    final label = _displayNodeLabel(node);
    final summary = _nodeSummary(node);
    final icon = _nodeIcon(type);
    final error = _validateNode(node);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: error == null
            ? AppColors.surfaceVariant.withValues(alpha: 0.3)
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: error == null
              ? AppColors.surfaceVariant.withValues(alpha: 0.6)
              : AppColors.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (error != null)
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
        ],
      ),
    );
  }

  Widget _flowArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _flowColumn(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(
            'Vacío',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map((e) => _flowChip(_displayNodeLabel(e)))
                .toList(),
          ),
      ],
    );
  }

  Widget _flowChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }

  String _displayNodeLabel(Map<String, dynamic> node) {
    final type = node['type']?.toString() ?? 'custom';
    final params = Map<String, dynamic>.from(node['params'] ?? {});
    final label = node['label']?.toString();
    if (label != null && label.isNotEmpty && type != 'multi_trigger') {
      return label;
    }
    return _labelFor(type, params);
  }

  String? _validateNodes() {
    if (_triggers.isEmpty) return 'Agrega al menos un trigger.';
    if (_actions.isEmpty) return 'Agrega al menos una acción.';
    for (final node in _triggers) {
      final err = _validateNode(node);
      if (err != null) return err;
    }
    for (final node in _conditions) {
      final err = _validateNode(node);
      if (err != null) return err;
    }
    for (final node in _actions) {
      final err = _validateNode(node);
      if (err != null) return err;
    }
    return null;
  }

  String? _validateNode(Map<String, dynamic> node, {bool allowMulti = true}) {
    final type = node['type']?.toString() ?? 'custom';
    final params = Map<String, dynamic>.from(node['params'] ?? {});
    final allowedSection = (type.startsWith('multi_'))
        ? (type == 'multi_condition' ? 'condition' : 'trigger')
        : (kTriggerTypes.contains(type)
            ? 'trigger'
            : (kConditionTypes.contains(type) ? 'condition' : 'action'));
    if (!isNodeTypeAllowed(type, allowedSection)) {
      return 'Tipo no permitido.';
    }
    final missing = validateNodeSchema(type, params);
    if (missing.isNotEmpty) {
      return 'Faltan: ${missing.join(', ')}';
    }
    switch (type) {
      case 'multi_trigger':
      case 'multi_condition':
        if (!allowMulti) return 'No se permite multi anidado.';
        final items = _normalizeNodeItems(params['items']);
        if (items.isEmpty) return 'Agrega items internos.';
        for (final item in items) {
          final err = _validateNode(item, allowMulti: false);
          if (err != null) return err;
        }
        return null;
      case 'time_of_day':
        if (!params.containsKey('hour')) return 'Falta hora en trigger.';
        return null;
      case 'day_of_week':
        final days = params['days'] as List<dynamic>? ?? [];
        if (days.isEmpty) return 'Selecciona días de semana.';
        return null;
      case 'screen_time_checkpoint':
        if ((params['packageName'] ?? '').toString().isEmpty) {
          return 'Selecciona una app.';
        }
        final minutes = params['minutes'];
        final value = minutes is num ? minutes.toInt() : int.tryParse('$minutes') ?? 0;
        if (value <= 0) return 'Intervalo inválido.';
        return null;
      case 'usage_exceeded':
      case 'usage_below':
        if ((params['packageName'] ?? '').toString().isEmpty) {
          return 'Selecciona una app.';
        }
        final minutes = params['minutes'];
        final value = minutes is num ? minutes.toInt() : int.tryParse('$minutes') ?? 0;
        if (value <= 0) return 'Minutos inválidos.';
        return null;
      case 'app_opened':
      case 'block_apps':
      case 'unblock_apps':
        if ((params['packageName'] ?? '').toString().isEmpty) {
          return 'Selecciona una app.';
        }
        return null;
      case 'device_inactive':
      case 'usage_daily':
      case 'today_screen_time':
        if ((params['packageName'] ?? '').toString().isEmpty) {
          return 'Selecciona una app para la condición de uso.';
        }
        final minutes = params['minutes'];
        final value = minutes is num ? minutes.toInt() : int.tryParse('$minutes') ?? 0;
        if (value <= 0) return 'Minutos inválidos.';
        return null;
      case 'consecutive_failures':
        final count = params['count'];
        final value = count is num ? count.toInt() : int.tryParse('$count') ?? 0;
        if (value <= 0) return 'Valor inválido.';
        return null;
      case 'extend_limit':
      case 'reduce_block':
        final minutes = params['minutes'];
        final value = minutes is num ? minutes.toInt() : int.tryParse('$minutes') ?? 0;
        if (value <= 0) return 'Minutos inválidos.';
        return null;
      case 'grant_reward':
        if ((params['packageName'] ?? '').toString().isEmpty) {
          return 'Selecciona una app.';
        }
        final base = params['baseMinutes'] ?? params['minutes'];
        final value = base is num ? base.toInt() : int.tryParse('$base') ?? 0;
        if (value <= 0) return 'Minutos inválidos.';
        return null;
      case 'unlock_window':
        if ((params['packageName'] ?? '').toString().isEmpty) {
          return 'Selecciona una app.';
        }
        final base = params['baseMinutes'] ?? params['minutes'];
        final value = base is num ? base.toInt() : int.tryParse('$base') ?? 0;
        if (value <= 0) return 'Duración inválida.';
        return null;
      case 'run_macro':
        if ((params['macroId'] ?? '').toString().isEmpty) {
          return 'Selecciona una macro.';
        }
        return null;
      case 'time_range':
        if (!params.containsKey('startHour') || !params.containsKey('endHour')) {
          return 'Rango horario incompleto.';
        }
        return null;
      case 'battery_level':
        final p = params['percent'];
        final value = p is num ? p.toInt() : int.tryParse('$p') ?? -1;
        if (value < 0 || value > 100) return 'Batería inválida.';
        return null;
      case 'is_charging':
        return null;
      case 'send_notification':
        if ((params['message'] ?? '').toString().trim().isEmpty) {
          return 'Mensaje de notificación vacío.';
        }
        return null;
      case 'update_state':
        if ((params['key'] ?? '').toString().trim().isEmpty) {
          return 'Falta clave de estado.';
        }
        return null;
      default:
        return null;
    }
  }

  Widget _nodeLabel(Map<String, dynamic> node) {
    final label = node['label']?.toString() ?? '';
    final error = _validateNode(node);
    final summary = _nodeSummary(node);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            summary,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 2),
          Text(
            error,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _nodeCard(Map<String, dynamic> node, String section, int index) {
    final error = _validateNode(node);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: error == null
            ? AppColors.surfaceVariant.withValues(alpha: 0.35)
            : AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: error == null
              ? AppColors.surfaceVariant.withValues(alpha: 0.6)
              : AppColors.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _nodeLabel(node)),
          IconButton(
            onPressed: () => _editNode(section, index),
            icon: const Icon(Icons.edit, size: 18),
          ),
          IconButton(
            onPressed: () => _removeNode(section, index),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  void _removeNode(String section, int index) {
    final list = _listFor(section);
    if (list == null || index < 0 || index >= list.length) return;
    setState(() => list.removeAt(index));
  }

  Future<void> _editNode(String section, int index) async {
    final list = _listFor(section);
    if (list == null || index < 0 || index >= list.length) return;
    final node = Map<String, dynamic>.from(list[index]);
    final type = node['type']?.toString() ?? 'custom';
    final params = Map<String, dynamic>.from(node['params'] ?? {});

    final updated = await _openParamEditor(type, params);
    if (updated == null) return;

    node['params'] = updated;
    node['label'] = _labelFor(type, updated);
    setState(() {
      list[index] = node;
    });
  }

  List<Map<String, dynamic>>? _listFor(String section) {
    if (section == 'trigger') return _triggers;
    if (section == 'condition') return _conditions;
    if (section == 'action') return _actions;
    return null;
  }

  String _labelFor(String type, Map<String, dynamic> params) {
    switch (type) {
      case 'multi_trigger':
        return _formatMultiTrigger(params);
      case 'multi_condition':
        return _formatMultiCondition(params);
      case 'time_of_day':
        return 'Hora: ${_formatTime(params)}';
      case 'day_of_week':
        return 'Días: ${_formatDays(params)}';
      case 'app_opened':
        return 'App abierta: ${params['appName'] ?? 'App'}';
      case 'screen_time_checkpoint':
        return 'Checkpoint: ${params['minutes'] ?? 0} min en ${params['appName'] ?? 'App'}';
      case 'usage_exceeded':
        return 'Uso excedido: ${params['minutes'] ?? 0} min';
      case 'usage_below':
        return 'Uso por debajo: ${params['minutes'] ?? 0} min';
      case 'device_inactive':
        return 'Inactividad: ${params['minutes'] ?? 0} min';
      case 'manual':
        return 'Manual';
      case 'time_range':
        return 'Rango: ${_formatRange(params)}';
      case 'usage_daily':
        return 'Uso diario: ${params['minutes'] ?? 0} min';
      case 'today_screen_time':
        return 'Pantalla hoy: ${params['minutes'] ?? 0} min en ${params['appName'] ?? 'App'}';
      case 'streak':
        return 'Racha ≥ ${params['count'] ?? 0}';
      case 'consecutive_failures':
        return 'Reincidencia ≥ ${params['count'] ?? 0}';
      case 'battery_level':
        return 'Batería ${_batteryDirectionLabel(params)} ${params['percent'] ?? 0}%';
      case 'is_charging':
        return 'Cargando';
      case 'is_weekend':
        return 'Fin de semana';
      case 'block_apps':
        return 'Bloquear: ${params['appName'] ?? 'App'}';
      case 'unblock_apps':
        return 'Desbloquear: ${params['appName'] ?? 'App'}';
      case 'extend_limit':
        return 'Extender: ${params['minutes'] ?? 0} min';
      case 'reduce_block':
        return 'Reducir bloqueo: ${params['minutes'] ?? 0} min';
      case 'grant_reward':
        return 'Recompensa: +${params['baseMinutes'] ?? params['minutes'] ?? 0} min';
      case 'unlock_window':
        return 'Desbloqueo: ${params['baseMinutes'] ?? params['minutes'] ?? 0} min';
      case 'run_macro':
        return 'Ejecutar: ${params['macroName'] ?? 'Macro'}';
      case 'send_notification':
        return 'Notificar: ${params['message'] ?? ''}';
      case 'update_state':
        return 'Estado: ${params['key'] ?? ''}';
      default:
        return 'Nodo';
    }
  }

  String _nodeSummary(Map<String, dynamic> node) {
    final type = node['type']?.toString() ?? 'custom';
    final params = Map<String, dynamic>.from(node['params'] ?? {});
    switch (type) {
      case 'time_of_day':
        return 'Hora exacta';
      case 'day_of_week':
        return 'Días seleccionados';
      case 'app_opened':
        return 'Detecta apertura de app';
      case 'screen_time_checkpoint':
        return 'Intervalo de pantalla';
      case 'usage_exceeded':
      case 'usage_below':
        return 'Validador de uso';
      case 'device_inactive':
        return 'Inactividad del dispositivo';
      case 'time_range':
        return 'Ventana horaria';
      case 'usage_daily':
      case 'today_screen_time':
        return 'Uso por app';
      case 'streak':
      case 'consecutive_failures':
        return 'Estado persistente';
      case 'battery_level':
      case 'is_charging':
        return 'Estado de batería';
      case 'block_apps':
      case 'unblock_apps':
        return 'Gestión de bloqueo';
      case 'extend_limit':
      case 'reduce_block':
      case 'grant_reward':
      case 'unlock_window':
        return 'Ajusta límites';
      case 'send_notification':
        return 'Aviso al usuario';
      case 'update_state':
        return 'Estado interno';
      case 'multi_trigger':
      case 'multi_condition':
        final items = _normalizeNodeItems(params['items']);
        return '${items.length} items internos';
      case 'run_macro':
        return 'Ordena ejecución de otra macro';
      default:
        return '';
    }
  }

  IconData _nodeIcon(String type) {
    switch (type) {
      case 'time_of_day':
        return Icons.schedule_rounded;
      case 'day_of_week':
        return Icons.calendar_today_rounded;
      case 'app_opened':
        return Icons.apps_rounded;
      case 'screen_time_checkpoint':
      case 'usage_exceeded':
      case 'usage_below':
      case 'usage_daily':
      case 'today_screen_time':
        return Icons.timer_rounded;
      case 'device_inactive':
        return Icons.bedtime_rounded;
      case 'battery_level':
      case 'is_charging':
        return Icons.battery_charging_full;
      case 'streak':
        return Icons.local_fire_department;
      case 'consecutive_failures':
        return Icons.report_gmailerrorred;
      case 'block_apps':
        return Icons.block;
      case 'unblock_apps':
        return Icons.lock_open_rounded;
      case 'extend_limit':
        return Icons.add_alarm_rounded;
      case 'reduce_block':
        return Icons.remove_circle_outline;
      case 'grant_reward':
        return Icons.card_giftcard;
      case 'unlock_window':
        return Icons.lock_clock_rounded;
      case 'run_macro':
        return Icons.play_arrow_rounded;
      case 'send_notification':
        return Icons.notifications_active;
      case 'update_state':
        return Icons.tune_rounded;
      case 'multi_trigger':
      case 'multi_condition':
        return Icons.call_split_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Future<void> _showSimulation() async {
    final validationError = _validateNodes();
    if (validationError != null) {
      if (mounted) context.showSnack(validationError, isError: true);
      return;
    }
    final summary = <String, dynamic>{
      'name': _nameController.text.trim(),
      'type': _macroType,
      'priority': _priority,
      'triggers': _triggers.map(_displayNodeLabel).toList(),
      'conditions': _conditions.map(_displayNodeLabel).toList(),
      'actions': _actions.map(_displayNodeLabel).toList(),
    };
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Simulación local'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(summary),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _openParamEditor(
      String type, Map<String, dynamic> params) async {
    switch (type) {
      case 'multi_trigger':
        return _editMultiTrigger(params);
      case 'multi_condition':
        return _editMultiCondition(params);
      case 'time_of_day':
        final picked = await showTimePicker(
          context: context,
          initialTime: _timeFromParams(params, fallback: const TimeOfDay(hour: 8, minute: 0)),
          helpText: 'Hora del día',
        );
        if (picked == null) return null;
        return {'hour': picked.hour, 'minute': picked.minute};
      case 'day_of_week':
        return _editDays(params);
      case 'app_opened':
      case 'block_apps':
      case 'unblock_apps':
        return _pickApp(params);
      case 'screen_time_checkpoint':
        return _editUsageTarget(
          params,
          title: 'Checkpoint de pantalla',
          minutesLabel: 'Intervalo (min)',
        );
      case 'usage_exceeded':
        return _editUsageTarget(
          params,
          title: 'Uso excedido',
          minutesLabel: 'Minutos límite',
        );
      case 'usage_below':
        return _editUsageTarget(
          params,
          title: 'Uso por debajo',
          minutesLabel: 'Minutos máximo',
        );
      case 'device_inactive':
        return _editNumber(params, 'minutes', 'Minutos de inactividad', 15);
      case 'time_range':
        return _editTimeRange(params);
      case 'usage_daily':
        return _editUsageTarget(
          params,
          title: 'Uso diario',
          minutesLabel: 'Minutos diarios',
        );
      case 'today_screen_time':
        return _editUsageTarget(
          params,
          title: 'Pantalla hoy',
          minutesLabel: 'Minutos hoy',
        );
      case 'streak':
        return _editNumber(params, 'count', 'Racha mínima', 3);
      case 'consecutive_failures':
        return _editNumber(params, 'count', 'Reincidencia mínima', 2);
      case 'battery_level':
        return _editBatteryLevel(params);
      case 'is_charging':
        return params;
      case 'send_notification':
        return _editText(params, 'message', 'Mensaje');
      case 'grant_reward':
        return _editRewardAction(params, title: 'Recompensa avanzada');
      case 'unlock_window':
        return _editRewardAction(params, title: 'Desbloqueo temporal');
      case 'run_macro':
        return _pickMacroAction(params);
      case 'reduce_block':
        return _editNumber(params, 'minutes', 'Minutos a reducir', 10);
      case 'update_state':
        return _editKeyValue(params);
      default:
        return params;
    }
  }

  Future<Map<String, dynamic>?> _editNumber(
      Map<String, dynamic> params, String key, String label, int fallback) async {
    final controller = TextEditingController(
      text: (params[key] ?? fallback).toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Valor'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final value = int.tryParse(controller.text.trim()) ?? fallback;
    return {...params, key: value};
  }

  Future<Map<String, dynamic>?> _editText(
      Map<String, dynamic> params, String key, String label) async {
    final controller = TextEditingController(text: params[key]?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Texto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return {...params, key: controller.text.trim()};
  }

  Future<Map<String, dynamic>?> _editKeyValue(Map<String, dynamic> params) async {
    final keyController = TextEditingController(text: params['key']?.toString() ?? '');
    final valueController =
        TextEditingController(text: params['value']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Actualizar estado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(labelText: 'Clave'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(labelText: 'Valor'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return {
      ...params,
      'key': keyController.text.trim(),
      'value': valueController.text.trim(),
    };
  }

  Future<Map<String, dynamic>?> _editUsageTarget(
    Map<String, dynamic> params, {
    required String title,
    required String minutesLabel,
  }) async {
    final controller = TextEditingController(
      text: (params['minutes'] ?? 30).toString(),
    );
    Map<String, dynamic>? app;
    if (params['packageName'] != null) {
      app = {
        'packageName': params['packageName'],
        'appName': params['appName'] ?? params['packageName'],
      };
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickApp(params);
                  if (picked == null) return;
                  setState(() {
                    app = picked;
                  });
                },
                icon: const Icon(Icons.apps_rounded),
                label: Text(
                  app == null
                      ? 'Seleccionar app'
                      : (app?['appName'] ?? app?['packageName'] ?? 'App')
                          .toString(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: minutesLabel,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    final minutes = int.tryParse(controller.text.trim()) ?? 0;
    if (minutes <= 0 || app == null) return null;
    return {
      ...params,
      'minutes': minutes,
      'packageName': app?['packageName'],
      'appName': app?['appName'] ?? app?['packageName'],
    };
  }

  Future<Map<String, dynamic>?> _editBatteryLevel(
      Map<String, dynamic> params) async {
    String direction = (params['direction']?.toString() == 'at_or_above')
        ? 'at_or_above'
        : 'at_or_below';
    final controller = TextEditingController(
      text: (params['percent'] ?? 30).toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batería'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: direction,
              decoration: const InputDecoration(labelText: 'Dirección'),
              items: const [
                DropdownMenuItem(
                  value: 'at_or_below',
                  child: Text('Igual o menor'),
                ),
                DropdownMenuItem(
                  value: 'at_or_above',
                  child: Text('Igual o mayor'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                direction = value;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Porcentaje'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final percent = int.tryParse(controller.text.trim()) ?? 0;
    return {
      ...params,
      'direction': direction,
      'percent': percent,
    };
  }

  Future<Map<String, dynamic>?> _editTimeRange(
      Map<String, dynamic> params) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _timeFromParams(params, keyPrefix: 'start', fallback: const TimeOfDay(hour: 9, minute: 0)),
      helpText: 'Inicio',
    );
    if (start == null) return null;
    if (!mounted) return null;
    final end = await showTimePicker(
      context: context,
      initialTime: _timeFromParams(params, keyPrefix: 'end', fallback: const TimeOfDay(hour: 18, minute: 0)),
      helpText: 'Fin',
    );
    if (end == null) return null;
    return {
      ...params,
      'startHour': start.hour,
      'startMinute': start.minute,
      'endHour': end.hour,
      'endMinute': end.minute,
    };
  }

  Future<Map<String, dynamic>?> _editDays(Map<String, dynamic> params) async {
    final days = ((params['days'] as List<dynamic>?) ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toSet();
    final selected = {...days};
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Días de semana'),
        content: Wrap(
          spacing: 6,
          children: List.generate(7, (i) {
            final day = i + 1;
            final label = _dayLabel(day);
            final active = selected.contains(day);
            return FilterChip(
              label: Text(label),
              selected: active,
              onSelected: (value) {
                if (value) {
                  selected.add(day);
                } else {
                  selected.remove(day);
                }
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return {...params, 'days': selected.toList()};
  }

  Future<Map<String, dynamic>?> _pickApp(Map<String, dynamic> params) async {
    final app = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppPickerDialog(excludedPackages: <String>{}),
    );
    if (app == null) return null;
    return {
      ...params,
      'packageName': app['packageName'],
      'appName': app['appName'] ?? app['packageName'],
    };
  }

  String _formatTime(Map<String, dynamic> params) {
    final h = params['hour'] ?? params['startHour'] ?? 0;
    final m = params['minute'] ?? params['startMinute'] ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String _formatRange(Map<String, dynamic> params) {
    final sh = params['startHour'] ?? 0;
    final sm = params['startMinute'] ?? 0;
    final eh = params['endHour'] ?? 0;
    final em = params['endMinute'] ?? 0;
    return '${sh.toString().padLeft(2, '0')}:${sm.toString().padLeft(2, '0')}'
        ' - '
        '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
  }

  String _formatDays(Map<String, dynamic> params) {
    final days = ((params['days'] as List<dynamic>?) ?? [])
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .toList();
    if (days.isEmpty) return 'Todos';
    return days.map(_dayLabel).join(', ');
  }

  String _dayLabel(int day) {
    switch (day) {
      case 1:
        return 'Dom';
      case 2:
        return 'Lun';
      case 3:
        return 'Mar';
      case 4:
        return 'Mié';
      case 5:
        return 'Jue';
      case 6:
        return 'Vie';
      case 7:
        return 'Sáb';
      default:
        return '$day';
    }
  }

  TimeOfDay _timeFromParams(
    Map<String, dynamic> params, {
    String? keyPrefix,
    required TimeOfDay fallback,
  }) {
    final prefix = keyPrefix;
    final hKey = prefix == null ? 'hour' : '${prefix}Hour';
    final mKey = prefix == null ? 'minute' : '${prefix}Minute';
    final h = (params[hKey] as num?)?.toInt();
    final m = (params[mKey] as num?)?.toInt();
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  Widget _hintCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones recomendadas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _chip('Bloquear app'),
            const SizedBox(height: 6),
            _chip('Desbloquear app'),
            const SizedBox(height: 6),
            _chip('Extender límite'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Future<_NodeType?> _pickNodeType(String section) {
    final options = _nodeOptions(section);
    return showModalBottomSheet<_NodeType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section == 'trigger'
                  ? 'Agregar trigger'
                  : section == 'condition'
                      ? 'Agregar condición'
                      : 'Agregar acción',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Elige un tipo base para esta macro.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...options.map(
              (opt) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(opt.icon, color: AppColors.primary),
                title: Text(opt.label),
                onTap: () => Navigator.pop(context, opt),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_NodeType> _nodeOptions(String section) {
    if (section == 'trigger') {
      return const [
        _NodeType('multi_trigger', 'Multi-trigger', Icons.call_split_rounded),
        _NodeType('time_of_day', 'Hora del día', Icons.schedule_rounded),
        _NodeType('day_of_week', 'Día de semana', Icons.calendar_today_rounded),
        _NodeType('app_opened', 'App abierta', Icons.apps_rounded),
        _NodeType('screen_time_checkpoint', 'Checkpoint de pantalla', Icons.timer_rounded),
        _NodeType('usage_exceeded', 'Uso excedido', Icons.timelapse_rounded),
        _NodeType('usage_below', 'Uso por debajo', Icons.trending_down_rounded),
        _NodeType('battery_level', 'Batería', Icons.battery_charging_full),
        _NodeType('device_inactive', 'Inactividad', Icons.bedtime_rounded),
        _NodeType('manual', 'Manual', Icons.touch_app_rounded),
      ];
    }
    if (section == 'condition') {
      return const [
        _NodeType('multi_condition', 'Multi-condición', Icons.merge_type_rounded),
        _NodeType('time_range', 'Rango horario', Icons.timelapse_rounded),
        _NodeType('usage_daily', 'Uso diario', Icons.timer_rounded),
        _NodeType('today_screen_time', 'Pantalla hoy', Icons.timer_rounded),
        _NodeType('usage_below', 'Uso por debajo', Icons.trending_down_rounded),
        _NodeType('streak', 'Racha actual', Icons.local_fire_department),
        _NodeType('consecutive_failures', 'Reincidencia', Icons.report_gmailerrorred),
        _NodeType('battery_level', 'Batería', Icons.battery_charging_full),
        _NodeType('is_charging', 'Cargando', Icons.power),
        _NodeType('is_weekend', 'Fin de semana', Icons.weekend_rounded),
      ];
    }
    return const [
      _NodeType('block_apps', 'Bloquear app', Icons.block),
      _NodeType('unblock_apps', 'Desbloquear app', Icons.lock_open_rounded),
      _NodeType('extend_limit', 'Extender límite', Icons.add_alarm_rounded),
      _NodeType('reduce_block', 'Reducir bloqueo', Icons.remove_circle_outline),
      _NodeType('grant_reward', 'Recompensa avanzada', Icons.card_giftcard),
      _NodeType('unlock_window', 'Desbloqueo temporal', Icons.lock_clock_rounded),
      _NodeType('run_macro', 'Ejecutar macro', Icons.play_arrow_rounded),
      _NodeType('send_notification', 'Notificar', Icons.notifications_active),
      _NodeType('update_state', 'Actualizar estado', Icons.tune_rounded),
    ];
  }

  Future<Map<String, dynamic>?> _pickMacroAction(
      Map<String, dynamic> params) async {
    final macros = await NativeService.getAllMacros();
    final habits = await NativeService.getAllHabitMacros();
    final disciplines = await NativeService.getAllDisciplineMacros();
    final candidates = <_MacroRef>[];
    for (final macro in macros) {
      candidates.add(_MacroRef(
        id: macro['id']?.toString() ?? '',
        title: macro['name']?.toString() ?? 'Macro',
        kind: 'simple',
      ));
    }
    for (final macro in habits) {
      candidates.add(_MacroRef(
        id: macro['id']?.toString() ?? '',
        title: macro['name']?.toString() ?? 'Hábito',
        kind: 'habit',
      ));
    }
    for (final macro in disciplines) {
      candidates.add(_MacroRef(
        id: macro['id']?.toString() ?? '',
        title: macro['name']?.toString() ?? 'Disciplina',
        kind: 'discipline',
      ));
    }
    if (!mounted) return null;
    final picked = await showModalBottomSheet<_MacroRef>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MacroRunPickerSheet(items: candidates),
    );
    if (picked == null) return null;
    return {
      ...params,
      'macroId': picked.id,
      'macroKind': picked.kind,
      'macroName': picked.title,
    };
  }

  Future<Map<String, dynamic>?> _editRewardAction(
      Map<String, dynamic> params, {
        required String title,
      }) async {
    String policy = params['policy']?.toString() ?? 'fixed';
    final baseController = TextEditingController(
      text: (params['baseMinutes'] ?? params['minutes'] ?? 15).toString(),
    );
    final stepController = TextEditingController(
      text: (params['stepMinutes'] ?? 5).toString(),
    );
    final maxController = TextEditingController(
      text: (params['maxMinutes'] ?? 60).toString(),
    );
    final durationController = TextEditingController(
      text: (params['durationMinutes'] ?? 0).toString(),
    );
    Map<String, dynamic>? app;
    if (params['packageName'] != null) {
      app = {
        'packageName': params['packageName'],
        'appName': params['appName'] ?? params['packageName'],
      };
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickApp(params);
                    if (picked == null) return;
                    setState(() => app = picked);
                  },
                  icon: const Icon(Icons.apps_rounded),
                  label: Text(
                    app == null
                        ? 'Seleccionar app'
                        : (app?['appName'] ?? app?['packageName'] ?? 'App')
                            .toString(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: policy,
                  decoration: const InputDecoration(labelText: 'Política'),
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('Fija')),
                    DropdownMenuItem(
                      value: 'streak_progressive',
                      child: Text('Progresiva por racha'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => policy = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: baseController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutos base'),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (policy == 'streak_progressive') ...[
                  TextField(
                    controller: stepController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutos por racha'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Máximo'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duración (min, 0 = sin expirar)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return {
      ...params,
      'packageName': app?['packageName'],
      'appName': app?['appName'] ?? app?['packageName'],
      'policy': policy,
      'baseMinutes': int.tryParse(baseController.text.trim()) ?? 0,
      'stepMinutes': int.tryParse(stepController.text.trim()) ?? 0,
      'maxMinutes': int.tryParse(maxController.text.trim()) ?? 0,
      'durationMinutes': int.tryParse(durationController.text.trim()) ?? 0,
    };
  }

  List<Map<String, dynamic>> _normalizeNodeItems(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map((e) => {
                'type': e['type']?.toString() ?? 'custom',
                'label': e['label']?.toString(),
                'params': Map<String, dynamic>.from(e['params'] ?? {}),
              })
          .toList();
    }
    return [];
  }

  String _formatMultiTrigger(Map<String, dynamic> params) {
    final op = (params['operator']?.toString().toUpperCase() == 'AND') ? 'AND' : 'OR';
    final items = _normalizeNodeItems(params['items']);
    if (items.isEmpty) return 'Multi-trigger ($op)';
    final labels = items.map(_labelForItem).toList();
    final short = labels.take(3).join(', ');
    final suffix = labels.length > 3 ? '…' : '';
    return 'Multi-trigger ($op): $short$suffix';
  }

  String _formatMultiCondition(Map<String, dynamic> params) {
    final op = (params['operator']?.toString().toUpperCase() == 'AND') ? 'AND' : 'OR';
    final items = _normalizeNodeItems(params['items']);
    if (items.isEmpty) return 'Multi-condición ($op)';
    final labels = items.map(_labelForItem).toList();
    final short = labels.take(3).join(', ');
    final suffix = labels.length > 3 ? '…' : '';
    return 'Multi-condición ($op): $short$suffix';
  }

  String _batteryDirectionLabel(Map<String, dynamic> params) {
    final direction = params['direction']?.toString();
    if (direction == 'at_or_above') return '>=';
    return '<=';
  }

  String _labelForItem(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'custom';
    final params = Map<String, dynamic>.from(item['params'] ?? {});
    return _labelFor(type, params);
  }

  Future<Map<String, dynamic>?> _editMultiTrigger(
      Map<String, dynamic> params) async {
    String op = (params['operator']?.toString().toUpperCase() == 'AND') ? 'AND' : 'OR';
    final items = _normalizeNodeItems(params['items']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Multi-trigger'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: op,
                  decoration: const InputDecoration(labelText: 'Operador'),
                  items: const [
                    DropdownMenuItem(value: 'AND', child: Text('AND (todo)')),
                    DropdownMenuItem(value: 'OR', child: Text('OR (cualquiera)')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => op = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 220,
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'Agrega triggers internos',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, index) {
                            final item = items[index];
                            final error = _validateNode(item, allowMulti: false);
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: error == null
                                    ? AppColors.surfaceVariant.withValues(alpha: 0.35)
                                    : AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: error == null
                                      ? AppColors.surfaceVariant.withValues(alpha: 0.6)
                                      : AppColors.error.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _labelForItem(item),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (error != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            error,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      final type = item['type']?.toString() ?? 'custom';
                                      if (type == 'multi_trigger') return;
                                      final updated = await _openParamEditor(
                                        type,
                                        Map<String, dynamic>.from(item['params'] ?? {}),
                                      );
                                      if (updated == null) return;
                                      setState(() {
                                        items[index] = {
                                          ...item,
                                          'params': updated,
                                          'label': _labelFor(type, updated),
                                        };
                                      });
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => items.removeAt(index));
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await _pickInnerTriggerType();
                      if (picked == null) return;
                      setState(() {
                        items.add(makeNode(type: picked.type, label: picked.label));
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar trigger'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return {
      ...params,
      'operator': op,
      'items': items,
    };
  }

  Future<Map<String, dynamic>?> _editMultiCondition(
      Map<String, dynamic> params) async {
    String op = (params['operator']?.toString().toUpperCase() == 'AND') ? 'AND' : 'OR';
    final items = _normalizeNodeItems(params['items']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Multi-condición'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: op,
                  decoration: const InputDecoration(labelText: 'Operador'),
                  items: const [
                    DropdownMenuItem(value: 'AND', child: Text('AND (todo)')),
                    DropdownMenuItem(value: 'OR', child: Text('OR (cualquiera)')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => op = value);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 220,
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'Agrega condiciones internas',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, index) {
                            final item = items[index];
                            final error = _validateNode(item, allowMulti: false);
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: error == null
                                    ? AppColors.surfaceVariant.withValues(alpha: 0.35)
                                    : AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: error == null
                                      ? AppColors.surfaceVariant.withValues(alpha: 0.6)
                                      : AppColors.error.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _labelForItem(item),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (error != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            error,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      final type = item['type']?.toString() ?? 'custom';
                                      if (type == 'multi_condition') return;
                                      final updated = await _openParamEditor(
                                        type,
                                        Map<String, dynamic>.from(item['params'] ?? {}),
                                      );
                                      if (updated == null) return;
                                      setState(() {
                                        items[index] = {
                                          ...item,
                                          'params': updated,
                                          'label': _labelFor(type, updated),
                                        };
                                      });
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() => items.removeAt(index));
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await _pickInnerConditionType();
                      if (picked == null) return;
                      setState(() {
                        items.add(makeNode(type: picked.type, label: picked.label));
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar condición'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return null;
    return {
      ...params,
      'operator': op,
      'items': items,
    };
  }

  Future<_NodeType?> _pickInnerConditionType() {
    const options = [
      _NodeType('time_range', 'Rango horario', Icons.timelapse_rounded),
      _NodeType('usage_daily', 'Uso diario', Icons.timer_rounded),
      _NodeType('streak', 'Racha actual', Icons.local_fire_department),
      _NodeType('battery_level', 'Batería', Icons.battery_charging_full),
      _NodeType('is_weekend', 'Fin de semana', Icons.weekend_rounded),
    ];
    return showModalBottomSheet<_NodeType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar condición interna',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Usa estas condiciones dentro del multi-condición.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...options.map(
              (opt) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(opt.icon, color: AppColors.primary),
                title: Text(opt.label),
                onTap: () => Navigator.pop(context, opt),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<_NodeType?> _pickInnerTriggerType() {
    const options = [
      _NodeType('time_of_day', 'Hora del día', Icons.schedule_rounded),
      _NodeType('day_of_week', 'Día de semana', Icons.calendar_today_rounded),
      _NodeType('app_opened', 'App abierta', Icons.apps_rounded),
      _NodeType('device_inactive', 'Inactividad', Icons.bedtime_rounded),
      _NodeType('manual', 'Manual', Icons.touch_app_rounded),
    ];
    return showModalBottomSheet<_NodeType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agregar trigger interno',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Usa estos disparadores dentro del multi-trigger.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...options.map(
              (opt) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(opt.icon, color: AppColors.primary),
                title: Text(opt.label),
                onTap: () => Navigator.pop(context, opt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeType {
  final String type;
  final String label;
  final IconData icon;

  const _NodeType(this.type, this.label, this.icon);
}

class _FlowSection {
  final String title;
  final List<Map<String, dynamic>> items;

  _FlowSection(this.title, this.items);
}

class _MacroRef {
  final String id;
  final String title;
  final String kind;

  _MacroRef({required this.id, required this.title, required this.kind});
}

class _MacroRunPickerSheet extends StatelessWidget {
  const _MacroRunPickerSheet({required this.items});

  final List<_MacroRef> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Seleccionar macro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            Text(
              'No hay macros disponibles.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return ListTile(
                    title: Text(item.title),
                    trailing: Text(item.kind),
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


