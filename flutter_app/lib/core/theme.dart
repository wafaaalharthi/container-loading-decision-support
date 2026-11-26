import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF080C1C);
  static const bgDeep = Color(0xFF050817);
  static const panel = Color(0xFF101A35);
  static const panel2 = Color(0xFF0D1630);
  static const border = Color(0xFF253D81);
  static const text = Color(0xFFF3F6FF);
  static const muted = Color(0xFFA0AFD1);
  static const cyan = Color(0xFF63E7FF);
  static const green = Color(0xFF66ECC0);
  static const warn = Color(0xFFFFC27A);
  static const danger = Color(0xFFFF8597);
  static const blue = Color(0xFF2F6BFF);
  static const violet = Color(0xFF873FFF);

  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blue, violet],
  );

  // Category colors (same order as the prototype pie chart)
  static const categories = <String, Color>{
    'electronics': Color(0xFF3987E5),
    'glass': Color(0xFFD95926),
    'iron_metal': Color(0xFF199E70),
    'machinery': Color(0xFFC98500),
    'wood_furniture': Color(0xFFD55181),
    'food': Color(0xFF0CA30C),
    'textiles': Color(0xFFE66767),
    'paper': Color(0xFF9085E9),
    'other': Color(0xFF7D879F),
  };

  // Box group colors (B01, B02, ... same order as the prototype)
  static const groupPalette = [
    Color(0xFF498BFF), Color(0xFFFF9D55), Color(0xFF50E5AA), Color(0xFFFFD25E),
    Color(0xFFFF71B3), Color(0xFFAF79FF), Color(0xFF4FD6E8), Color(0xFFFF7A7A),
    Color(0xFFA6E05A), Color(0xFFF2A6FF), Color(0xFF8FB0FF), Color(0xFFFFB86B),
  ];

  static Color group(String code) {
    final n = int.tryParse(code.replaceAll(RegExp(r'\D'), '')) ?? 1;
    return groupPalette[(n - 1) % groupPalette.length];
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.blue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.blue,
    secondary: AppColors.cyan,
    surface: AppColors.panel,
    onSurface: AppColors.text,
    error: AppColors.danger,
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel2,
      labelStyle: const TextStyle(color: AppColors.muted),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.6),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.bg,
      indicatorColor: AppColors.blue.withValues(alpha: 0.25),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          color: states.contains(WidgetState.selected) ? AppColors.cyan : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.cyan : AppColors.muted,
        ),
      ),
    ),
    dividerColor: AppColors.border,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.panel,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
