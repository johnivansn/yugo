import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/screens/app_picker_screen.dart';
import 'package:yugo/screens/block_edit_screen.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';

class DisciplineModeScreen extends StatefulWidget {
  const DisciplineModeScreen({super.key});

  @override
  State<DisciplineModeScreen> createState() => _DisciplineModeScreenState();
}

class _DisciplineModeScreenState extends State<DisciplineModeScreen> {
  final Map<String, Uint8List> _iconCache = {};
  final Set<String> _iconLoading = {};
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final List<_DisciplineTemplate> _templates = const [
    _DisciplineTemplate(
      id: 'workday',
      label: 'Laboral 9-18',
      startHour: 9,
      startMinute: 0,
      endHour: 18,
      endMinute: 0,
      daysOfWeek: [2, 3, 4, 5, 6],
    ),
    _DisciplineTemplate(
      id: 'evening',
      label: 'Noche 20-23',
      startHour: 20,
      startMinute: 0,
      endHour: 23,
      endMinute: 0,
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    ),
    _DisciplineTemplate(
      id: 'weekend',
      label: 'Fin de semana 10-22',
      startHour: 10,
      startMinute: 0,
      endHour: 22,
      endMinute: 0,
      daysOfWeek: [1, 7],
    ),
    _DisciplineTemplate(
      id: 'morning',
      label: 'Mañana 6-9',
      startHour: 6,
      startMinute: 0,
      endHour: 9,
      endMinute: 0,
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    ),
    _DisciplineTemplate(
      id: 'focus',
      label: 'Enfoque 14-18',
      startHour: 14,
      startMinute: 0,
      endHour: 18,
      endMinute: 0,
      daysOfWeek: [2, 3, 4, 5, 6],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDiscipline();
  }

  Future<void> _loadDiscipline() async {
    setState(() => _loading = true);
    final items = <Map<String, dynamic>>[];
    try {
      final packages = await NativeService.getDirectBlockPackages();
      for (final pkg in packages) {
        final name = await NativeService.getAppName(pkg) ?? pkg;
        int scheduleCount = 0;
        int scheduleActive = 0;
        int dateCount = 0;
        int dateActive = 0;
        try {
          final schedules = await NativeService.getSchedules(pkg);
          scheduleCount = schedules.length;
          scheduleActive =
              schedules.where((s) => (s['isEnabled'] as bool? ?? true)).length;
        } catch (_) {}
        try {
          final blocks = await NativeService.getDateBlocks(pkg);
          dateCount = blocks.length;
          dateActive =
              blocks.where((b) => (b['isEnabled'] as bool? ?? true)).length;
        } catch (_) {}
        items.add({
          'packageName': pkg,
          'appName': name,
          'scheduleCount': scheduleCount,
          'scheduleActiveCount': scheduleActive,
          'dateBlockCount': dateCount,
          'dateBlockActiveCount': dateActive,
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openEditor({
    required String appName,
    required String packageName,
    required bool isCreate,
  }) async {
    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => BlockEditScreen(
          appName: appName,
          packageName: packageName,
          isCreate: isCreate,
          initial: isCreate
              ? null
              : {
                  'packageName': packageName,
                  'appName': appName,
                },
          initialSection: 'direct',
          initialDirectTab: 'schedule',
        ),
      ),
    );
    await _loadDiscipline();
  }

  Future<void> _createDiscipline() async {
    final choice = await _pickCreateMode();
    if (choice == null || !mounted) return;
    final existing = _items.map((e) => e['packageName'] as String).toSet();
    final app = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(excludedPackages: existing),
      ),
    );
    if (app == null || !mounted) return;
    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => BlockEditScreen(
          appName: app['appName'] as String,
          packageName: app['packageName'] as String,
          isCreate: true,
          initialSection: 'direct',
          initialDirectTab: choice,
        ),
      ),
    );
    await _loadDiscipline();
  }

