import 'package:flutter/material.dart';

/// Centralized color palette for LunaSight.
///
/// Refined scientific and aerospace-inspired palette: deep space obsidian,
/// celestial midnight navy, muted lunar cyan/teal accents, starlight slate neutrals.
class AppColors {
  AppColors._();

  // Dark Theme Palette (Deep Space)
  static const Color darkBackground = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111726);
  static const Color darkSurfaceElevated = Color(0xFF182238);
  static const Color darkCard = Color(0xFF141D30);
  static const Color darkBorder = Color(0xFF22314E);
  static const Color darkBorderSubtle = Color(0xFF19253B);

  static const Color darkPrimary = Color(0xFF38BDF8); // Cyan / Celestial Blue
  static const Color darkPrimaryContainer = Color(0xFF0F3652);
  static const Color darkOnPrimary = Color(0xFF041826);
  static const Color darkOnPrimaryContainer = Color(0xFFBAE6FD);

  static const Color darkSecondary = Color(0xFF818CF8); // Stellar Indigo
  static const Color darkSecondaryContainer = Color(0xFF1E265C);
  static const Color darkOnSecondary = Color(0xFF0C1030);
  static const Color darkOnSecondaryContainer = Color(0xFFC7D2FE);

  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // Light Theme Palette (Clean Aerospace Laboratory)
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderSubtle = Color(0xFFEDF2F7);

  static const Color lightPrimary = Color(0xFF0284C7); // Technical Sky Blue
  static const Color lightPrimaryContainer = Color(0xFFE0F2FE);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnPrimaryContainer = Color(0xFF0369A1);

  static const Color lightSecondary = Color(0xFF4F46E5); // Deep Indigo
  static const Color lightSecondaryContainer = Color(0xFFEEF2FF);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightOnSecondaryContainer = Color(0xFF3730A3);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // Functional Status
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFEF4444);
  static const Color statusInfo = Color(0xFF38BDF8);
}

