import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';
import 'package:yugo/utils/macro_schema.dart';

class MacroLibraryScreen extends StatefulWidget {
  const MacroLibraryScreen({super.key});

  @override
  State<MacroLibraryScreen> createState() => _MacroLibraryScreenState();
}

class _MacroLibraryScreenState extends State<MacroLibraryScreen> {
  bool _loading = true;
  String _search = '';
  String? _selectedCategory;
  String? _selectedTag;
  List<Map<String, dynamic>> _entries = [];
  final Map<String, Map<String, dynamic>> _macrosById = {};
  final Map<String, Map<String, dynamic>> _habitsById = {};
  final Map<String, Map<String, dynamic>> _disciplinesById = {};
  List<String> _categories = [];
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _entries = await NativeService.getMacroLibrary();
      final macros = await NativeService.getAllMacros();
      final habits = await NativeService.getAllHabitMacros();
      final disciplines = await NativeService.getAllDisciplineMacros();
      _macrosById
        ..clear()
        ..addEntries(macros.map((e) => MapEntry(e['id']?.toString() ?? '', e)));
      _habitsById
        ..clear()
        ..addEntries(habits.map((e) => MapEntry(e['id']?.toString() ?? '', e)));
      _disciplinesById
        ..clear()
        ..addEntries(
            disciplines.map((e) => MapEntry(e['id']?.toString() ?? '', e)));
      _categories = _entries
          .map((e) => e['category']?.toString() ?? 'general')
          .toSet()
          .where((e) => e.isNotEmpty)
          .toList()
        ..sort();
      _tags = _entries
          .expand((e) => _parseTags(e['tagsJson']?.toString()))
          .toSet()
          .where((e) => e.isNotEmpty)
          .toList()
        ..sort();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addFromMacro() async {
    try {
      final candidates = _buildCandidates();
      if (!mounted) return;
      final picked = await showModalBottomSheet<_LibraryCandidate>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _MacroPickerSheet(candidates: candidates),
      );
      if (picked == null) return;
      final payloadJson = jsonEncode(picked.payload);
      final tags = <String>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'macroId': picked.id,
        'title': picked.title,
        'macroKind': picked.kind,
        'category': 'general',
        'tagsJson': jsonEncode(tags),
        'payloadJson': payloadJson,
        'isSystem': false,
        'usageCount': 0,
        'createdAt': now,
      };
      await NativeService.addMacroLibraryEntry(payload);
      await _load();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    final id = entry['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar de biblioteca'),
        content: const Text('¿Eliminar esta macro de la biblioteca?'),
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
      await NativeService.deleteMacroLibraryEntry(id);
      await _load();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final categoryController =
        TextEditingController(text: entry['category']?.toString() ?? 'general');
    final tagsController = TextEditingController(
      text: _parseTags(entry['tagsJson']?.toString()).join(', '),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar biblioteca'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: tagsController,
              decoration:
                  const InputDecoration(labelText: 'Tags (separados por coma)'),
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
    if (ok != true) return;
    try {
      final updated = {
        ...entry,
        'category': categoryController.text.trim().isEmpty
            ? 'general'
            : categoryController.text.trim(),
        'tagsJson': jsonEncode(
          tagsController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList(),
        ),
      };
      await NativeService.updateMacroLibraryEntry(updated);
      await _load();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _useEntry(Map<String, dynamic> entry) async {
    try {
      final payloadJson = _resolvePayloadJson(entry);
      final macroKind = entry['macroKind']?.toString() ??
          _inferMacroKind(entry['macroId']?.toString());
      final res = await NativeService.createMacroFromLibraryPayload({
        'payloadJson': payloadJson,
        'macroKind': macroKind ?? 'simple',
      });
      if (res['success'] == true) {
        await _incrementUsage(entry);
        if (mounted) context.showSnack('Macro creada desde biblioteca');
      } else {
        if (mounted) context.showSnack('No se pudo crear', isError: true);
      }
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _incrementUsage(Map<String, dynamic> entry) async {
    final usage = (entry['usageCount'] as num?)?.toInt() ?? 0;
    final updated = {...entry, 'usageCount': usage + 1};
    await NativeService.updateMacroLibraryEntry(updated);
    await _load();
  }

  String _resolvePayloadJson(Map<String, dynamic> entry) {
    final raw = entry['payloadJson']?.toString();
    if (raw != null && raw.trim().isNotEmpty && raw.trim() != '{}') {
      return raw;
    }
    final id = entry['macroId']?.toString() ?? '';
    final kind = entry['macroKind']?.toString() ?? _inferMacroKind(id);
    final payload = _payloadFor(kind ?? 'simple', id);
    return jsonEncode(payload);
  }

  String? _inferMacroKind(String? macroId) {
    if (macroId == null || macroId.isEmpty) return null;
    if (_habitsById.containsKey(macroId)) return 'habit';
    if (_disciplinesById.containsKey(macroId)) return 'discipline';
    if (_macrosById.containsKey(macroId)) return 'simple';
    return null;
  }

  Map<String, dynamic> _payloadFor(String kind, String id) {
    if (kind == 'habit') return _habitsById[id] ?? {};
    if (kind == 'discipline') return _disciplinesById[id] ?? {};
    return _macrosById[id] ?? {};
  }

  List<_LibraryCandidate> _buildCandidates() {
    final list = <_LibraryCandidate>[];
    for (final macro in _macrosById.values) {
      list.add(_LibraryCandidate(
        id: macro['id']?.toString() ?? '',
        title: macro['name']?.toString() ?? 'Macro',
        kind: 'simple',
        payload: macro,
        subtitle: macro['description']?.toString() ?? '',
      ));
    }
    for (final macro in _habitsById.values) {
      list.add(_LibraryCandidate(
        id: macro['id']?.toString() ?? '',
        title: macro['name']?.toString() ?? 'Hábito',
        kind: 'habit',
        payload: macro,
        subtitle: 'Hábito persistente',
      ));
    }
    for (final macro in _disciplinesById.values) {
      list.add(_LibraryCandidate(
        id: macro['id']?.toString() ?? '',
        title: macro['name']?.toString() ?? 'Disciplina',
        kind: 'discipline',
        payload: macro,
        subtitle: 'Disciplina contextual',
      ));
    }
    return list;
  }

  List<Map<String, dynamic>> _filteredEntries() {
    return _entries.where((entry) {
      final title = _displayTitle(entry).toLowerCase();
      final queryOk = _search.isEmpty || title.contains(_search.toLowerCase());
      final category = entry['category']?.toString() ?? 'general';
      final categoryOk =
          _selectedCategory == null || _selectedCategory == category;
      final tags = _parseTags(entry['tagsJson']?.toString()).toSet();
      final tagOk = _selectedTag == null || tags.contains(_selectedTag);
      return queryOk && categoryOk && tagOk;
    }).toList();
  }

  String _displayTitle(Map<String, dynamic> entry) {
    final title = entry['title']?.toString();
    if (title != null && title.isNotEmpty) return title;
    final id = entry['macroId']?.toString() ?? '';
    final kind = _inferMacroKind(id);
    final payload = _payloadFor(kind ?? 'simple', id);
    return payload['name']?.toString() ?? id;
  }

  List<String> _parseTags(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Macros'),
        actions: [
          IconButton(
            onPressed: _exportLibrary,
            icon: const Icon(Icons.file_upload_rounded),
            tooltip: 'Exportar',
          ),
          IconButton(
            onPressed: _importLibrary,
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
        onPressed: _addFromMacro,
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
    final filtered = _filteredEntries();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.library_books_rounded,
                  size: 52, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sin macros guardadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Guarda tus macros para reutilizarlas.',
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                onChanged: (value) => setState(() => _search = value.trim()),
                decoration: const InputDecoration(
                  hintText: 'Buscar macro',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_categories.isNotEmpty) _buildFilterChips(
                label: 'Categorías',
                items: _categories,
                selected: _selectedCategory,
                onSelected: (value) => setState(() => _selectedCategory = value),
              ),
              if (_tags.isNotEmpty) _buildFilterChips(
                label: 'Tags',
                items: _tags,
                selected: _selectedTag,
                onSelected: (value) => setState(() => _selectedTag = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: filtered.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final entry = filtered[i];
              final tags = _parseTags(entry['tagsJson']?.toString());
              final category = entry['category']?.toString() ?? 'general';
              return Card(
                child: ListTile(
                  leading: Icon(Icons.bookmark, color: AppColors.primary),
                  title: Text(
                    _displayTitle(entry),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags
                                .map((tag) => _tagChip(tag))
                                .toList(),
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'use') _useEntry(entry);
                      if (value == 'edit') _editEntry(entry);
                      if (value == 'delete') _delete(entry);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'use', child: Text('Usar')),
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tag,
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildFilterChips({
    required String label,
    required List<String> items,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('Todas'),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
              ...items.map(
                (value) => FilterChip(
                  label: Text(value),
                  selected: selected == value,
                  onSelected: (_) => onSelected(value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportLibrary() async {
    try {
      final res = await NativeService.exportLibrary();
      final ok = res['success'] == true;
      if (!ok) {
        if (mounted) context.showSnack('No se pudo exportar', isError: true);
        return;
      }
      final json = const JsonEncoder.withIndent('  ').convert(res);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Exportar biblioteca'),
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

  Future<void> _importLibrary() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importar biblioteca'),
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
      final validation = validateLibraryImportPayload(
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
      await NativeService.importLibrary(validation.payload);
      await _load();
      if (mounted) context.showSnack('Biblioteca importada');
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }
}

class _LibraryCandidate {
  final String id;
  final String title;
  final String kind;
  final String subtitle;
  final Map<String, dynamic> payload;

  _LibraryCandidate({
    required this.id,
    required this.title,
    required this.kind,
    required this.payload,
    required this.subtitle,
  });
}

class _MacroPickerSheet extends StatelessWidget {
  const _MacroPickerSheet({required this.candidates});

  final List<_LibraryCandidate> candidates;

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
          if (candidates.isEmpty)
            Text(
              'No hay macros disponibles.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (_, i) {
                  final item = candidates[i];
                  return ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.subtitle),
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



