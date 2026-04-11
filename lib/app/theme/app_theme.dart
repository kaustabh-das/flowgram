import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary:          AppColors.accentPurple,
        secondary:        AppColors.accentCyan,
        tertiary:         AppColors.accentGradEnd,
        surface:          AppColors.surfaceMid,
        error:            AppColors.error,
        onPrimary:        AppColors.textPrimary,
        onSecondary:      AppColors.background,
        onSurface:        AppColors.textPrimary,
        onError:          AppColors.textPrimary,
        outline:          AppColors.divider,
        surfaceContainerHighest: AppColors.surfaceLight,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.accentPurple,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.accentPurple.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.accentPurple);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = textTheme.labelSmall!;
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(color: AppColors.accentPurple);
          }
          return style.copyWith(color: AppColors.textSecondary);
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceMid,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPurple,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          highlightColor: AppColors.surfaceGlass,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceMid,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accentPurple,
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.outfitTextTheme(base).copyWith(
      displayLarge:  _style(57, FontWeight.w700),
      displayMedium: _style(45, FontWeight.w700),
      displaySmall:  _style(36, FontWeight.w600),
      headlineLarge: _style(32, FontWeight.w700),
      headlineMedium:_style(28, FontWeight.w600),
      headlineSmall: _style(24, FontWeight.w600),
      titleLarge:    _style(22, FontWeight.w600),
      titleMedium:   _style(16, FontWeight.w500),
      titleSmall:    _style(14, FontWeight.w500),
      bodyLarge:     _style(16, FontWeight.w400),
      bodyMedium:    _style(14, FontWeight.w400),
      bodySmall:     _style(12, FontWeight.w400),
      labelLarge:    _style(14, FontWeight.w600),
      labelMedium:   _style(12, FontWeight.w500),
      labelSmall:    _style(11, FontWeight.w500),
    );
  }

  static TextStyle _style(double size, FontWeight weight) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );
}
