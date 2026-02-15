import 'package:flutter/material.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';
import 'package:yugo/widgets/app_picker_dialog.dart';

class MacroListScreen extends StatefulWidget {
  const MacroListScreen({super.key});

  @override
  State<MacroListScreen> createState() => _MacroListScreenState();
}

class _MacroListScreenState extends State<MacroListScreen> {
  List<Map<String, dynamic>> _macros = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMacros();
  }

  Future<void> _loadMacros() async {
    setState(() => _loading = true);
    try {
      _macros = await NativeService.getAllMacros();
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _pickApp() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AppPickerDialog(
        excludedPackages: <String>{},
      ),
    );
  }

  Future<void> _createMacro() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String actionType = 'limit';
    String macroType = 'BLOCK';
    Map<String, dynamic>? app;
    final minutesController = TextEditingController(text: '30');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva macro'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: actionType,
                items: const [
                  DropdownMenuItem(
                    value: 'limit',
                    child: Text('Bloqueo: limitar app'),
                  ),
                  DropdownMenuItem(
                    value: 'extend',
                    child: Text('Recompensa: extender tiempo'),
                  ),
                  DropdownMenuItem(
                    value: 'unblock',
                    child: Text('Recompensa: desbloquear app'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => actionType = value);
                },
                decoration: const InputDecoration(
                  labelText: 'Acción',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _pickApp();
                  if (picked == null || !mounted) return;
                  setDialogState(() => app = picked);
                },
                icon: const Icon(Icons.apps_rounded),
                label: Text(
                  app == null
                      ? 'Seleccionar app'
                      : (app?['appName'] ?? app?['packageName'] ?? 'App')
                          .toString(),
                ),
              ),
              if (actionType == 'limit' || actionType == 'extend') ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: actionType == 'extend'
                        ? 'Minutos extra'
                        : 'Minutos diarios',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) context.showSnack('Nombre requerido', isError: true);
      return;
    }
    if (app == null) {
      if (mounted) context.showSnack('Selecciona una app', isError: true);
      return;
    }
    final minutes = int.tryParse(minutesController.text) ?? 30;
    if (actionType == 'limit') {
      macroType = 'BLOCK';
    } else if (actionType == 'extend' || actionType == 'unblock') {
      macroType = 'REWARD';
    } else {
      macroType = 'CUSTOM';
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      'id': '$now',
      'name': name,
      'description': descController.text.trim(),
      'isActive': true,
      'createdAt': now,
      'macroType': macroType,
      'actionType': actionType,
      'packageName': app?['packageName'],
      'appName': app?['appName'] ?? app?['packageName'],
      'minutes': minutes,
    };
    try {
      await NativeService.createMacro(payload);
      await _loadMacros();
      if (mounted) context.showSnack('Macro creada');
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _deleteMacro(Map<String, dynamic> macro) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar macro'),
        content: Text(
          '¿Eliminar "${macro['name'] ?? 'Macro'}"?',
        ),
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
    final id = macro['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await NativeService.deleteMacro(id);
      await _loadMacros();
      if (mounted) context.showSnack('Macro eliminada');
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _toggleMacro(Map<String, dynamic> macro) async {
    final current = macro['isActive'] == true;
    final id = macro['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await NativeService.toggleMacroActive(id, !current);
      await _loadMacros();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _executeMacro(Map<String, dynamic> macro) async {
    final type = macro['actionType']?.toString() ?? 'limit';
    final pkg = macro['packageName']?.toString();
    final appName = macro['appName']?.toString() ?? pkg ?? 'App';
    final macroId = macro['id']?.toString() ?? '';
    if (pkg == null || pkg.isEmpty) {
      if (mounted) context.showSnack('Macro sin app asociada', isError: true);
      return;
    }
    try {
      if (type == 'unblock' || type == 'unlock') {
        await NativeService.deleteBlock(pkg);
        if (mounted) {
          context.showSnack('Bloqueo removida: $appName');
        }
        if (macroId.isNotEmpty) {
          await NativeService.emitEvent({
            'macroId': macroId,
            'type': 'macro_executed',
            'title': 'Desbloqueo ejecutado',
            'message': 'Se desbloqueó $appName',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
        return;
      }
      final minutes = (macro['minutes'] as num?)?.toInt() ?? 30;
      if (type == 'extend') {
        final blocks = await NativeService.getBlocks();
        final existing = blocks.firstWhere(
          (r) => r['packageName']?.toString() == pkg,
          orElse: () => {},
        );
        if (existing.isNotEmpty) {
          final current = (existing['dailyQuotaMinutes'] as num?)?.toInt() ?? 0;
          await NativeService.updateBlock({
            'packageName': pkg,
            'dailyQuotaMinutes': current + minutes,
            'isEnabled': true,
            'limitType': 'daily',
            'dailyMode': 'same',
            'dailyQuotas': {},
            'weeklyQuotaMinutes': 0,
            'weeklyResetDay': 2,
            'weeklyResetHour': 0,
            'weeklyResetMinute': 0,
            'expiresAt': null,
          });
          if (mounted) {
            context.showSnack('Tiempo extendido: $appName (+$minutes min)');
          }
          if (macroId.isNotEmpty) {
            await NativeService.emitEvent({
              'macroId': macroId,
              'type': 'macro_executed',
              'title': 'Recompensa aplicada',
              'message': 'Se extendió $appName +$minutes min',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
          return;
        }
      }
      await NativeService.addBlock({
        'packageName': pkg,
        'appName': appName,
        'dailyQuotaMinutes': minutes,
        'isEnabled': true,
        'limitType': 'daily',
        'dailyMode': 'same',
        'dailyQuotas': {},
        'weeklyQuotaMinutes': 0,
        'weeklyResetDay': 2,
        'weeklyResetHour': 0,
        'weeklyResetMinute': 0,
        'expiresAt': null,
      });
      if (mounted) {
        context.showSnack(
          type == 'extend'
              ? 'Tiempo extendido: $appName (+$minutes min)'
              : type == 'unblock' || type == 'unlock'
                  ? 'Bloqueo removida: $appName'
                  : 'Bloqueo aplicada: $appName',
        );
      }
      if (macroId.isNotEmpty) {
        await NativeService.emitEvent({
          'macroId': macroId,
          'type': 'macro_executed',
          'title': 'Bloqueo aplicado',
          'message': 'Se limitó $appName a $minutes min/día',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Macros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMacros,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _createMacro,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text('Cargando macros...'),
          ],
        ),
      );
    }

    if (_macros.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Sin macros todavía',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Crea tu primera automatización.',
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

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: _macros.length,
      itemBuilder: (context, index) {
        final macro = _macros[index];
        final isActive = macro['isActive'] == true;
        final type = macro['actionType']?.toString() ?? 'limit';
        final appName = macro['appName']?.toString() ?? '';
        final minutes = (macro['minutes'] as num?)?.toInt() ?? 30;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isActive ? AppColors.success : AppColors.surfaceVariant,
              child: Icon(
                isActive ? Icons.play_arrow : Icons.pause,
                color: AppColors.onColor(
                  isActive ? AppColors.success : AppColors.surfaceVariant,
                ),
              ),
            ),
            title: Text(
              macro['name']?.toString() ?? 'Macro',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              macro['description']?.toString().isNotEmpty == true
                  ? macro['description'].toString()
                  : (type == 'unblock' || type == 'unlock'
                      ? 'Desbloquear $appName'
                      : type == 'extend'
                          ? 'Extender $appName +$minutes min/día'
                          : 'Limitar $appName a $minutes min/día'),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle') _toggleMacro(macro);
                if (value == 'execute') _executeMacro(macro);
                if (value == 'delete') _deleteMacro(macro);
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
}





