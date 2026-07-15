import 'package:flutter/material.dart';

class AppTheme {
  // ASHA Saathi Production Theme
  // Utilizing Material 3. Primary: Deep Green for Healthcare Trust.

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1B5E20), // Green 900
        secondary: const Color(0xFF0277BD), // Light Blue 800
        tertiary: const Color(0xFFF9A825), // Amber 800 for warnings
        error: const Color(0xFFD32F2F), // Red 700 for emergencies
      ),
      fontFamily: 'Inter', // Fallback, will use system font natively
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4CAF50), // Green 500
        brightness: Brightness.dark,
        secondary: const Color(0xFF29B6F6),
      ),
    );
  }
}
