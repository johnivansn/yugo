import 'dart:convert';

List<Map<String, dynamic>> decodeMacroList(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  } catch (_) {}
  return [];
}

String encodeMacroList(List<Map<String, dynamic>> items) {
  return jsonEncode(items);
}

Map<String, dynamic> makeNode({
  required String type,
  required String label,
  Map<String, dynamic>? params,
}) {
  return {
    'type': type,
    'label': label,
    'params': params ?? <String, dynamic>{},
  };
}

const List<String> kTriggerTypes = [
  'multi_trigger',
  'time_of_day',
  'day_of_week',
  'app_opened',
  'screen_time_checkpoint',
  'usage_exceeded',
  'usage_below',
  'battery_level',
  'device_inactive',
  'manual',
];

const List<String> kConditionTypes = [
  'multi_condition',
  'time_range',
  'usage_daily',
  'today_screen_time',
  'usage_below',
  'streak',
  'consecutive_failures',
  'battery_level',
  'is_charging',
  'is_weekend',
];

const List<String> kActionTypes = [
  'block_apps',
  'unblock_apps',
  'extend_limit',
  'reduce_block',
  'grant_reward',
  'unlock_window',
  'run_macro',
  'send_notification',
  'update_state',
];

const Map<String, List<String>> kRequiredParams = {
  'time_of_day': ['hour'],
  'day_of_week': ['days'],
  'app_opened': ['packageName'],
  'screen_time_checkpoint': ['packageName', 'minutes'],
  'usage_exceeded': ['packageName', 'minutes'],
  'usage_below': ['packageName', 'minutes'],
  'battery_level': ['percent'],
  'device_inactive': ['minutes'],
  'time_range': ['startHour', 'endHour'],
  'usage_daily': ['packageName', 'minutes'],
  'today_screen_time': ['packageName', 'minutes'],
  'streak': ['count'],
  'consecutive_failures': ['count'],
  'block_apps': ['packageName'],
  'unblock_apps': ['packageName'],
  'extend_limit': ['packageName', 'minutes'],
  'reduce_block': ['packageName', 'minutes'],
  'grant_reward': ['packageName', 'baseMinutes'],
  'unlock_window': ['packageName', 'baseMinutes'],
  'run_macro': ['macroId'],
  'send_notification': ['message'],
  'update_state': ['key'],
};

bool isNodeTypeAllowed(String type, String section) {
  switch (section) {
    case 'trigger':
      return kTriggerTypes.contains(type);
    case 'condition':
      return kConditionTypes.contains(type);
    case 'action':
      return kActionTypes.contains(type);
    default:
      return false;
  }
}

List<String> validateNodeSchema(String type, Map<String, dynamic> params) {
  final required = kRequiredParams[type] ?? const <String>[];
  final missing = <String>[];
  for (final key in required) {
    if (!params.containsKey(key) || params[key] == null || key.isEmpty) {
      missing.add(key);
    }
  }
  return missing;
}

class MacroImportValidationResult {
  final bool isValid;
  final Map<String, dynamic> payload;
  final List<String> errors;

  const MacroImportValidationResult({
    required this.isValid,
    required this.payload,
    required this.errors,
  });
}

MacroImportValidationResult validateHabitImportPayload(
  Map<String, dynamic> decoded,
) {
  return _validateStructuredImport(
    decoded,
    key: 'habits',
    expectedMacroType: 'HABIT_PERSISTENT',
  );
}

MacroImportValidationResult validateDisciplineImportPayload(
  Map<String, dynamic> decoded,
) {
  return _validateStructuredImport(
    decoded,
    key: 'disciplines',
    expectedMacroType: 'DISCIPLINE',
  );
}

MacroImportValidationResult validateLibraryImportPayload(
  Map<String, dynamic> decoded,
) {
  final errors = <String>[];
  final payload = <String, dynamic>{};
  final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
  if (schemaVersion > 1) {
    errors.add('schemaVersion no soportado');
  }

  final library = decoded['library'];
  if (library != null && library is! List) {
    errors.add('library debe ser lista');
  }
  final macros = decoded['macros'];
  if (macros != null && macros is! List) {
    errors.add('macros debe ser lista');
  }
  final habits = decoded['habits'];
  if (habits != null && habits is! List) {
    errors.add('habits debe ser lista');
  }
  final disciplines = decoded['disciplines'];
  if (disciplines != null && disciplines is! List) {
    errors.add('disciplines debe ser lista');
  }
  if (errors.isNotEmpty) {
    return MacroImportValidationResult(
      isValid: false,
      payload: const {},
      errors: errors,
    );
  }

  payload['library'] = _normalizeLibraryList(library as List? ?? [], errors);
  payload['macros'] = _normalizeMacroList(macros as List? ?? [], errors);
  payload['habits'] = _normalizeStructuredList(
    habits as List? ?? [],
    errors,
    expectedMacroType: 'HABIT_PERSISTENT',
  );
  payload['disciplines'] = _normalizeStructuredList(
    disciplines as List? ?? [],
    errors,
    expectedMacroType: 'DISCIPLINE',
  );
  payload['schemaVersion'] = schemaVersion;

  return MacroImportValidationResult(
    isValid: errors.isEmpty,
    payload: payload,
    errors: errors,
  );
}

