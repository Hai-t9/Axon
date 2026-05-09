import 'package:flutter/material.dart';

class AppColors {
  // Mobile App Theme Colors
  static const primary = Color(0xFF5F75EE);
  static const primaryDark = Color(0xFF5F75EE);
  
  static const background = Color(0xFF1C1C28);
  static const surface = Color(0xFF252536);
  static const surfaceAlt = Color(0xFF252536);
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white70;
  static const border = Color(0xFF3A3A50);
  static const accent = Color(0xFF5F75EE);
  
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const shadow = Color(0x19000000);

  // Dark Theme (Same as above)
  static const darkBackground = Color(0xFF1C1C28);
  static const darkSurface = Color(0xFF252536);
  static const darkSurfaceAlt = Color(0xFF252536);
  static const darkTextPrimary = Colors.white;
  static const darkTextSecondary = Colors.white70;
  static const darkBorder = Color(0xFF3A3A50);
  static const darkPrimary = Color(0xFF5F75EE);
  static const darkError = Color(0xFFEF4444);

  // Helpers (Force mobile dark theme)
  static Color backgroundFor(BuildContext context) => background;
  static Color surfaceFor(BuildContext context) => surface;
  static Color surfaceAltFor(BuildContext context) => surfaceAlt;
  static Color borderFor(BuildContext context) => border;
}
