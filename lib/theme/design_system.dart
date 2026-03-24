import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens y tema global premium para SasPer.
/// Centraliza tipografía, colores, espaciados, radios y animaciones.

// ============================================================================
// TEMA GLOBAL (APP THEME) - iOS / AMOLED
// ============================================================================
class AppTheme {
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  // ── Colores Base Estáticos (Para configuración de ThemeData) ──
  static const Color lightBg = Color(0xFFF2F2F7);
  static const Color lightSurface = Colors.white;
  
  static const Color darkBg = Color(0xFF000000); // TRUE BLACK AMOLED
  static const Color darkSurface = Color(0xFF1C1C1E); // iOS Dark Gray

  // ── Helpers Dinámicos (Para usar en las pantallas si se requiere) ──
  static Color bg(BuildContext context) => isDark(context) ? darkBg : lightBg;
  static Color surface(BuildContext context) => isDark(context) ? darkSurface : lightSurface;
  static Color surfaceRaised(BuildContext context) => isDark(context) ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  static Color border(BuildContext context) => isDark(context) ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  static Color sheetBg(BuildContext context) => isDark(context) ? const Color(0xFF1C1C1E).withOpacity(0.85) : Colors.white.withOpacity(0.92);

  // ── Textos ──
  static Color textPrimary(BuildContext context) => isDark(context) ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  static Color textSecondary(BuildContext context) => isDark(context) ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  static Color textTertiary(BuildContext context) => isDark(context) ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  // ── Semánticos ──
  static const Color accent  = Color(0xFFC9A96E); // Tu color principal
  static const Color success = Color(0xFF30D158); // Verde iOS
  static const Color danger  = Color(0xFFFF453A); // Rojo iOS
  static const Color info    = Color(0xFF0A84FF); // Azul iOS
}

// ============================================================================
// SPACING & RADIUS
// ============================================================================
class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

class AppRadius {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const card = 28.0;
  static const pill = 999.0;
}

class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 200);
  static const screenTransition = Duration(milliseconds: 300);
}

// ============================================================================
// TYPOGRAPHY (DM Sans o Poppins, centralizado)
// ============================================================================
class AppTypography {
  static final display = GoogleFonts.dmSans(
    fontSize: 32, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -0.5,
  );
  static final h1 = GoogleFonts.dmSans(
    fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3,
  );
  static final h2 = GoogleFonts.dmSans(
    fontSize: 22, fontWeight: FontWeight.w600, height: 1.2,
  );
  static final h3 = GoogleFonts.dmSans(
    fontSize: 18, fontWeight: FontWeight.w600, height: 1.3,
  );
  static final body1 = GoogleFonts.dmSans(
    fontSize: 16, fontWeight: FontWeight.w400, height: 1.4,
  );
  static final body2 = GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w400, height: 1.4,
  );
  static final caption = GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, letterSpacing: 0.2,
  );
  static final button = GoogleFonts.dmSans(
    fontSize: 16, fontWeight: FontWeight.w600, height: 1.2,
  );
}

// ============================================================================
// BUILDERS DE TEMA MATERIAL (AQUÍ OCURRE LA MAGIA GLOBAL)
// ============================================================================

/// Tema CLARO (Fondo gris claro, tarjetas blancas)
ThemeData buildLightTheme(ColorScheme baseScheme) {
  // Forzamos los colores de fondo ignorando los dinámicos para mantener estilo iOS
  final colorScheme = baseScheme.copyWith(
    brightness: Brightness.light,
    surface: AppTheme.lightSurface, // Cards blancas
    onSurface: Colors.black,
    primary: AppTheme.accent, // Color principal
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppTheme.lightBg, // Fondo principal gris claro
    fontFamily: GoogleFonts.dmSans().fontFamily,
  );

  return _applySharedTheme(base, colorScheme, isDark: false);
}

/// Tema OSCURO (AMOLED True Black, tarjetas gris oscuro)
ThemeData buildDarkTheme(ColorScheme baseScheme) {
  // Forzamos True Black en toda la app
  final colorScheme = baseScheme.copyWith(
    brightness: Brightness.dark,
    surface: AppTheme.darkSurface, // Cards gris oscuro (#1C1C1E)
    onSurface: Colors.white,
    primary: AppTheme.accent, // Color principal
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppTheme.darkBg, // TRUE BLACK (#000000)
    fontFamily: GoogleFonts.dmSans().fontFamily,
  );

  return _applySharedTheme(base, colorScheme, isDark: true);
}

/// Aplica las formas, botones y textos compartidos entre ambos temas
ThemeData _applySharedTheme(ThemeData base, ColorScheme colorScheme, {required bool isDark}) {
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: AppTypography.display.copyWith(color: colorScheme.onSurface),
      titleLarge: AppTypography.h1.copyWith(color: colorScheme.onSurface),
      titleMedium: AppTypography.h2.copyWith(color: colorScheme.onSurface),
      titleSmall: AppTypography.h3.copyWith(color: colorScheme.onSurface),
      bodyLarge: AppTypography.body1.copyWith(color: colorScheme.onSurface),
      bodyMedium: AppTypography.body2.copyWith(color: colorScheme.onSurface.withOpacity(0.9)),
      bodySmall: AppTypography.caption.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
      labelLarge: AppTypography.button.copyWith(color: colorScheme.onPrimary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: base.scaffoldBackgroundColor, // Mismo color del fondo
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
      titleTextStyle: AppTypography.h2.copyWith(color: colorScheme.onSurface),
    ),
    // MAGIA: Todas las Cards de tu app ahora usarán el color correcto automáticamente
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: EdgeInsets.zero,
    ),
    // MAGIA: Todos los popups y diálogos usarán el color correcto
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    // MAGIA: Todos los BottomSheets usarán el color correcto
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: AppTypography.button,
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.accent,
        textStyle: AppTypography.button.copyWith(fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7), // Inputs un tono más alto
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    ),
  );
}