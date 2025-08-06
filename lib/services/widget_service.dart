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
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/models/upcoming_payment_model.dart';
import 'package:sasper/data/goal_repository.dart';

// --- Constante de Logging ---
const String _logName = 'WidgetService';

/// Callback de nivel superior para la actualización periódica en segundo plano.
/// NOTA: La lógica principal de actualización se activa desde la app cuando está abierta.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  developer.log('🚀 [BACKGROUND] Callback de HomeWidget iniciado.', name: _logName);
  // Aquí se podría implementar una lógica de actualización ligera si fuera necesario,
  // por ejemplo, usando las credenciales guardadas para obtener datos mínimos.
}


/// Clase de servicio que encapsula toda la lógica para los widgets de la pantalla de inicio.
class WidgetService {

  //============================================================================
  // SECCIÓN DE WIDGETS PRINCIPALES (Dashboard: Pequeño, Mediano, Grande)
  //============================================================================

  /// Prepara y guarda todos los datos necesarios para los widgets del dashboard.
  ///
  /// Esta función debe ser llamada desde el hilo principal de la UI, ya que
  /// contiene operaciones de renderizado (`dart:ui`) que no pueden ejecutarse
  /// en un Isolate secundario.
  static const String _goalsWidgetName = 'GoalsWidgetProvider';
  Future<void> updateAllWidgets(DashboardData data, BuildContext context) async {
    developer.log('🚀 [UI_THREAD] Iniciando actualización completa de todos los widgets.', name: _logName);

    try {
      // 1. Formatear datos simples.
      final formattedBalance = NumberFormat.currency(
        locale: 'es_CO', 
        symbol: '\$', 
        decimalDigits: 0
      ).format(data.totalBalance);

      // 2. Serializar datos complejos a JSON.
      final budgetsJson = jsonEncode(data.featuredBudgets.map((b) => b.toJson()).toList());
      final transactionsJson = jsonEncode(data.recentTransactions.take(3).map((tx) => tx.toJson()).toList());

      // 3. Crear y guardar la imagen del gráfico (operación de UI/CPU).
      String? finalChartPath;
      if (data.expenseSummaryForWidget.isNotEmpty) {
        developer.log('📊 [UI_THREAD] Creando imagen del gráfico...', name: _logName);
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        final chartBytes = await _createChartImageFromData(data.expenseSummaryForWidget, isDarkMode: isDarkMode);
        
        if (chartBytes != null) {
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_chart.png');
          await file.writeAsBytes(chartBytes);
          finalChartPath = file.path;
          developer.log('✅ [UI_THREAD] Imagen del gráfico guardada en: $finalChartPath', name: _logName);
        }
      }

      // 4. Persistir todos los datos usando HomeWidget.
      // Estas llamadas son asíncronas pero rápidas (escriben en SharedPreferences).
      await HomeWidget.saveWidgetData<String>('total_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>('widget_chart_path', finalChartPath ?? "");
      await HomeWidget.saveWidgetData<String>('featured_budgets_json', budgetsJson);
      await HomeWidget.saveWidgetData<String>('recent_transactions_json', transactionsJson);

      // 5. Notificar a los widgets nativos que sus datos han cambiado y deben redibujarse.
      await HomeWidget.updateWidget(name: 'SasPerMediumWidgetProvider');
      await HomeWidget.updateWidget(name: 'SasPerLargeWidgetProvider');
      // Asegúrate de incluir aquí los nombres de todos tus providers.
      // await HomeWidget.updateWidget(name: 'SasPerSmallWidgetProvider');
      
      developer.log('✅ [UI_THREAD] Actualización de widgets completada.', name: _logName);

    } catch (e, st) {
      developer.log('🔥🔥🔥 [UI_THREAD] ERROR FATAL al actualizar widgets: $e', name: _logName, error: e, stackTrace: st);
    }
  }

  static Future<void> updateGoalsWidget() async {
        developer.log('🔄 [WidgetService] Iniciando actualización del widget de metas...', name: 'WidgetService');
        try {
            // 1. Usa la instancia Singleton
            final goalRepo = GoalRepository.instance;
            
            // 2. Llama al nuevo método que devuelve un Future
            final goals = await goalRepo.getActiveGoals();

            final goalsListForWidget = goals.map((goal) => {
                'name': goal.name,
                'current_amount': goal.currentAmount,
                'target_amount': goal.targetAmount,
            }).toList();

            // Guardar los datos para que el widget nativo los lea
            await HomeWidget.saveWidgetData<String>('goals_list', json.encode(goalsListForWidget));
            
            // Notificar al widget que se actualice
            await HomeWidget.updateWidget(
                name: _goalsWidgetName,
                androidName: _goalsWidgetName,
            );
            developer.log('✅ [WidgetService] Widget de metas actualizado con ${goals.length} metas.', name: 'WidgetService');
        } catch (e) {
            developer.log('🔥 [WidgetService] Error al actualizar el widget de metas: $e', name: 'WidgetService');
        }
    }

  /// Método estático privado para generar la imagen del gráfico.
  static Future<Uint8List?> _createChartImageFromData(
    List<ExpenseByCategory> data, { required bool isDarkMode, }
  ) async {
    try {
      final textColor = isDarkMode ? Colors.white : Colors.black;
      final subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;
      final positiveData = data.map((e) => ExpenseByCategory(category: e.category, totalSpent: e.totalSpent.abs())).toList();
      
      const double width = 400;
      const double height = 200;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
      canvas.drawPaint(Paint()..color = Colors.transparent);

      final colors = [ Colors.blue.shade400, Colors.red.shade400, Colors.green.shade400, Colors.orange.shade400, Colors.purple.shade400, Colors.yellow.shade700, ];
      final total = positiveData.fold<double>(0.0, (sum, e) => sum + e.totalSpent);
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
        canvas.drawArc(Rect.fromCircle(center: chartCenter, radius: chartRadius), startAngle, sweepAngle, true, paint);
        startAngle += sweepAngle;
      }

      double legendY = 25.0;
      const double legendX = height + 15;
      for (var i = 0; i < dataToShow.length; i++) {
        final item = dataToShow[i];
        if (item.totalSpent <= 0) continue;
        final pct = (item.totalSpent / total) * 100;
        final colorPaint = Paint()..color = colors[i % colors.length];
        canvas.drawCircle(Offset(legendX, legendY), 6, colorPaint);

        final textStyle = TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500);
        final pctStyle = TextStyle(color: subTextColor, fontSize: 14, fontWeight: FontWeight.normal);
        
        final textSpan = TextSpan(style: textStyle, text: '${item.category} ', children: [TextSpan(text: '(${pct.toStringAsFixed(0)}%)', style: pctStyle)]);
        final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr, maxLines: 1, ellipsis: '...');
        textPainter.layout(minWidth: 0, maxWidth: width - legendX - 25);
        textPainter.paint(canvas, Offset(legendX + 20, legendY - textPainter.height / 2));
        legendY += 30.0;
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e, stackTrace) {
      // Este log es crucial para capturar errores de renderizado.
      developer.log('🔥🔥🔥 [ChartCreator] ERROR FATAL al crear la imagen del gráfico: $e', name: _logName, error: e, stackTrace: stackTrace);
      return null;
    }
  }


  //============================================================================
  // SECCIÓN DE WIDGET DE PRÓXIMOS PAGOS
  //============================================================================

  /// Obtiene la lista de próximos pagos combinando deudas y transacciones recurrentes.
  Future<List<UpcomingPayment>> getUpcomingPayments() async {
    final List<UpcomingPayment> upcomingPayments = [];

    // NOTA: Estos repositorios deben estar inicializados en el hilo principal.
    final debts = await DebtRepository.instance.getActiveDebts();
    for (var debt in debts) {
      if (debt.dueDate != null && debt.dueDate!.isAfter(DateTime.now())) {
        upcomingPayments.add(UpcomingPayment(
          id: debt.id,
          concept: debt.name,
          amount: debt.currentBalance, 
          nextDueDate: debt.dueDate!, 
          type: UpcomingPaymentType.debt,
          iconName: 'debt_icon', 
        ));
      }
    }

    final recurringTxs = await RecurringRepository.instance.getAll();
    for (var tx in recurringTxs) {
      if (tx.nextDueDate.isAfter(DateTime.now())) {
        upcomingPayments.add(UpcomingPayment(
          id: tx.id,
          concept: tx.description,
          amount: tx.amount,
          nextDueDate: tx.nextDueDate,
          type: UpcomingPaymentType.recurring,
        ));
      }
    }

    upcomingPayments.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return upcomingPayments;
  }

  /// Actualiza el widget específico de "Próximos Pagos".
  Future<void> updateUpcomingPaymentsWidget() async {
    try {
      final payments = await getUpcomingPayments();
      final jsonString = jsonEncode(payments.map((p) => p.toJson()).toList());

      await HomeWidget.saveWidgetData<String>('upcoming_payments_data', jsonString);
      await HomeWidget.updateWidget(
        name: 'UpcomingPaymentsWidgetProvider',
        androidName: 'UpcomingPaymentsWidgetProvider',
      );
    } catch (e) {
      developer.log('🔥 Error en updateUpcomingPaymentsWidget: $e', name: _logName);
    }
  }
}