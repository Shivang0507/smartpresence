import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color color) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return base.copyWith(
      displayLarge:  base.displayLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: color),
      displaySmall:  base.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: color),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
      titleLarge:    base.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
      titleMedium:   base.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: color),
      titleSmall:    base.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: color),
      bodyLarge:     base.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: color),
      bodyMedium:    base.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: color),
      bodySmall:     base.bodySmall?.copyWith(color: color),
      labelLarge:    base.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
      labelMedium:   base.labelMedium?.copyWith(color: color),
      labelSmall:    base.labelSmall?.copyWith(color: color),
    );
  }
}
