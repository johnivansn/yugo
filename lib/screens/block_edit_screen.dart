import 'package:flutter/material.dart';
import 'package:yugo/theme/app_theme.dart';
import 'package:yugo/widgets/limit_picker_dialog.dart';

class BlockEditScreen extends StatelessWidget {
  const BlockEditScreen({
    super.key,
    required this.appName,
    this.packageName,
    this.initial,
    this.isCreate = false,
    this.initialSection = 'limit',
    this.initialDirectTab = 'schedule',
  });

  final String appName;
  final String? packageName;
  final Map<String, dynamic>? initial;
  final bool isCreate;
  final String initialSection;
  final String initialDirectTab;

  @override
  Widget build(BuildContext context) {
    if (initialSection == 'direct') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: LimitPickerDialog(
          appName: appName,
          initial: initial,
          fullScreen: true,
          useEditLayoutForCreate: isCreate,
          packageName: packageName,
          initialSection: initialSection,
          initialDirectTab: initialDirectTab,
        ),
      );
    }

    return _SimpleLimitEditor(
      appName: appName,
      packageName: packageName,
      initial: initial,
      isCreate: isCreate,
    );
  }
}

class _SimpleLimitEditor extends StatefulWidget {
  const _SimpleLimitEditor({
    required this.appName,
    this.packageName,
    this.initial,
    this.isCreate = false,
  });

  final String appName;
  final String? packageName;
  final Map<String, dynamic>? initial;
  final bool isCreate;

  @override
  State<_SimpleLimitEditor> createState() => _SimpleLimitEditorState();
}

class _SimpleLimitEditorState extends State<_SimpleLimitEditor> {
  late final TextEditingController _minutesController;
  bool _enabled = true;
  int? _expiresAt;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? {};
    final minutes = (initial['dailyQuotaMinutes'] as num?)?.toInt() ?? 30;
    _minutesController = TextEditingController(
      text: minutes > 0 ? minutes.toString() : '30',
    );
    _enabled = (initial['isEnabled'] as bool?) ?? true;
    final raw = initial['expiresAt'];
    _expiresAt = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    if (minutes < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El límite debe ser mayor o igual a 1 minuto.'),
        ),
      );
      return;
    }
    Navigator.pop(context, {
      'dailyQuotaMinutes': minutes,
      'limitType': 'daily',
      'dailyMode': 'same',
      'dailyQuotas': {},
      'weeklyQuotaMinutes': 0,
      'weeklyResetDay': 2,
      'weeklyResetHour': 0,
      'weeklyResetMinute': 0,
      'expiresAt': _expiresAt,
      'schedulesChanged': false,
      'dateBlocksChanged': false,
      'isEnabled': _enabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Límite diario'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.appName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.packageName ?? '',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Minutos por día',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Ej. 30',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
              title: const Text('Bloqueo activa'),
              subtitle: const Text('Pausa o reactiva esta automatización.'),
              contentPadding: EdgeInsets.zero,
            ),
            const Spacer(),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}



