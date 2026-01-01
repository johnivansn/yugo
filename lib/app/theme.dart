import 'package:flutter/material.dart';

class AppTheme {
  // Colors from React mockup
  static const Color bgGrafito = Color(0xFF0F1115);
  static const Color bgOscuro = Color(0xFF1C1F26);
  static const Color bgMedio = Color(0xFF2A2F3A);
  static const Color textPrincipal = Color(0xFFE6E8EB);
  static const Color textSecundario = Color(0xFF9AA0A6);
  static const Color success = Color(0xFF3CB371);
  static const Color error = Color(0xFFC0392B);
  static const Color warning = Color(0xFFF39C12);
  static const Color primaryBlue = Color(0xFF4A6CF7);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgGrafito,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: bgMedio,
        surface: bgOscuro,
        error: error,
        onPrimary: textPrincipal,
        onSecondary: textPrincipal,
        onSurface: textPrincipal,
        onError: textPrincipal,
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: bgOscuro,
        foregroundColor: textPrincipal,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrincipal,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: bgOscuro,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: bgMedio, width: 1),
        ),
      ),

      // Text Theme
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrincipal,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrincipal,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: textPrincipal,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrincipal,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrincipal,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: textPrincipal,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrincipal,
          fontSize: 16,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: TextStyle(
          color: textSecundario,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        bodySmall: TextStyle(
          color: textSecundario,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: TextStyle(
          color: textPrincipal,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: textSecundario,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: textSecundario,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: textPrincipal,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrincipal,
          side: const BorderSide(color: bgMedio, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgOscuro,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: bgMedio, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: bgMedio, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryBlue, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: textSecundario),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: textSecundario, size: 24),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: bgMedio,
        thickness: 1,
        space: 1,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgOscuro,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textSecundario,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