  Future<String?> _pickCreateMode() {
    return showModalBottomSheet<String>(
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
              'Nuevo bloqueo de disciplina',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Elige el tipo de contexto que quieres definir.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _choiceTile(
              icon: Icons.schedule_rounded,
              title: 'Horario',
              subtitle: 'Bloquea por días y horas',
              onTap: () => Navigator.pop(context, 'schedule'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _choiceTile(
              icon: Icons.event_rounded,
              title: 'Fecha',
              subtitle: 'Bloquea por rango de fechas',
              onTap: () => Navigator.pop(context, 'date'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _applyTemplate(_DisciplineTemplate template) async {
    final app = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const AppPickerScreen(
          excludedPackages: <String>{},
        ),
      ),
    );
    if (app == null || !mounted) return;
    final pkg = app['packageName'] as String;
    final name = app['appName'] as String;
    try {
      await NativeService.addSchedule({
        'packageName': pkg,
        'startHour': template.startHour,
        'startMinute': template.startMinute,
        'endHour': template.endHour,
        'endMinute': template.endMinute,
        'daysOfWeek': template.daysOfWeek,
        'isEnabled': true,
      });
      if (mounted) {
        context.showSnack('Disciplina aplicada a $name');
      }
      await _loadDiscipline();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _deleteDiscipline(Map<String, dynamic> item) async {
    final pkg = item['packageName']?.toString();
    if (pkg == null || pkg.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar disciplina'),
        content: Text('¿Eliminar "${item['appName'] ?? pkg}"?'),
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
    if (confirmed != true) return;
    try {
      await NativeService.deleteDirectBlocks(pkg);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e['packageName'] == pkg);
      });
      context.showSnack('Disciplina eliminada');
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final active = _items.where((item) {
      final scheduleActive = (item['scheduleActiveCount'] as int?) ?? 0;
      final dateActive = (item['dateBlockActiveCount'] as int?) ?? 0;
      return scheduleActive > 0 || dateActive > 0;
    }).length;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _summaryCard(total, active)),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(child: _emptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
                sliver: SliverList.separated(
                  itemCount: _items.length,
                  itemBuilder: (_, i) => _disciplineCard(_items[i]),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createDiscipline,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Modo Disciplina',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadDiscipline,
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bloqueos contextuales sin macros persistentes.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 1,
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          _templateRow(),
        ],
      ),
    );
  }

  Widget _summaryCard(int total, int active) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  label: 'Totales',
                  value: total.toString(),
                ),
              ),
              Expanded(
                child: _summaryMetric(
                  label: 'Activas',
                  value: active.toString(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryMetric({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _templateRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLANTILLAS RÁPIDAS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _templates
              .map(
                (template) => OutlinedButton(
                  onPressed: () => _applyTemplate(template),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(template.label),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _choiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_clock_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin disciplina todavía',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Crea tu primer bloqueo contextual.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _disciplineCard(Map<String, dynamic> item) {
    final scheduleCount = (item['scheduleCount'] as int?) ?? 0;
    final scheduleActive = (item['scheduleActiveCount'] as int?) ?? 0;
    final dateCount = (item['dateBlockCount'] as int?) ?? 0;
    final dateActive = (item['dateBlockActiveCount'] as int?) ?? 0;
    final active = scheduleActive > 0 || dateActive > 0;
    final statusLabel = active ? 'ACTIVA' : 'PAUSADA';
    final statusColor = active ? AppColors.success : AppColors.textSecondary;

    return Card(
      child: ListTile(
        leading: _buildAppIcon(item),
        title: Text(
          item['appName']?.toString() ?? 'App',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                _pill('Horarios', scheduleCount, scheduleActive),
                _pill('Fechas', dateCount, dateActive),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _openEditor(
          appName: item['appName']?.toString() ?? 'App',
          packageName: item['packageName']?.toString() ?? '',
          isCreate: false,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _openEditor(
                appName: item['appName']?.toString() ?? 'App',
                packageName: item['packageName']?.toString() ?? '',
                isCreate: false,
              );
            }
            if (value == 'delete') {
              _deleteDiscipline(item);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
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
  }

  Widget _pill(String label, int total, int active) {
    final text = '$label: $active/$total';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildAppIcon(Map<String, dynamic> item) {
    final pkg = item['packageName'] as String?;
    final cached = pkg != null ? _iconCache[pkg] : null;
    final bytes = cached ?? item['iconBytes'];
    if (bytes is Uint8List && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    if (pkg != null && !_iconLoading.contains(pkg)) {
      _iconLoading.add(pkg);
      NativeService.getAppIcon(pkg).then((icon) {
        if (!mounted) return;
        if (icon != null && icon.isNotEmpty) {
          setState(() {
            _iconCache[pkg] = icon;
            item['iconBytes'] = icon;
          });
        }
      }).whenComplete(() => _iconLoading.remove(pkg));
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.lock_clock_rounded,
        size: 20,
        color: AppColors.textTertiary,
      ),
    );
  }
}

class _DisciplineTemplate {
  final String id;
  final String label;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final List<int> daysOfWeek;

  const _DisciplineTemplate({
    required this.id,
    required this.label,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.daysOfWeek,
  });
}


