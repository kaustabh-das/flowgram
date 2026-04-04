/// Centralized color palette for Flowgram.
/// Inspired by Prequel – deep blacks, vivid accent, glassy surfaces.
library;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Background / Surface ──────────────────────────────────────────
  static const Color background     = Color(0xFF0A0A0A);
  static const Color surfaceDark    = Color(0xFF121212);
  static const Color surfaceMid     = Color(0xFF1C1C1E);
  static const Color surfaceLight   = Color(0xFF2C2C2E);
  static const Color surfaceGlass   = Color(0x1AFFFFFF); // frosted glass overlay

  // ── Accent ────────────────────────────────────────────────────────
  static const Color accentPurple   = Color(0xFF9B5DE5); // Prequel-like violet
  static const Color accentCyan     = Color(0xFF00D4FF);
  static const Color accentGradEnd  = Color(0xFFE040FB);

  // ── Text ──────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFFF2F2F7);
  static const Color textSecondary  = Color(0xFF8E8E93);
  static const Color textDisabled   = Color(0xFF3A3A3C);

  // ── Error / Success ───────────────────────────────────────────────
  static const Color error          = Color(0xFFFF453A);
  static const Color success        = Color(0xFF30D158);

  // ── Divider ───────────────────────────────────────────────────────
  static const Color divider        = Color(0xFF2C2C2E);

  // ── Gradient shortcuts ────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentPurple, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, surfaceDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
