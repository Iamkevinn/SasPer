import 'package:flutter/material.dart';

/// Design tokens y tema global premium para SasPer.
/// Centraliza tipografía, colores, espaciados, radios y animaciones.

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
  static const pill = 999.0;
}

class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 200);
  static const screenTransition = Duration(milliseconds: 300);
}

class AppCurves {
  static const standard = Curves.easeInOutCubicEmphasized;
  static const decelerate = Curves.easeOutCubic;
  static const accelerate = Curves.easeInCubic;
}

class AppTypography {
  static const display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 38 / 32,
    letterSpacing: -0.5,
  );

  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 34 / 28,
    letterSpacing: -0.3,
  );

  static const h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 28 / 22,
  );

  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 24 / 18,
  );

  static const body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 22 / 16,
  );

  static const body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
    letterSpacing: 0.2,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 20 / 16,
  );
}

/// Construye el tema claro a partir de un [baseScheme] (por ejemplo, dynamic color)
/// pero con nuestros tokens aplicados de forma coherente.
ThemeData buildLightTheme(ColorScheme baseScheme) {
  final colorScheme = baseScheme.copyWith(
    primary: baseScheme.primary,
    secondary: baseScheme.secondary,
    error: baseScheme.error,
    surface: baseScheme.surface,
    background: baseScheme.background,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: AppTypography.display.copyWith(color: colorScheme.onBackground),
      titleLarge: AppTypography.h1.copyWith(color: colorScheme.onBackground),
      titleMedium: AppTypography.h2.copyWith(color: colorScheme.onBackground),
      titleSmall: AppTypography.h3.copyWith(color: colorScheme.onBackground),
      bodyLarge: AppTypography.body1.copyWith(color: colorScheme.onBackground),
      bodyMedium: AppTypography.body2.copyWith(color: colorScheme.onBackground.withOpacity(0.9)),
      bodySmall: AppTypography.caption.copyWith(color: colorScheme.onBackground.withOpacity(0.7)),
      labelLarge: AppTypography.button.copyWith(color: colorScheme.onPrimary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: colorScheme.onBackground,
      centerTitle: false,
      titleTextStyle: AppTypography.h3.copyWith(color: colorScheme.onBackground),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: AppTypography.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: AppTypography.button.copyWith(
          fontSize: 14,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
  );
}

/// Tema oscuro con los mismos tokens, armonizado con [baseScheme].
ThemeData buildDarkTheme(ColorScheme baseScheme) {
  final colorScheme = baseScheme.copyWith(
    brightness: Brightness.dark,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.background,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: AppTypography.display.copyWith(color: colorScheme.onBackground),
      titleLarge: AppTypography.h1.copyWith(color: colorScheme.onBackground),
      titleMedium: AppTypography.h2.copyWith(color: colorScheme.onBackground),
      titleSmall: AppTypography.h3.copyWith(color: colorScheme.onBackground),
      bodyLarge: AppTypography.body1.copyWith(color: colorScheme.onBackground),
      bodyMedium: AppTypography.body2.copyWith(color: colorScheme.onBackground.withOpacity(0.9)),
      bodySmall: AppTypography.caption.copyWith(color: colorScheme.onBackground.withOpacity(0.7)),
      labelLarge: AppTypography.button.copyWith(color: colorScheme.onPrimary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.background.withOpacity(0.98),
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: colorScheme.onBackground,
      centerTitle: false,
      titleTextStyle: AppTypography.h3.copyWith(color: colorScheme.onBackground),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        textStyle: AppTypography.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: AppTypography.button.copyWith(
          fontSize: 14,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    ),
  );
}

