class AppConstants {
  AppConstants._();

  static const String appName = 'Yugo';
  static const String appVersion = '0.1.0-alpha';
  static const String appDescription =
      'Sistema de automatización de hábitos con penalizaciones inteligentes';
  static const String hiveBoxSettings = 'settings_box';

  static const String currentPhase = 'Fase 1 - Core Funcional';
  static const String currentSprint = 'Sprint 1 - Motor de Macros (COMPLETE ✅)';
  static const String nextSprint = 'Sprint 2 - Persistencia + Continuidad';
  static const List<String> implementedFeatures = [
    '+ Modelos de datos (Habit, Validator, Penalty, Macro, Streak, Log)',
    '+ Motor de macros (IF evento + condiciones THEN acciones)',
    '+ Sistema de eventos (Event Dispatcher)',
    '+ Persistencia local (Hive)',
    '+ Logging de ejecución',
    '+ Arquitectura Clean (Domain, Data, Services)',
  ];
}
