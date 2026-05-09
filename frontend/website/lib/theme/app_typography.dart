import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme textTheme(TextTheme base, Color primary, Color secondary) {
    final outfit = GoogleFonts.outfitTextTheme(base);
    return outfit.copyWith(
      displayMedium: outfit.displayMedium?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.6, color: primary,
      ),
      headlineMedium: outfit.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700, color: primary,
      ),
      titleLarge: outfit.titleLarge?.copyWith(
        fontWeight: FontWeight.w600, color: primary,
      ),
      bodyLarge: outfit.bodyLarge?.copyWith(color: primary),
      bodyMedium: outfit.bodyMedium?.copyWith(color: secondary),
      labelLarge: outfit.labelLarge?.copyWith(
        fontWeight: FontWeight.w600, color: primary,
      ),
    );
  }
}
