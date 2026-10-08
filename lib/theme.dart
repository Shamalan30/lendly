import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFFAF9F6);
  static const ink = Color(0xFF111111);
  static const grey = Color(0xFF8A8A8E);
  static const line = Color(0xFFEAE8E3);
  static const green = Color(0xFF2F7D5B);
  static const greenSoft = Color(0xFFE6F2EC);
  static const orange = Color(0xFFE59A3C);
  static const orangeSoft = Color(0xFFFCF1E2);
  static const red = Color(0xFFD9534F);
  static const redSoft = Color(0xFFFBE9E8);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green),
    scaffoldBackgroundColor: AppColors.bg,
  );
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c),
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.green),
    ),
  );
}
