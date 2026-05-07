import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTypography {
  static TextTheme textTheme(TextTheme base) {
    final sora = GoogleFonts.soraTextTheme(base);
    return sora.copyWith(
      displayMedium: sora.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.textPrimary,
      ),
      headlineMedium: sora.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: sora.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: sora.bodyLarge?.copyWith(color: AppColors.textPrimary),
      bodyMedium: sora.bodyMedium?.copyWith(color: AppColors.textSecondary),
      labelLarge: sora.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
