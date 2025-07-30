// lib/services/widget_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  // ----------- INICIO DE LA DEPURACIÓN -----------
  developer.log('🚀 [BACKGROUND] 1. Callback INICIADO.', name: 'WidgetService');

  try {
    // PASO 1: INICIALIZACIÓN
    if (!GlobalState.supabaseInitialized) {
      developer.log(
          '[BACKGROUND] 2a. Supabase no inicializado, inicializando AHORA...',
          name: 'WidgetService');
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      GlobalState.supabaseInitialized = true;
      developer.log('[BACKGROUND] 2b. Supabase inicialización COMPLETADA.',
          name: 'WidgetService');
    }

    final client = Supabase.instance.client;

    // PASO 2: VERIFICACIÓN Y RECUPERACIÓN DE SESIÓN (LA PARTE CLAVE)
    // Primero, comprobamos si ya hay un usuario.
    if (client.auth.currentUser == null) {
      developer.log(
          'ℹ️ [BACKGROUND] 3a. No hay usuario en la instancia actual. Intentando recuperar sesión...',
          name: 'WidgetService');

      // Intentamos recuperar la sesión desde el almacenamiento local.
      // Supabase guarda la sesión automáticamente. Esta llamada intenta recargarla.
      try {
        await client.auth.refreshSession();
        if (client.auth.currentUser == null) {
          // Si después de refrescar sigue siendo nulo, no podemos continuar.
          developer.log(
              '⚠️ [BACKGROUND] 3b. ERROR CRÍTICO: No se pudo recuperar la sesión de usuario.',
              name: 'WidgetService');
          return;
        }
      } catch (e) {
        developer.log(
            '🔥 [BACKGROUND] 3c. ERROR al intentar refrescar la sesión: $e',
            name: 'WidgetService');
        return; // Salimos si hay un error al refrescar.
      }
    }

    final currentUser = client.auth.currentUser;
    developer.log(
        '✅ [BACKGROUND] 3d. Sesión de usuario ENCONTRADA. User ID: ${currentUser!.id}',
        name: 'WidgetService');

    // PASO 3: INICIALIZAR REPOSITORIOS
    DashboardRepository.instance.initialize(client);
    developer.log('[BACKGROUND] 4. DashboardRepository inicializado.',
        name: 'WidgetService');

    // PASO 4: OBTENER DATOS FRESCOS
    developer.log('[BACKGROUND] 5. Intentando obtener datos del dashboard...',
        name: 'WidgetService');
    final dashboardData =
        await DashboardRepository.instance.fetchDataForWidget();

    // PASO 5: ACTUALIZAR LA UI DEL WIDGET
    if (dashboardData != null) {
      developer.log(
          '[BACKGROUND] 6a. Datos obtenidos con ÉXITO. Balance: ${dashboardData.totalBalance}',
          name: 'WidgetService');
      await WidgetService.updateAllWidgetData(data: dashboardData);
    } else {
      developer.log(
          '⚠️ [BACKGROUND] 6b. Los datos del dashboard son NULL después de la llamada.',
          name: 'WidgetService');
    }
  } catch (e, stackTrace) {
    developer.log(
        '🔥🔥🔥 [BACKGROUND] 7. ERROR FATAL INESPERADO en el callback: $e',
        name: 'WidgetService',
        error: e,
        stackTrace: stackTrace);
  }
}