MacroImportValidationResult _validateStructuredImport(
  Map<String, dynamic> decoded, {
  required String key,
  required String expectedMacroType,
}) {
  final errors = <String>[];
  final payload = <String, dynamic>{};
  final list = decoded[key];
  if (list is! List) {
    return MacroImportValidationResult(
      isValid: false,
      payload: const {},
      errors: ['$key debe ser lista'],
    );
  }
  payload[key] = _normalizeStructuredList(
    list,
    errors,
    expectedMacroType: expectedMacroType,
  );
  return MacroImportValidationResult(
    isValid: errors.isEmpty,
    payload: payload,
    errors: errors,
  );
}

List<Map<String, dynamic>> _normalizeStructuredList(
  List raw,
  List<String> errors, {
  required String expectedMacroType,
}) {
  final list = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) {
      errors.add('Macro inválida');
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final name = map['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      errors.add('Macro sin nombre');
      continue;
    }
    final macroType = map['macroType']?.toString();
    if (macroType != null &&
        macroType.isNotEmpty &&
        macroType != expectedMacroType) {
      errors.add('macroType inválido: $macroType');
      continue;
    }
    final triggersJson =
        _ensureJsonList(map['triggersJson'], 'triggersJson', errors);
    final conditionsJson =
        _ensureJsonList(map['conditionsJson'], 'conditionsJson', errors);
    final actionsJson =
        _ensureJsonList(map['actionsJson'], 'actionsJson', errors);
    map['triggersJson'] = triggersJson;
    map['conditionsJson'] = conditionsJson;
    map['actionsJson'] = actionsJson;
    _validateNodesFromJson(triggersJson, 'trigger', 'triggersJson', errors);
    _validateNodesFromJson(conditionsJson, 'condition', 'conditionsJson', errors);
    _validateNodesFromJson(actionsJson, 'action', 'actionsJson', errors);
    map['stateJson'] = _ensureJsonObject(map['stateJson'], 'stateJson', errors);
    map['isActive'] = map['isActive'] is bool ? map['isActive'] : true;
    map['priority'] = (map['priority'] as num?)?.toInt() ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    map['createdAt'] = (map['createdAt'] as num?)?.toInt() ?? now;
    map['updatedAt'] = (map['updatedAt'] as num?)?.toInt() ?? now;
    list.add(map);
  }
  return list;
}

List<Map<String, dynamic>> _normalizeMacroList(List raw, List<String> errors) {
  final list = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) {
      errors.add('Macro simple inválida');
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final name = map['name']?.toString().trim() ?? '';
    if (name.isEmpty) {
      errors.add('Macro simple sin nombre');
      continue;
    }
    final macroType = map['macroType']?.toString() ?? 'CUSTOM';
    if (macroType.trim().isEmpty) {
      errors.add('macroType inválido');
      continue;
    }
    final actionType = map['actionType']?.toString();
    if (actionType != null &&
        actionType.isNotEmpty &&
        !['limit', 'extend', 'unblock', 'unlock'].contains(actionType)) {
      errors.add('actionType inválido: $actionType');
      continue;
    }
    final minutes = (map['minutes'] as num?)?.toInt();
    if (minutes != null && minutes < 0) {
      errors.add('minutes inválidos');
      continue;
    }
    map['isActive'] = map['isActive'] is bool ? map['isActive'] : true;
    map['macroType'] = macroType;
    final now = DateTime.now().millisecondsSinceEpoch;
    map['createdAt'] = (map['createdAt'] as num?)?.toInt() ?? now;
    map['updatedAt'] = (map['updatedAt'] as num?)?.toInt() ?? now;
    list.add(map);
  }
  return list;
}

List<Map<String, dynamic>> _normalizeLibraryList(
  List raw,
  List<String> errors,
) {
  final list = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) {
      errors.add('Entrada de biblioteca inválida');
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    map['macroId'] ??= '';
    map['title'] ??= map['name'] ?? '';
    map['macroKind'] ??= 'simple';
    map['category'] ??= 'general';
    final category = map['category']?.toString().trim() ?? '';
    if (category.isEmpty) {
      errors.add('Entrada de biblioteca sin categoría');
      continue;
    }
    final macroKind = map['macroKind']?.toString() ?? 'simple';
    if (!['simple', 'habit', 'discipline'].contains(macroKind)) {
      errors.add('macroKind inválido: $macroKind');
      continue;
    }
    if (map['tagsJson'] == null && map['tags'] is List) {
      map['tagsJson'] = jsonEncode(map['tags']);
    }
    map['tagsJson'] ??= '[]';
    if (!_isJsonArray(map['tagsJson']?.toString() ?? '[]')) {
      errors.add('tagsJson inválido');
      continue;
    }
    if (map['payloadJson'] == null && map['payload'] is Map) {
      map['payloadJson'] = jsonEncode(map['payload']);
    }
    map['payloadJson'] ??= '{}';
    final payloadJson = map['payloadJson']?.toString() ?? '{}';
    final payload = _decodeJsonObject(payloadJson);
    if (payload == null) {
      errors.add('payloadJson inválido');
      continue;
    }
    final payloadErrors = _validateLibraryPayload(payload, macroKind);
    if (payloadErrors.isNotEmpty) {
      errors.add(payloadErrors.first);
      continue;
    }
    map['isSystem'] ??= false;
    map['usageCount'] = (map['usageCount'] as num?)?.toInt() ?? 0;
    map['createdAt'] =
        (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    list.add(map);
  }
  return list;
}

