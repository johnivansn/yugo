import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/screens/macro_editor_screen.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';
import 'package:yugo/utils/macro_schema.dart';

class HabitMacroListScreen extends StatefulWidget {
  const HabitMacroListScreen({super.key});

  @override
  State<HabitMacroListScreen> createState() => _HabitMacroListScreenState();
}

class _HabitMacroListScreenState extends State<HabitMacroListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await NativeService.getAllHabitMacros();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MacroEditorScreen(
          macroName: initial?['name']?.toString(),
          initialMacroType: 'HABIT_PERSISTENT',
          initial: initial,
        ),
      ),
    );
    if (ok == true) {
      await _load();
    }
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await NativeService.updateHabitMacro({
        ...item,
        'id': id,
        'isActive': !(item['isActive'] == true),
      });
      await _load();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _executeNow(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final rawState = item['stateJson']?.toString() ?? '{}';
      final state = jsonDecode(rawState) is Map
          ? Map<String, dynamic>.from(jsonDecode(rawState))
          : <String, dynamic>{};
      state['manualTriggerAt'] = DateTime.now().millisecondsSinceEpoch;
      await NativeService.updateHabitMacro({
        ...item,
        'id': id,
        'stateJson': jsonEncode(state),
      });
      await _load();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar hábito'),
        content: Text('¿Eliminar "${item['name'] ?? 'Hábito'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await NativeService.deleteHabitMacro(id);
      await _load();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Macros de Hábito'),
        actions: [
          IconButton(
            onPressed: _exportHabits,
            icon: const Icon(Icons.file_upload_rounded),
            tooltip: 'Exportar',
          ),
          IconButton(
            onPressed: _importHabits,
            icon: const Icon(Icons.file_download_rounded),
            tooltip: 'Importar',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.self_improvement, size: 52, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sin hábitos todavía',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Crea tu primera macro de hábito.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final item = _items[i];
        final isActive = item['isActive'] == true;
        return Card(
          child: ListTile(
            leading: Icon(
              isActive ? Icons.play_arrow : Icons.pause,
              color: isActive ? AppColors.success : AppColors.textTertiary,
            ),
            title: Text(
              item['name']?.toString() ?? 'Hábito',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _summaryLine(item, isActive),
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => _openEditor(initial: item),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'execute') _executeNow(item);
                if (value == 'toggle') _toggle(item);
                if (value == 'delete') _delete(item);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'execute',
                  child: Text('Ejecutar ahora'),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(isActive ? 'Desactivar' : 'Activar'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Eliminar',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _summaryLine(Map<String, dynamic> item, bool isActive) {
    final triggers = decodeMacroList(item['triggersJson']?.toString()).length;
    final conditions =
        decodeMacroList(item['conditionsJson']?.toString()).length;
    final actions = decodeMacroList(item['actionsJson']?.toString()).length;
    final status = isActive ? 'Activa' : 'Pausada';
    return '$status · T:$triggers C:$conditions A:$actions';
  }

  Future<void> _exportHabits() async {
    try {
      final res = await NativeService.exportHabitMacros();
      if (res['success'] != true) {
        if (mounted) context.showSnack('No se pudo exportar', isError: true);
        return;
      }
      final json = const JsonEncoder.withIndent('  ')
          .convert({'habits': res['habits'] ?? []});
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Exportar hábitos'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(json),
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
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _importHabits() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importar hábitos'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Pega aquí el JSON exportado',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final raw = controller.text.trim();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        if (mounted) context.showSnack('JSON inválido', isError: true);
        return;
      }
      final validation = validateHabitImportPayload(
        Map<String, dynamic>.from(decoded),
      );
      if (!validation.isValid) {
        if (mounted) {
          context.showSnack(
            'Importación inválida: ${validation.errors.first}',
            isError: true,
          );
        }
        return;
      }
      await NativeService.importHabitMacros(validation.payload);
      await _load();
      if (mounted) context.showSnack('Hábitos importados');
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }
}


