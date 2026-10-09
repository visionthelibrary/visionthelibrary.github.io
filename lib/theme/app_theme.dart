import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color backgroundTop = Color(0xFF0F172A);
  static const Color backgroundMiddle = Color(0xFF1E3A8A);
  static const Color backgroundBottom = Color(0xFF2563EB);

  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.backgroundMiddle,
        brightness: Brightness.dark,
      ),
    );
  }
}
