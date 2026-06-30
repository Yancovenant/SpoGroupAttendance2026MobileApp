import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SPOColors {
  // Primary Colors
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color limeGreen = Color(0xFFA4C639);

  // Light Theme Colors
  static const Color lightBg = Color(0xFFF8FAF0);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF1B5E20);
  static const Color lightTextSecondary = Color(0xFF666666);

  // Dark Theme Colors
  static const Color darkBg = Color(0xFF0A1F0D);
  static const Color darkCard = Color(0xFF1E3A2E);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB0BEC5);

  // Common
  static const Color glassBg = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color conflictRed = Color(0xFFE53935);
}


// 589A30
// EE1F15
ThemeData spoLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF589A30),
    tertiary: const Color(0xFFEE1F15),
    brightness: Brightness.light,
  ),
);
ThemeData spoDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF589A30),
    tertiary: const Color(0xFFEE1F15),
    brightness: Brightness.dark,
  ),
);

ThemeData spoLightTheme2 = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorSchemeSeed: SPOColors.primaryGreen,
  scaffoldBackgroundColor: SPOColors.lightBg,
  textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
  appBarTheme: AppBarTheme(
    backgroundColor: SPOColors.primaryGreen,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.inter(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    color: SPOColors.lightCard,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);

ThemeData spoDarkTheme2 = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorSchemeSeed: SPOColors.primaryGreen,
  scaffoldBackgroundColor: SPOColors.darkBg,
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.inter(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
  ),
  cardTheme: CardThemeData(
    color: SPOColors.darkCard,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);