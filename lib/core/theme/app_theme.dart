import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Soft light yellow — primary brand accent.
  static const Color lightYellow = Color(0xFFFFF1A8);

  /// Deeper warm yellow for gradient end / accents.
  static const Color warmYellow = Color(0xFFFFE066);

  /// Soft cream-yellow page wash.
  static const Color softCream = Color(0xFFFFFBF0);

  /// Backward-compatible aliases.
  static const Color lightOrange = lightYellow;
  static const Color yellow = warmYellow;

  static const Color navy = Color(0xFF001A54);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mutedBlue = Color(0xFF5A6B8C);
  static const Color orange = Color(0xFFE8A317);
  static const Color purple = Color(0xFF7B2D8E);
  static const Color blue = Color(0xFF0072CE);
  static const Color green = Color(0xFF2E8540);
  static const Color red = Color(0xFFD32F2F);
  static const Color cardPink = Color(0xFFFFF8E7);
  static const Color darkGray = Color(0xFF424242);
  static const Color pageBackground = softCream;
  static const Color navLabel = Color(0xFF5A6B8C);

  /// Brand header / splash gradient (light yellow → warm yellow → cream).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF8D6),
      lightYellow,
      warmYellow,
    ],
  );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF8D6),
      softCream,
      Color(0xFFFFFDF8),
    ],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.warmYellow,
        primary: AppColors.navy,
        secondary: AppColors.warmYellow,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: AppColors.pageBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightYellow,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.navy, width: 1.5),
        ),
      ),
    );
  }
}