class WidgetService {
  static Future<void> updateAllWidgetData({required DashboardData data}) async {
    // El nombre de la función ahora es un poco engañoso, ya que solo guarda datos,
    // pero lo dejaremos así por ahora para minimizar cambios.
    developer.log('[Service] 7. Guardando datos para todos los widgets...',
        name: 'WidgetService');
    try {
      final formattedBalance = NumberFormat.currency(
        locale: 'es_CO',
        symbol: '',
        decimalDigits: 2,
      ).format(data.totalBalance);

      final analysisRepo = AnalysisRepository();
      final expenseData = await analysisRepo.getExpenseSummaryForWidget();

      String? chartPath;
      if (expenseData.isNotEmpty) {
        final chartBytes = await _createChartImageFromData(expenseData);
        if (chartBytes != null) {
          final dir = await getApplicationSupportDirectory();
          final path = '${dir.path}/widget_chart.png';
          await File(path).writeAsBytes(chartBytes);
          chartPath = path;
          developer.log('✅ [Service] 8b. Imagen de gráfico guardada en: $path',
              name: 'WidgetService');
        }
      } else {
        developer.log(
            'ℹ️ [Service] 8c. No hay datos de gastos para el gráfico.',
            name: 'WidgetService');
      }

      final budgetsJson =
          jsonEncode(data.featuredBudgets.map((b) => b.toJson()).toList());
      final transactionsJson = jsonEncode(
          data.recentTransactions.take(3).map((tx) => tx.toJson()).toList());

      await HomeWidget.saveWidgetData<String>(
          'total_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>(
          'widget_chart_path', chartPath ?? ""); // Aseguramos no guardar null
      await HomeWidget.saveWidgetData<String>(
          'featured_budgets_json', budgetsJson);
      await HomeWidget.saveWidgetData<String>(
          'recent_transactions_json', transactionsJson);
      await HomeWidget.saveWidgetData<String>('budgets_json', budgetsJson);

      // --- CAMBIO CLAVE: LÍNEAS ELIMINADAS ---
      // await HomeWidget.updateWidget(name: 'SasPerWidgetProvider');
      // await HomeWidget.updateWidget(name: 'SasPerMediumWidgetProvider');
      // await HomeWidget.updateWidget(name: 'SasPerLargeWidgetProvider');

      developer.log(
          '✅ [Service] 9. Datos guardados en SharedPreferences con ÉXITO.',
          name: 'WidgetService');
    } catch (e, stackTrace) {
      developer.log(
          '🔥 [Service] Error durante el guardado de datos del widget: $e',
          name: 'WidgetService',
          error: e,
          stackTrace: stackTrace);
    }
  }

  /// Dibuja un gráfico de tarta con una leyenda manualmente en un Canvas.
  /// Este código no necesita cambios.
  static Future<Uint8List?> _createChartImageFromData(
      List<ExpenseByCategory> data) async {
    try {
      // 1. Convertimos todos los gastos a valores positivos para el gráfico.
      final positiveData = data
          .map((e) => ExpenseByCategory(
              category: e.category, totalSpent: e.totalSpent.abs()))
          .toList();

      final double width = 400;
      final double height = 200;
      // ... el resto de la función es idéntico al que te pasé en el mensaje anterior ...
      // ... asegúrate de que toda la lógica a partir de aquí use 'positiveData' ...

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
      canvas.drawPaint(Paint()..color = Colors.transparent);
      final colors = [
        Colors.blue.shade400,
        Colors.red.shade400,
        Colors.green.shade400,
        Colors.orange.shade400,
        Colors.purple.shade400,
        Colors.yellow.shade700,
      ];

      final total =
          positiveData.fold<double>(0.0, (sum, e) => sum + e.totalSpent);
      if (total <= 0) return null;

      final chartCenter = Offset(height / 2, height / 2);
      final chartRadius = height / 2 * 0.85;
      double startAngle = -pi / 2;
      final dataToShow = positiveData.take(5).toList();

      for (var i = 0; i < dataToShow.length; i++) {
        final item = dataToShow[i];
        if (item.totalSpent <= 0) continue;
        final sweepAngle = (item.totalSpent / total) * 2 * pi;
        final paint = Paint()..color = colors[i % colors.length];
        canvas.drawArc(
          Rect.fromCircle(center: chartCenter, radius: chartRadius),
          startAngle,
          sweepAngle,
          true,
          paint,
        );
        startAngle += sweepAngle;
      }

      double legendY = 25.0;
      final double legendX = height + 15;
      for (var i = 0; i < dataToShow.length; i++) {
        final item = dataToShow[i];
        if (item.totalSpent <= 0) continue;
        final pct = (item.totalSpent / total) * 100;
        final colorPaint = Paint()..color = colors[i % colors.length];
        canvas.drawCircle(Offset(legendX, legendY), 6, colorPaint);
        final textStyle = const TextStyle(
            color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500);
        final pctStyle = TextStyle(
            color: Colors.grey[800],
            fontSize: 14,
            fontWeight: FontWeight.normal);
        final textSpan = TextSpan(
            style: textStyle,
            text: '${item.category} ',
            children: [
              TextSpan(text: '(${pct.toStringAsFixed(0)}%)', style: pctStyle)
            ]);
        final textPainter = TextPainter(
            text: textSpan,
            textDirection: ui.TextDirection.ltr,
            maxLines: 1,
            ellipsis: '...');
        textPainter.layout(minWidth: 0, maxWidth: width - legendX - 25);
        textPainter.paint(
            canvas, Offset(legendX + 20, legendY - textPainter.height / 2));
        legendY += 30.0;
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e, stackTrace) {
      developer.log(
          '🔥🔥🔥 [ChartCreator] ERROR FATAL al crear la imagen del gráfico: $e',
          name: 'WidgetDebug',
          error: e,
          stackTrace: stackTrace);
      return null;
    }
  }
}
