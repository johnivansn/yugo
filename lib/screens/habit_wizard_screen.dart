import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';
import 'package:yugo/utils/macro_schema.dart';
import 'package:yugo/widgets/app_picker_dialog.dart';

class HabitWizardScreen extends StatefulWidget {
  const HabitWizardScreen({super.key});

  @override
  State<HabitWizardScreen> createState() => _HabitWizardScreenState();
}

class _HabitWizardScreenState extends State<HabitWizardScreen> {
  final _nameController = TextEditingController();
  final _limitController = TextEditingController(text: '30');
  final _rewardController = TextEditingController(text: '15');
  Map<String, dynamic>? _app;
  int _step = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _pickApp() async {
    final app = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppPickerDialog(excludedPackages: <String>{}),
    );
    if (app == null) return;
    setState(() {
      _app = {
        'packageName': app['packageName'],
        'appName': app['appName'] ?? app['packageName'],
      };
    });
  }

  bool _validateStep(int step) {
    if (step == 0) {
      return _nameController.text.trim().isNotEmpty && _app != null;
    }
    if (step == 1) {
      final limit = int.tryParse(_limitController.text.trim()) ?? 0;
      final reward = int.tryParse(_rewardController.text.trim()) ?? 0;
      return limit > 0 && reward >= 0;
    }
    return true;
  }

  Future<void> _create() async {
    if (_app == null) return;
    final name = _nameController.text.trim();
    final limit = int.tryParse(_limitController.text.trim()) ?? 0;
    final reward = int.tryParse(_rewardController.text.trim()) ?? 0;
    if (name.isEmpty || limit <= 0) {
      context.showSnack('Completa los datos requeridos', isError: true);
      return;
    }
    final triggers = [
      makeNode(
        type: 'time_of_day',
        label: 'Hora: 23:59',
        params: {'hour': 23, 'minute': 59},
      ),
    ];
    final conditions = [
      makeNode(
        type: 'usage_below',
        label: 'Uso por debajo: $limit min',
        params: {
          'minutes': limit,
          'packageName': _app?['packageName'],
          'appName': _app?['appName'],
        },
      ),
    ];
    final actions = [
      makeNode(
        type: 'grant_reward',
        label: 'Recompensa: +$reward min',
        params: {
          'packageName': _app?['packageName'],
          'appName': _app?['appName'],
          'policy': 'fixed',
          'baseMinutes': reward,
          'durationMinutes': 0,
        },
      ),
    ];
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'name': name,
      'isActive': true,
      'macroType': 'HABIT_PERSISTENT',
      'priority': 1,
      'triggersJson': jsonEncode(triggers),
      'conditionsJson': jsonEncode(conditions),
      'actionsJson': jsonEncode(actions),
      'stateJson': '{}',
      'createdAt': now,
      'updatedAt': now,
    };
    try {
      await NativeService.createHabitMacro(payload);
      if (mounted) {
        context.showSnack('Hábito creado');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo Simple'),
      ),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (!_validateStep(_step)) {
            context.showSnack('Completa este paso', isError: true);
            return;
          }
          if (_step == 2) {
            _create();
          } else {
            setState(() => _step += 1);
          }
        },
        onStepCancel: () {
          if (_step == 0) {
            Navigator.pop(context);
          } else {
            setState(() => _step -= 1);
          }
        },
        controlsBuilder: (context, details) {
          final isLast = _step == 2;
          return Row(
            children: [
              FilledButton(
                onPressed: details.onStepContinue,
                child: Text(isLast ? 'Crear' : 'Continuar'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: details.onStepCancel,
                child: const Text('Atrás'),
              ),
            ],
          );
        },
        steps: [
          Step(
            title: const Text('Nombre y app'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.editing,
            content: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del hábito',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _pickApp,
                  icon: const Icon(Icons.apps_rounded),
                  label: Text(
                    _app == null
                        ? 'Seleccionar app'
                        : (_app?['appName'] ?? _app?['packageName']).toString(),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Reglas básicas'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.editing,
            content: Column(
              children: [
                TextField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Uso máximo diario (min)',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _rewardController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Recompensa (min)',
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Resumen'),
            isActive: _step >= 2,
            state: StepState.editing,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryRow('Nombre', _nameController.text.trim()),
                _summaryRow(
                  'App',
                  (_app?['appName'] ?? _app?['packageName'] ?? '').toString(),
                ),
                _summaryRow('Límite', '${_limitController.text.trim()} min'),
                _summaryRow('Recompensa', '${_rewardController.text.trim()} min'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Regla: si el uso diario está por debajo del límite, se otorga la recompensa.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}


