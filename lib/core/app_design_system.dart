// lib/core/app_design_system.dart
// Sistema de diseño centralizado — Sasper Premium
// Inspirado en Apple Wallet + Apple Fitness: profundidad real, jerarquía clara.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// SPACING SCALE — Base 4pt grid
// ============================================================================
abstract class AppSpacing {
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
  static const double xxxl = 64.0;

  // Padding predefinidos
  static const EdgeInsets pagePadding   = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding   = EdgeInsets.all(lg);
  static const EdgeInsets pillPadding   = EdgeInsets.symmetric(horizontal: md, vertical: sm);
  static const EdgeInsets sectionInset  = EdgeInsets.fromLTRB(md, lg, md, sm);
}

// ============================================================================
// BORDER RADII
// ============================================================================
abstract class AppRadius {
  static const double pill    = 100.0;
  static const double card    = 28.0;
  static const double cardLg  = 32.0;
  static const double module  = 20.0;
  static const double chip    = 14.0;
  static const double icon    = 12.0;
  static const double sm      = 8.0;
}

// ============================================================================
// ANIMATION DURATIONS & CURVES
// ============================================================================
abstract class AppMotion {
  static const Duration instant  = Duration(milliseconds: 100);
  static const Duration fast     = Duration(milliseconds: 200);
  static const Duration normal   = Duration(milliseconds: 280);
  static const Duration smooth   = Duration(milliseconds: 350);
  static const Duration count    = Duration(milliseconds: 1200);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve springCurve  = Curves.easeInOutCubic;
  static const Curve fadeCurve    = Curves.easeInOut;
}

// ============================================================================
// BLUR INTENSITIES
// ============================================================================
abstract class AppBlur {
  static const double none    = 0.0;
  static const double subtle  = 8.0;
  static const double medium  = 16.0;
  static const double strong  = 28.0;
  static const double nav     = 20.0;
}

// ============================================================================
// NEUTRAL OPACITY LEVELS
// ============================================================================
abstract class AppOpacity {
  static const double ghost     = 0.04;
  static const double faint     = 0.08;
  static const double light     = 0.12;
  static const double soft      = 0.20;
  static const double medium    = 0.40;
  static const double secondary = 0.65;
  static const double primary   = 0.85;
  static const double full      = 1.00;
}

// ============================================================================
// COLOR PALETTE
// ============================================================================
abstract class AppColors {
  // Brand — desaturado, elegante
  static const Color teal900   = Color(0xFF0A7066);
  static const Color teal700   = Color(0xFF0D9488);
  static const Color teal500   = Color(0xFF14B8A6);
  static const Color teal200   = Color(0xFF99F6E4);

  // Neutrals
  static const Color ink       = Color(0xFF0E1117);
  static const Color slate     = Color(0xFF1C2130);
  static const Color muted     = Color(0xFF8892A4);
  static const Color surface   = Color(0xFFF2F4F7);
  static const Color white     = Color(0xFFFFFFFF);

  // Semantic
  static const Color success   = Color(0xFF22C55E);
  static const Color warning   = Color(0xFFF59E0B);
  static const Color danger    = Color(0xFFEF4444);
  static const Color info      = Color(0xFF3B82F6);

  // Glass layers
  static Color glassLight = white.withOpacity(AppOpacity.faint);
  static Color glassDark  = ink.withOpacity(AppOpacity.faint);
}

// ============================================================================
// TEXT STYLES — Poppins system
// ============================================================================
abstract class AppText {
  // Hero — número principal del balance
  static TextStyle heroNumber(Color color) => GoogleFonts.poppins(
    fontSize: 52,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1.0,
    color: color,
  );

  // Display — títulos de sección grandes
  static TextStyle display(Color color) => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: color,
  );

  // Title — cabeceras de card
  static TextStyle title(Color color) => GoogleFonts.poppins(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: color,
  );

  // Subtitle — etiquetas secundarias
  static TextStyle subtitle(Color color) => GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: color,
  );

  // Body — texto corrido
  static TextStyle body(Color color) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  // Caption — texto muy pequeño
  static TextStyle caption(Color color) => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: color,
  );

  // Label de pill / badge
  static TextStyle label(Color color) => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: color,
  );

  // Número KPI dentro de pill
  static TextStyle kpiValue(Color color) => GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: color,
  );
}

// ============================================================================
// DECORATION HELPERS
// ============================================================================
abstract class AppDecorations {
  /// Card glass — superficie con blur, sin sombra fuerte
  static BoxDecoration glassCard({
    required BuildContext context,
    Color? borderColor,
    double radius = AppRadius.card,
    double borderOpacity = AppOpacity.light,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withOpacity(AppOpacity.ghost)
          : Colors.white.withOpacity(0.72),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? (isDark
            ? Colors.white.withOpacity(borderOpacity)
            : Colors.black.withOpacity(borderOpacity * 0.5)),
        width: 1.0,
      ),
    );
  }

  /// Hero card — gradiente teal desaturado
  static BoxDecoration heroCard({bool isDark = false}) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF0A5C53), Color(0xFF0D7A6E)]
          : const [Color(0xFF0B8079), Color(0xFF0EA594)],
      stops: const [0.0, 1.0],
    ),
    borderRadius: BorderRadius.circular(AppRadius.cardLg),
  );

  /// Pill translúcida sobre fondo oscuro (hero card)
  static BoxDecoration heroPill() => BoxDecoration(
    color: Colors.white.withOpacity(AppOpacity.light),
    borderRadius: BorderRadius.circular(AppRadius.pill),
    border: Border.all(
      color: Colors.white.withOpacity(AppOpacity.soft),
      width: 1.0,
    ),
  );

  /// Chip de acción secundaria
  static BoxDecoration actionChip({required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withOpacity(AppOpacity.faint)
          : Colors.black.withOpacity(AppOpacity.ghost),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(AppOpacity.light)
            : Colors.black.withOpacity(AppOpacity.faint),
        width: 1.0,
      ),
    );
  }
}