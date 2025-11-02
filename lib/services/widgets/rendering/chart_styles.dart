import 'package:flutter/material.dart';

class ChartStyles {
  /// Paleta de colores premium con gradientes armónicos
  static List<Color> get premiumPalette => [
        const Color(0xFF6366F1), // Indigo
        const Color(0xFFEC4899), // Pink
        const Color(0xFF10B981), // Emerald
        const Color(0xFFF59E0B), // Amber
        const Color(0xFF8B5CF6), // Purple
        const Color(0xFF06B6D4), // Cyan
        const Color(0xFFEF4444), // Red
        const Color(0xFF14B8A6), // Teal
      ];

  /// Genera gradiente para una categoría
  static List<Color> getGradientForIndex(int index) {
    final baseColor = premiumPalette[index % premiumPalette.length];
    return [
      baseColor,
      HSLColor.fromColor(baseColor).withLightness(0.7).toColor(),
    ];
  }

  /// Estilo de texto para gráficos
  static TextStyle chartLabelStyle({
    required bool isDark,
    double fontSize = 13,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      color: isDark ? Colors.white : Colors.black87,
      fontSize: fontSize,
      fontWeight: weight,
      fontFamily: 'Poppins',
    );
  }

  /// Estilo de texto secundario
  static TextStyle chartSubtextStyle({
    required bool isDark,
    double fontSize = 11,
  }) {
    return TextStyle(
      color: isDark ? Colors.white70 : Colors.black54,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      fontFamily: 'Poppins',
    );
  }

  /// Color de fondo según tema
  static Color backgroundColor(bool isDark) {
    return isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  }
}
