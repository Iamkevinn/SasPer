// lib/services/widget_service.dart (VERSIÓN FINAL CON GRÁFICO Y LEYENDA)

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart'; // Ahora es crucial para TextPainter
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WidgetService {
  
  static Future<void> updateAllWidgetData({required double totalBalance}) async {
    developer.log('🔄 [Service] Starting full widget update...', name: 'WidgetService');
    try {
      final formattedBalance = NumberFormat.currency(
        locale: 'es_ES', symbol: '€', decimalDigits: 2,
      ).format(totalBalance);

      final analysisRepo = AnalysisRepository(client: Supabase.instance.client);
      final expenseData = await analysisRepo.getExpenseSummaryForWidget();
      
      String? chartPath;
      if (expenseData.isNotEmpty) {
        // Generamos la imagen directamente desde los datos, sin widgets.
        final chartBytes = await _createChartImageFromData(expenseData);
        if (chartBytes != null) {
          final dir = await getApplicationSupportDirectory();
          final path = '${dir.path}/widget_chart.png';
          await File(path).writeAsBytes(chartBytes);
          chartPath = path;
          developer.log('✅ [Service] Chart image saved to: $path', name: 'WidgetService');
        }
      } else {
        developer.log('ℹ️ [Service] No expense data for chart.', name: 'WidgetService');
      }

      await HomeWidget.saveWidgetData<String>('total_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>('widget_chart_path', chartPath);

      await HomeWidget.updateWidget(name: 'SasPerWidgetProvider');
      await HomeWidget.updateWidget(name: 'SasPerMediumWidgetProvider');
      
      developer.log('✅ [Service] Full widget update sent.', name: 'WidgetService');
    } catch (e, stackTrace) {
      developer.log('🔥 [Service] Error during full widget update: $e', name: 'WidgetService', error: e, stackTrace: stackTrace);
    }
  }

  /// Dibuja un gráfico de tarta con una leyenda manualmente en un Canvas.
  static Future<Uint8List?> _createChartImageFromData(List<ExpenseByCategory> data) async {
    try {
      final double width = 400;
      final double height = 200;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      // Fondo transparente para la imagen PNG
      canvas.drawPaint(Paint()..color = Colors.transparent);

      final colors = [
        Colors.blue.shade400, Colors.red.shade400, Colors.green.shade400,
        Colors.orange.shade400, Colors.purple.shade400, Colors.yellow.shade700,
      ];
      final total = data.fold<double>(0.0, (sum, e) => sum + e.totalSpent);
      
      // --- DIBUJAR EL GRÁFICO (IZQUIERDA) ---
      final chartCenter = Offset(height / 2, height / 2);
      final chartRadius = height / 2 * 0.85; // Un poco más grande
      double startAngle = -pi / 2;

      // Limitamos los datos a mostrar para que la leyenda sea legible
      final dataToShow = data.take(5).toList();

      for (var i = 0; i < dataToShow.length; i++) {
        final item = dataToShow[i];
        if (item.totalSpent <= 0) continue; // No dibujar arcos de tamaño cero
        final sweepAngle = (item.totalSpent / total) * 2 * pi;
        final paint = Paint()..color = colors[i % colors.length];
        canvas.drawArc(
          Rect.fromCircle(center: chartCenter, radius: chartRadius),
          startAngle, sweepAngle, true, paint,
        );
        startAngle += sweepAngle;
      }
      
      // --- DIBUJAR LA LEYENDA (DERECHA) ---
      double legendY = 25.0;
      final double legendX = height + 15;

      for (var i = 0; i < dataToShow.length; i++) {
        final item = dataToShow[i];
        if (item.totalSpent <= 0) continue;
        final pct = (item.totalSpent / total) * 100;

        // Punto de color
        final colorPaint = Paint()..color = colors[i % colors.length];
        canvas.drawCircle(Offset(legendX, legendY), 6, colorPaint);

        // Texto (Categoría y Porcentaje)
        final textStyle = const TextStyle(
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        );
        final pctStyle = TextStyle(
          color: Colors.grey[800],
          fontSize: 14,
          fontWeight: FontWeight.normal,
        );
        
        final textSpan = TextSpan(
          style: textStyle,
          text: '${item.category} ',
          children: [TextSpan(text: '(${pct.toStringAsFixed(0)}%)', style: pctStyle)],
        );
        
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        
        textPainter.layout(minWidth: 0, maxWidth: width - legendX - 25);
        textPainter.paint(canvas, Offset(legendX + 20, legendY - textPainter.height / 2));

        legendY += 30.0;
      }
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e, stackTrace) {
      developer.log('🔥 Error creating chart image with Canvas: $e', name: 'WidgetService', stackTrace: stackTrace);
      return null;
    }
  }
}