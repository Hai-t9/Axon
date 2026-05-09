import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme textTheme(TextTheme base, Color primary, Color secondary) {
    final sora = GoogleFonts.soraTextTheme(base);
    return sora.copyWith(
      displayMedium: sora.displayMedium?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.6, color: primary,
      ),
      headlineMedium: sora.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700, color: primary,
      ),
      titleLarge: sora.titleLarge?.copyWith(
        fontWeight: FontWeight.w600, color: primary,
      ),
      bodyLarge: sora.bodyLarge?.copyWith(color: primary),
      bodyMedium: sora.bodyMedium?.copyWith(color: secondary),
      labelLarge: sora.labelLarge?.copyWith(
        fontWeight: FontWeight.w600, color: primary,
      ),
    );
  }
}
