import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF2A2D35);
  static const Color surface = Color(0xFF32363F);
  static const Color surfaceVariant = Color(0xFF3A3E49);
  static const Color blue = Color(0xFF4A9EFF);
  static const Color red = Color(0xFFCF6679);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color divider = Color(0xFF3E424C);
  static const Color keyboardBackground = Color(0xFF1E2028);
  static const Color keyboardKey = Color(0xFF3A3E49);
  static const Color completedGreen = Color(0xFF1E3A2E);
  static const Color checkGreen = Color(0xFF4CAF50);
  static const Color green = Color(0xFF26DE81);
  static const Color orange = Color(0xFFFF9F43);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.blue,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.blue,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
        dividerColor: AppColors.divider,
      );
}
