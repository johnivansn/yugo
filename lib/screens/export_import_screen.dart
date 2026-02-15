import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';
import 'dart:convert';

class ExportImportScreen extends StatefulWidget {
  const ExportImportScreen({super.key});

  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final json = await NativeService.exportConfig();
      if (json != null && mounted) {
        setState(() => _exporting = false);
        await Clipboard.setData(ClipboardData(text: json));
        if (mounted) context.showSnack('Configuración copiada al portapapeles');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        context.showSnack('Error al exportar', isError: true);
      }
    }
  }

  Future<void> _pasteAndImport() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) context.showSnack('Portapapeles vacío', isError: true);
      return;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        if (mounted) context.showSnack('JSON inválido', isError: true);
        return;
      }
      final validation = _validateConfigImport(
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
    } catch (_) {
      if (mounted) context.showSnack('JSON inválido', isError: true);
      return;
    }

    setState(() => _importing = true);
    try {
      final res = await NativeService.importConfig(text);
      if (!mounted) return;
      setState(() => _importing = false);

      final success = res['success'] as bool? ?? false;
      if (success) {
        final imported = res['imported'] as int? ?? 0;
        final skipped = res['skipped'] as int? ?? 0;
        final expiredAdjusted = res['expiredAdjusted'] as int? ?? 0;
        final usageMarked = res['usageMarked'] as int? ?? 0;
        if (skipped > 0) {
          context.showSnack('Importadas: $imported | Ya existían: $skipped');
        } else {
          context.showSnack(
              'Importadas $imported Bloqueo${imported == 1 ? '' : 'es'}');
        }
        if (expiredAdjusted > 0) {
          context.showSnack(
              'Se desactivaron $expiredAdjusted Bloqueos ya vencidos');
        }
        if (usageMarked > 0) {
          context.showSnack(
              'Se bloquearon $usageMarked Bloqueos por uso previo');
        }
      } else {
        context.showSnack(res['error'] as String? ?? 'Error desconocido',
            isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _importing = false);
        context.showSnack('Error al importar', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              pinned: true,
              title: Text('Export / Import'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 320;
                    final text = Text(
                      'Exporta y comparte tu configuración entre dispositivos o como respaldo',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    );
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.info, width: 1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.sync_rounded,
                                        color: AppColors.info, size: 18),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: text),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.sync_rounded,
                                    color: AppColors.info, size: 18),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: text),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'EXPORTAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 320;
                            final text = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exportar configuración',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Genera JSON con tus Bloqueos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            );
                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.md),
                                        ),
                                        child: Icon(
                                          Icons.upload_rounded,
                                          size: 20,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(child: text),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Icon(
                                    Icons.upload_rounded,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: text),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: FilledButton.icon(
                            onPressed: _exporting ? null : _export,
                            icon: _exporting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          AppColors.onColor(AppColors.primary),
                                    ),
                                  )
                                : const Icon(Icons.share_rounded, size: 18),
                            label: Text(
                                _exporting ? 'Exportando...' : 'Compartir'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'IMPORTAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 320;
                            final text = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Importar configuración',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Restaura desde JSON exportado',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            );
                            if (isCompact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: AppColors.success
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.md),
                                        ),
                                        child: Icon(
                                          Icons.download_rounded,
                                          size: 20,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(child: text),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: Icon(
                                    Icons.download_rounded,
                                    size: 20,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: text),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: FilledButton.icon(
                            onPressed: _importing ? null : _pasteAndImport,
                            icon: _importing
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          AppColors.onColor(AppColors.success),
                                    ),
                                  )
                                : const Icon(Icons.paste_rounded, size: 18),
                            label: Text(_importing
                                ? 'Importando...'
                                : 'Pegar del portapapeles'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor:
                                  AppColors.onColor(AppColors.success),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  'NOTAS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _noteItem(
                            'Las Bloqueos importadas no sobreescriben las existentes'),
                        const SizedBox(height: AppSpacing.sm),
                        _noteItem(
                            'El modo administrador (PIN) no se exporta por seguridad'),
                        const SizedBox(height: AppSpacing.sm),
                        _noteItem(
                            'Los contadores de uso diario no se exportan'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  Widget _noteItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded,
            color: AppColors.textTertiary, size: 16),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  _ConfigValidationResult _validateConfigImport(
    Map<String, dynamic> decoded,
  ) {
    final errors = <String>[];
    final version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version != 6) {
      errors.add('Versión no soportada: $version');
      return _ConfigValidationResult(false, errors);
    }
    final blocks = decoded['blocks'];
    if (blocks is! List) {
      errors.add('blocks debe ser lista');
      return _ConfigValidationResult(false, errors);
    }
    for (var i = 0; i < blocks.length; i++) {
      final item = blocks[i];
      if (item is! Map) {
        errors.add('blocks[$i] inválido');
        break;
      }
      final map = Map<String, dynamic>.from(item);
      final pkg = map['packageName']?.toString().trim() ?? '';
      if (pkg.isEmpty) {
        errors.add('blocks[$i] sin packageName');
        break;
      }
      final dailyQuota = map['dailyQuotaMinutes'];
      if (dailyQuota is! num || dailyQuota.toInt() < 0) {
        errors.add('blocks[$i] dailyQuotaMinutes inválido');
        break;
      }
      final limitType = map['limitType']?.toString() ?? 'daily';
      if (!['daily', 'weekly'].contains(limitType)) {
        errors.add('blocks[$i] limitType inválido');
        break;
      }
      final dailyMode = map['dailyMode']?.toString() ?? 'same';
      if (!['same', 'per_day'].contains(dailyMode)) {
        errors.add('blocks[$i] dailyMode inválido');
        break;
      }
      final dailyQuotas = map['dailyQuotas'];
      if (!_isValidDailyQuotas(dailyQuotas)) {
        errors.add('blocks[$i] dailyQuotas inválido');
        break;
      }
      final weeklyQuota = map['weeklyQuotaMinutes'];
      if (weeklyQuota is! num || weeklyQuota.toInt() < 0) {
        errors.add('blocks[$i] weeklyQuotaMinutes inválido');
        break;
      }
      if (!_isIntInRange(map['weeklyResetDay'], 1, 7)) {
        errors.add('blocks[$i] weeklyResetDay inválido');
        break;
      }
      if (!_isIntInRange(map['weeklyResetHour'], 0, 23)) {
        errors.add('blocks[$i] weeklyResetHour inválido');
        break;
      }
      if (!_isIntInRange(map['weeklyResetMinute'], 0, 59)) {
        errors.add('blocks[$i] weeklyResetMinute inválido');
        break;
      }
      final expiresAt = map['expiresAt'];
      if (expiresAt != null && expiresAt is! num) {
        errors.add('blocks[$i] expiresAt inválido');
        break;
      }
      final isEnabled = map['isEnabled'];
      if (isEnabled != null && isEnabled is! bool) {
        errors.add('blocks[$i] isEnabled inválido');
        break;
      }
    }

    final schedules = decoded['schedules'];
    if (schedules != null && schedules is! List) {
      errors.add('schedules debe ser lista');
    }
    if (schedules is List) {
      for (var i = 0; i < schedules.length; i++) {
        final item = schedules[i];
        if (item is! Map) {
          errors.add('schedules[$i] inválido');
          break;
        }
        final map = Map<String, dynamic>.from(item);
        final pkg = map['packageName']?.toString().trim() ?? '';
        if (pkg.isEmpty) {
          errors.add('schedules[$i] sin packageName');
          break;
        }
        if (!_isIntInRange(map['startHour'], 0, 23) ||
            !_isIntInRange(map['startMinute'], 0, 59) ||
            !_isIntInRange(map['endHour'], 0, 23) ||
            !_isIntInRange(map['endMinute'], 0, 59)) {
          errors.add('schedules[$i] horario inválido');
          break;
        }
        if (!_isIntInRange(map['daysOfWeek'], 0, 127)) {
          errors.add('schedules[$i] daysOfWeek inválido');
          break;
        }
        final isEnabled = map['isEnabled'];
        if (isEnabled != null && isEnabled is! bool) {
          errors.add('schedules[$i] isEnabled inválido');
          break;
        }
      }
    }

    final dateBlocks = decoded['dateBlocks'];
    if (dateBlocks != null && dateBlocks is! List) {
      errors.add('dateBlocks debe ser lista');
    }
    if (dateBlocks is List) {
      for (var i = 0; i < dateBlocks.length; i++) {
        final item = dateBlocks[i];
        if (item is! Map) {
          errors.add('dateBlocks[$i] inválido');
          break;
        }
        final map = Map<String, dynamic>.from(item);
        final pkg = map['packageName']?.toString().trim() ?? '';
        if (pkg.isEmpty) {
          errors.add('dateBlocks[$i] sin packageName');
          break;
        }
        final startDate = map['startDate']?.toString() ?? '';
        final endDate = map['endDate']?.toString() ?? '';
        if (!_isDate(startDate) || !_isDate(endDate)) {
          errors.add('dateBlocks[$i] fechas inválidas');
          break;
        }
        if (!_isIntInRange(map['startHour'], 0, 23) ||
            !_isIntInRange(map['startMinute'], 0, 59) ||
            !_isIntInRange(map['endHour'], 0, 23) ||
            !_isIntInRange(map['endMinute'], 0, 59)) {
          errors.add('dateBlocks[$i] horario inválido');
          break;
        }
        final isEnabled = map['isEnabled'];
        if (isEnabled != null && isEnabled is! bool) {
          errors.add('dateBlocks[$i] isEnabled inválido');
          break;
        }
      }
    }

    final templates = decoded['blockTemplates'];
    if (templates != null && templates is! List) {
      errors.add('blockTemplates debe ser lista');
    }
    if (templates is List) {
      for (var i = 0; i < templates.length; i++) {
        final item = templates[i];
        if (item is! Map) {
          errors.add('blockTemplates[$i] inválido');
          break;
        }
        final map = Map<String, dynamic>.from(item);
        final name = map['name']?.toString().trim() ?? '';
        final type = map['type']?.toString().trim() ?? '';
        final payloadJson = map['payloadJson']?.toString().trim() ?? '';
        if (name.isEmpty || type.isEmpty) {
          errors.add('blockTemplates[$i] nombre o tipo vacío');
          break;
        }
        if (!_isJson(payloadJson)) {
          errors.add('blockTemplates[$i] payloadJson inválido');
          break;
        }
      }
    }

    return _ConfigValidationResult(errors.isEmpty, errors);
  }

  bool _isIntInRange(dynamic value, int min, int max) {
    if (value is! num) return false;
    final v = value.toInt();
    return v >= min && v <= max;
  }

  bool _isDate(String value) {
    final exp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return exp.hasMatch(value);
  }

  bool _isJson(String value) {
    if (value.trim().isEmpty) return false;
    try {
      jsonDecode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isValidDailyQuotas(dynamic value) {
    if (value == null) return true;
    if (value is String) {
      if (value.trim().isEmpty) return true;
      final parts = value.split(',');
      for (final part in parts) {
        final pair = part.split(':');
        if (pair.length != 2) return false;
        final day = int.tryParse(pair[0]);
        final minutes = int.tryParse(pair[1]);
        if (day == null || minutes == null) return false;
        if (day < 1 || day > 7 || minutes < 0) return false;
      }
      return true;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        final day = int.tryParse(entry.key.toString());
        final minutes = entry.value is num
            ? (entry.value as num).toInt()
            : int.tryParse(entry.value.toString());
        if (day == null || minutes == null) return false;
        if (day < 1 || day > 7 || minutes < 0) return false;
      }
      return true;
    }
    return false;
  }
}

class _ConfigValidationResult {
  final bool isValid;
  final List<String> errors;

  const _ConfigValidationResult(this.isValid, this.errors);
}



