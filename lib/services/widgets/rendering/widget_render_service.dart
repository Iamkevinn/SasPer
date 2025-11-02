import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sasper/services/widgets/core/widget_config.dart';
import 'dart:developer' as developer;

import 'package:sasper/services/widgets/core/widget_types.dart';
import 'package:sasper/services/widgets/rendering/chart_styles.dart';

class WidgetRenderService {
  static const String _logName = 'WidgetRender';
  
  /// Renderiza un gráfico de pastel premium con optimizaciones
  static Future<Uint8List?> renderPieChart({
    required List<CategoryData> data,
    required bool isDarkMode,
    WidgetSize size = WidgetSize.medium,
    bool showShadows = true,
    bool showGradients = true,
  }) async {
    if (data.isEmpty) return null;

    try {
      final width = size.width * WidgetConfig.chartQuality;
      final height = size.height * WidgetConfig.chartQuality;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, width, height),
      );

      // Configuración de áreas
      final pieArea = width * 0.5;
      final legendArea = width * 0.5;
      final chartDiameter = min(pieArea, height) * 0.75;
      final chartRadius = chartDiameter / 2;
      final chartCenter = Offset(pieArea / 2, height / 2);

      // Preparar datos
      final sortedData = List<CategoryData>.from(data)
        ..sort((a, b) => b.amount.compareTo(a.amount));
      
      final displayData = sortedData.length > WidgetConfig.maxChartCategories
          ? _consolidateData(sortedData)
          : sortedData;

      final total = displayData.fold<double>(0, (sum, d) => sum + d.amount);
      if (total <= 0) return null;

      // Dibujar fondo con gradiente sutil
      _drawBackground(canvas, Size(width, height), isDarkMode);

      // Dibujar sombra del gráfico
      if (showShadows) {
        _drawChartShadow(canvas, chartCenter, chartRadius);
      }

      // Dibujar segmentos
      double startAngle = -pi / 2;
      for (var i = 0; i < displayData.length; i++) {
        final item = displayData[i];
        final sweepAngle = (item.amount / total) * 2 * pi;
        
        _drawSegment(
          canvas,
          center: chartCenter,
          radius: chartRadius,
          startAngle: startAngle,
          sweepAngle: sweepAngle,
          colors: ChartStyles.getGradientForIndex(i),
          useGradient: showGradients,
        );

        startAngle += sweepAngle;
      }

      // Dibujar círculo central (efecto donut opcional)
      _drawCenterCircle(canvas, chartCenter, chartRadius * 0.4, isDarkMode);

      // Dibujar leyenda
      _drawLegend(
        canvas,
        data: displayData,
        total: total,
        startX: pieArea + 20,
        startY: (height - (displayData.length * 30)) / 2,
        maxWidth: legendArea - 40,
        isDarkMode: isDarkMode,
      );

      // Renderizar imagen
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e, st) {
      developer.log(
        '🔥 Error al renderizar gráfico: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static void _drawBackground(Canvas canvas, Size size, bool isDark) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        isDark
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  static void _drawChartShadow(Canvas canvas, Offset center, double radius) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    
    canvas.drawCircle(
      center.translate(5, 5),
      radius,
      shadowPaint,
    );
  }

  static void _drawSegment(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required List<Color> colors,
    required bool useGradient,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    final paint = Paint();
    if (useGradient && colors.length > 1) {
      final gradientAngle = startAngle + sweepAngle / 2;
      final gradientStart = center + Offset(
        cos(gradientAngle) * radius * 0.3,
        sin(gradientAngle) * radius * 0.3,
      );
      final gradientEnd = center + Offset(
        cos(gradientAngle) * radius,
        sin(gradientAngle) * radius,
      );
      
      paint.shader = ui.Gradient.linear(gradientStart, gradientEnd, colors);
    } else {
      paint.color = colors.first;
    }

    canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

    // Borde sutil entre segmentos
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);
  }

  static void _drawCenterCircle(
    Canvas canvas,
    Offset center,
    double radius,
    bool isDark,
  ) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    canvas.drawCircle(center, radius, paint);
  }

  static void _drawLegend(
    Canvas canvas, {
    required List<CategoryData> data,
    required double total,
    required double startX,
    required double startY,
    required double maxWidth,
    required bool isDarkMode,
  }) {
    double y = startY;

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final percentage = (item.amount / total * 100);
      
      // Color bullet
      final bulletPaint = Paint()
        ..color = ChartStyles.premiumPalette[i % ChartStyles.premiumPalette.length];
      canvas.drawCircle(Offset(startX, y + 7), 6, bulletPaint);

      // Texto
      final textStyle = ChartStyles.chartLabelStyle(isDark: isDarkMode, fontSize: 13);
      final subTextStyle = ChartStyles.chartSubtextStyle(isDark: isDarkMode);

      final textSpan = TextSpan(
        style: textStyle,
        text: '${item.category} ',
        children: [
          TextSpan(
            text: '(${percentage.toStringAsFixed(0)}%)',
            style: subTextStyle,
          ),
        ],
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      );

      textPainter.layout(maxWidth: maxWidth - 30);
      textPainter.paint(canvas, Offset(startX + 15, y));

      y += 30;
    }
  }

  static List<CategoryData> _consolidateData(List<CategoryData> data) {
    final topItems = data.take(WidgetConfig.maxChartCategories - 1).toList();
    final othersAmount = data
        .skip(WidgetConfig.maxChartCategories - 1)
        .fold<double>(0, (sum, d) => sum + d.amount);

    if (othersAmount > 0) {
      topItems.add(CategoryData(category: 'Otros', amount: othersAmount));
    }

    return topItems;
  }
}

class CategoryData {
  final String category;
  final double amount;

  CategoryData({required this.category, required this.amount});
}