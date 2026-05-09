import 'package:flutter/material.dart';

class AppColors {
  // Primary (Professional Purple)
  static const primary = Color(0xFF7C3AED); // Violet 600
  static const primaryDark = Color(0xFF5B21B6); // Violet 800
  
  // Light Theme
  static const background = Color(0xFFF5F3FF); // Violet 50
  static const surface = Color(0xFFFFFFFF); // White
  static const surfaceAlt = Color(0xFFEDE9FE); // Violet 100
  static const textPrimary = Color(0xFF2E1065); // Violet 950
  static const textSecondary = Color(0xFF6D28D9); // Violet 700
  static const border = Color(0xFFDDD6FE); // Violet 200
  static const accent = Color(0xFFC4B5FD); // Violet 300
  
  // Status
  static const success = Color(0xFF10B981); // Emerald 500
  static const error = Color(0xFFEF4444); // Red 500
  static const shadow = Color(0x19000000);

  // Dark Theme
  static const darkBackground = Color(0xFF0F0A1E); // Very Dark Purple
  static const darkSurface = Color(0xFF1C1433); // Dark Purple Slate
  static const darkSurfaceAlt = Color(0xFF2D214D); // Slate Purple
  static const darkTextPrimary = Color(0xFFF5F3FF); // Violet 50
  static const darkTextSecondary = Color(0xFFA78BFA); // Violet 400
  static const darkBorder = Color(0xFF4C1D95); // Violet 900
  static const darkPrimary = Color(0xFF8B5CF6); // Violet 500
  static const darkError = Color(0xFFF87171); // Red 400

  // Helpers
  static Color backgroundFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkBackground : background;
  static Color surfaceFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;
  static Color surfaceAltFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkSurfaceAlt : surfaceAlt;
  static Color borderFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkBorder : border;
}
