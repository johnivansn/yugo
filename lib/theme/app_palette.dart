import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.primary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final Color primary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  static const Color seed = Color(0xFFAF5330);
  static const Color accent = Color(0xFFFFC23F);
  static const Color brandDanger = Color(0xFF5F2022);
  static const Color brandSuccess = Color(0xFFED8139);
  static const Color brandWarning = Color(0xFFFFC23F);

  static const light = AppPalette(
    primary: Color(0xFFAF5330),
    success: brandSuccess,
    warning: brandWarning,
    error: brandDanger,
    info: Color(0xFF803328),
    background: Color(0xFFFFC23F),
    surface: Color(0xFFED8139),
    surfaceVariant: Color(0xFFAF5330),
    textPrimary: Color(0xFF5F2022),
    textSecondary: Color(0xFF803328),
    textTertiary: Color(0xFFAF5330),
  );

  static const dark = AppPalette(
    primary: Color(0xFFED8139),
    success: brandSuccess,
    warning: brandWarning,
    error: Color(0xFFAF5330),
    info: Color(0xFFAF5330),
    background: Color(0xFF16090A),
    surface: Color(0xFF241112),
    surfaceVariant: Color(0xFF331616),
    textPrimary: Color(0xFFF8E5C1),
    textSecondary: Color(0xFFFFC23F),
    textTertiary: Color(0xFFED8139),
  );
}


