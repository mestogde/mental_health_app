import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFEEEEEE);
  static const Color surface = Color(0xFFF7F7F7);
  static const Color textDark = Color(0xFF191919);
  static const Color pinkAccent = Color(0xFFF1D4D4);
  static const Color yellowAccent = Color(0xFFF7D784);
  static const Color blueAccent = Color(0xFFA8CDEA);
  static const Color greenStatus = Color(0xFFC5EEC8);
  static const Color greyStatus = Color(0xFFAFAFAF);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final textTheme = GoogleFonts.golosTextTextTheme().apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );

    const colorScheme = ColorScheme.light(
      primary: AppColors.textDark,
      secondary: AppColors.pinkAccent,
      surface: AppColors.surface,
      error: Color(0xFFB3261E),
      onPrimary: Colors.white,
      onSecondary: AppColors.textDark,
      onSurface: AppColors.textDark,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      colorScheme: colorScheme.copyWith(surfaceTint: Colors.transparent),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blueAccent,
          foregroundColor: AppColors.textDark,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
