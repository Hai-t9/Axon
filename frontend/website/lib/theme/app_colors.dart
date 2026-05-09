import 'package:flutter/material.dart';

class AppColors {
  // Light
  static const primary = Color(0xFFB596FF);
  static const primaryDark = Color(0xFF7A5CFF);
  static const background = Color(0xFFF9F6FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF2ECFF);
  static const textPrimary = Color(0xFF2A1B3D);
  static const textSecondary = Color(0xFF6C5D7A);
  static const border = Color(0xFFE5DDF5);
  static const accent = Color(0xFFFFD7F3);
  static const success = Color(0xFF37B287);
  static const error = Color(0xFFE56C6C);
  static const shadow = Color(0x19000000);

  // Dark
  static const darkBackground = Color(0xFF130B1E);
  static const darkSurface = Color(0xFF1E1530);
  static const darkSurfaceAlt = Color(0xFF2A1E40);
  static const darkTextPrimary = Color(0xFFE8E0F5);
  static const darkTextSecondary = Color(0xFFA898C0);
  static const darkBorder = Color(0xFF3D2D55);

  static Color backgroundFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkBackground : background;
  static Color surfaceFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;
  static Color surfaceAltFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkSurfaceAlt : surfaceAlt;
  static Color borderFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkBorder : border;
}