List<String> _validateLibraryPayload(
  Map<String, dynamic> payload,
  String macroKind,
) {
  if (macroKind == 'simple') {
    return _validateSimpleMacroMap(payload);
  }
  if (macroKind == 'habit') {
    return _validateStructuredMacroMap(payload, 'HABIT_PERSISTENT');
  }
  if (macroKind == 'discipline') {
    return _validateStructuredMacroMap(payload, 'DISCIPLINE');
  }
  return ['macroKind inválido'];
}

List<String> _validateStructuredMacroMap(
  Map<String, dynamic> map,
  String expectedMacroType,
) {
  final errors = <String>[];
  final name = map['name']?.toString().trim() ?? '';
  if (name.isEmpty) {
    errors.add('Macro sin nombre');
    return errors;
  }
  final macroType = map['macroType']?.toString();
  if (macroType != null &&
      macroType.isNotEmpty &&
      macroType != expectedMacroType) {
    errors.add('macroType inválido: $macroType');
    return errors;
  }
  final triggersJson =
      _ensureJsonList(map['triggersJson'], 'triggersJson', errors);
  final conditionsJson =
      _ensureJsonList(map['conditionsJson'], 'conditionsJson', errors);
  final actionsJson =
      _ensureJsonList(map['actionsJson'], 'actionsJson', errors);
  _validateNodesFromJson(triggersJson, 'trigger', 'triggersJson', errors);
  _validateNodesFromJson(conditionsJson, 'condition', 'conditionsJson', errors);
  _validateNodesFromJson(actionsJson, 'action', 'actionsJson', errors);
  _ensureJsonObject(map['stateJson'], 'stateJson', errors);
  return errors;
}

List<String> _validateSimpleMacroMap(Map<String, dynamic> map) {
  final errors = <String>[];
  final name = map['name']?.toString().trim() ?? '';
  if (name.isEmpty) {
    errors.add('Macro sin nombre');
    return errors;
  }
  final macroType = map['macroType']?.toString() ?? 'CUSTOM';
  if (macroType.trim().isEmpty) {
    errors.add('macroType inválido');
    return errors;
  }
  final actionType = map['actionType']?.toString();
  if (actionType != null &&
      actionType.isNotEmpty &&
      !['limit', 'extend', 'unblock', 'unlock'].contains(actionType)) {
    errors.add('actionType inválido: $actionType');
    return errors;
  }
  final minutes = (map['minutes'] as num?)?.toInt();
  if (minutes != null && minutes < 0) {
    errors.add('minutes inválidos');
  }
  return errors;
}

String _ensureJsonList(dynamic raw, String field, List<String> errors) {
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return raw;
      errors.add('$field debe ser lista');
      return '[]';
    } catch (_) {
      errors.add('$field inválido');
      return '[]';
    }
  }
  if (raw is List) {
    return jsonEncode(raw);
  }
  errors.add('$field inválido');
  return '[]';
}

String _ensureJsonObject(dynamic raw, String field, List<String> errors) {
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return raw;
      errors.add('$field debe ser objeto');
      return '{}';
    } catch (_) {
      errors.add('$field inválido');
      return '{}';
    }
  }
  if (raw is Map) {
    return jsonEncode(raw);
  }
  return '{}';
}

void _validateNodesFromJson(
  String raw,
  String section,
  String field,
  List<String> errors,
) {
  final list = decodeMacroList(raw);
  for (var i = 0; i < list.length; i++) {
    final node = list[i];
    final type = node['type']?.toString() ?? '';
    final label = node['label']?.toString() ?? '';
    if (type.isEmpty) {
      errors.add('$field[$i] sin type');
      continue;
    }
    if (!isNodeTypeAllowed(type, section)) {
      errors.add('$field[$i] type no permitido: $type');
      continue;
    }
    if (label.isEmpty) {
      errors.add('$field[$i] sin label');
      continue;
    }
    final rawParams = node['params'];
    Map<String, dynamic> params;
    if (rawParams == null) {
      params = <String, dynamic>{};
    } else if (rawParams is Map) {
      params = Map<String, dynamic>.from(rawParams);
    } else {
      errors.add('$field[$i] params inválidos');
      continue;
    }
    final missing = validateNodeSchema(type, params);
    if (missing.isNotEmpty) {
      errors.add('$field[$i] missing: ${missing.join(', ')}');
    }
  }
}

bool _isJsonArray(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is List;
  } catch (_) {
    return false;
  }
}

Map<String, dynamic>? _decodeJsonObject(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return null;
}


