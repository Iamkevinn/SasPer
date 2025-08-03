// Archivo: lib/services/widget_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/models/upcoming_payment_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Constante para el nombre del log
const String _logName = 'WidgetService';

/// Callback para ejecución en segundo plano.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  developer.log('🚀 [BACKGROUND] 1. Callback INICIADO.', name: _logName);

  try {
    // PASO 1: INICIALIZACIÓN SEGURA Y ROBUSTA DE SUPABASE
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    developer.log('ℹ️ [BACKGROUND] 2. Supabase inicializado.', name: _logName);

    final client = Supabase.instance.client;

    // PASO 2: VERIFICACIÓN Y RECUPERACIÓN DE SESIÓN
    // En lugar de solo comprobar, escuchamos el estado de autenticación.
    // Esto asegura que esperamos a que la sesión se restaure si es necesario.
    final completer = Completer<User?>();
    final authSubscription = client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && !completer.isCompleted) {
        developer.log('✅ [BACKGROUND] 3. Sesión de usuario VÁLIDA. User ID: ${session.user.id}', name: _logName);
        completer.complete(session.user);
      } else if (!completer.isCompleted) {
        developer.log('ℹ️ [BACKGROUND] 3b. Esperando sesión...', name: _logName);
      }
    });

    // Si ya hay un usuario, completamos inmediatamente.
    if (client.auth.currentUser != null) {
      if (!completer.isCompleted) {
         developer.log('✅ [BACKGROUND] 3a. Sesión de usuario ya estaba disponible.', name: _logName);
         completer.complete(client.auth.currentUser);
      }
    }

    // Esperamos un máximo de 5 segundos por la sesión.
    final user = await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      developer.log('⚠️ [BACKGROUND] ERROR CRÍTICO: Timeout esperando la sesión de usuario.', name: _logName);
      return null;
    });

    authSubscription.cancel();

    if (user == null) {
      return; // No podemos continuar sin un usuario.
    }

    // PASO 3: OBTENER Y ACTUALIZAR DATOS
    developer.log('[BACKGROUND] 4. Obteniendo datos del dashboard...', name: _logName);
    DashboardRepository.instance.initialize(client);
    final dashboardData = await DashboardRepository.instance.fetchDataForWidget();

    if (dashboardData != null) {
      developer.log('[BACKGROUND] 5a. Datos obtenidos con ÉXITO. Balance: ${dashboardData.totalBalance}', name: _logName);
      await WidgetService.updateAllWidgetData(data: dashboardData);
    } else {
      developer.log('⚠️ [BACKGROUND] 5b. Los datos del dashboard son NULL.', name: _logName);
    }

  } catch (e, stackTrace) {
    developer.log(
        '🔥🔥🔥 [BACKGROUND] 6. ERROR FATAL INESPERADO en el callback: $e',
        name: _logName,
        error: e,
        stackTrace: stackTrace);
  }
}

class WidgetService {
  static StreamSubscription? _dashboardSubscription;

  /// Escucha los cambios en los datos del dashboard y actualiza los widgets automáticamente.
  static void listenToDashboardChanges() {
    // Si ya estamos escuchando, cancelamos para evitar duplicados.
    _dashboardSubscription?.cancel();
    
    // Asumo que tu repositorio tiene un stream llamado 'dashboardStream' o similar.
    // ¡Ajusta el nombre si es diferente!
    _dashboardSubscription = DashboardRepository.instance.getDashboardDataStream().listen((dashboardData) {
      developer.log('✅ [WidgetService] ¡Nuevos datos recibidos del stream! Actualizando widgets...', name: _logName);
      // Llamamos a la función que ya teníamos.
      updateAllWidgetData();
        }, onError: (e) {
        developer.log('🔥 [WidgetService] Error en el stream del dashboard: $e', name: _logName);
    });

    developer.log('🎧 [WidgetService] Ahora escuchando cambios del dashboard.', name: _logName);
  }

  /// Detiene la escucha de cambios.
  static void cancelListening() {
    _dashboardSubscription?.cancel();
    developer.log('🔇 [WidgetService] Se ha dejado de escuchar los cambios del dashboard.', name: _logName);
  }
  // =======================

  Future<List<UpcomingPayment>> getUpcomingPayments() async {
    final List<UpcomingPayment> upcomingPayments = [];

    // 1. Obtener deudas activas
    final debts = await DebtRepository.instance.getActiveDebts(); // Asumo que tienes un método así
    for (var debt in debts) {
      // Lógica para determinar la próxima fecha de pago de la deuda si es recurrente
      // Por ahora, usaremos 'due_date' como ejemplo
      if (debt.dueDate != null && debt.dueDate!.isAfter(DateTime.now())) {
        
        upcomingPayments.add(UpcomingPayment(
          id: debt.id,
          concept: debt.name,
          
          // AHORA (Correcto): Usamos el saldo actual de la deuda.
          amount: debt.currentBalance, 
          
          // AHORA (Correcto): Usamos '!' porque ya comprobamos que no es nulo.
          nextDueDate: debt.dueDate!, 
          
          type: UpcomingPaymentType.debt,
          iconName: 'debt_icon', 
        ));
      }
    }

    // 2. Obtener transacciones recurrentes
    final recurringTxs = await RecurringRepository.instance.getAll(); // Asumo un método así
    for (var tx in recurringTxs) {
      // *** LÓGICA CRÍTICA ***
      // Aquí debes calcular la próxima fecha de vencimiento real basada en la frecuencia (tx.frequency)
      // y la última fecha de pago. Esto es lo más complejo.
      //final DateTime nextDate = _calculateNextDueDate(tx.startDate, tx.frequency);

    if (tx.nextDueDate.isAfter(DateTime.now())) {
          upcomingPayments.add(UpcomingPayment(
          id: tx.id,
          concept: tx.description,
          amount: tx.amount,
          nextDueDate: tx.nextDueDate, // ¡Mucho más simple!
          type: UpcomingPaymentType.recurring,
          // iconName: tx.categoryIcon, // Puedes añadir esto si tu modelo lo tiene
        ));
      }
    }

    // 3. Ordenar por fecha más próxima
    upcomingPayments.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    return upcomingPayments;
  }

  // Función de ejemplo para calcular la próxima fecha. Deberás ajustarla a tu lógica.
//  DateTime _calculateNextDueDate(DateTime startDate, String frequency) {
//    DateTime now = DateTime.now();
//    DateTime nextDate = startDate;
//
//    if (frequency == 'monthly') {
//      while (nextDate.isBefore(now)) {
//        nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
//      }
//    } else if (frequency == 'weekly') {
//      while (nextDate.isBefore(now)) {
//        nextDate = nextDate.add(const Duration(days: 7));
//      }
//    }
//    // Añadir más lógicas para 'daily', 'yearly', etc.
//    return nextDate;
//  }

  // ¡NUEVO MÉTODO PARA ACTUALIZAR ESTE WIDGET ESPECÍFICO!
  Future<void> updateUpcomingPaymentsWidget() async {
      try {
        final payments = await getUpcomingPayments();
        // Serializamos la lista completa a un string JSON
        final jsonString = jsonEncode(payments.map((p) => p.toJson()).toList());

        // Guardamos usando una clave única para este widget
        await HomeWidget.saveWidgetData<String>('upcoming_payments_data', jsonString);
        await HomeWidget.updateWidget(
          name: 'UpcomingPaymentsWidgetProvider', // Usaremos este nombre en Kotlin
          androidName: 'UpcomingPaymentsWidgetProvider',
        );
      } catch (e) {
        // Manejar errores
      }
  }
  
  static Future<void> updateAllWidgetData({DashboardData? data}) async {
    developer.log('[Service] 7. Guardando datos para todos los widgets...', name: _logName);
    try {
      // ====> LA NUEVA LÓGICA DIRECTA <====

      // 1. Obtenemos el cliente de Supabase.
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) {
        developer.log('⚠️ [Service] No hay usuario para actualizar el widget. Abortando.', name: _logName);
        return;
      }

      // 2. Ejecutamos las llamadas RPC directamente desde aquí.
      final results = await Future.wait([
        client.rpc('get_dashboard_balance', params: {'p_user_id': userId}),
        client.rpc('get_budgets_progress_for_user', params: {'p_user_id': userId}),
        client.rpc('get_dashboard_details', params: {'p_user_id': userId}), // Para las transacciones
      ]);

      // 3. Parseamos los datos directamente.
      final balanceMap = results[0] as Map<String, dynamic>? ?? {};
      final budgetsData = results[1] as List<dynamic>? ?? [];
      final detailsMap = results[2] as Map<String, dynamic>? ?? {};

      final totalBalance = (balanceMap['total_balance'] as num? ?? 0).toDouble();
      
      final featuredBudgets = budgetsData
          .map((item) => BudgetProgress.fromMap(item as Map<String, dynamic>))
          .toList();
      
      final recentTransactions = (detailsMap['recent_transactions'] as List<dynamic>? ?? [])
          .map((item) => Transaction.fromMap(item as Map<String, dynamic>))
          .toList();

      developer.log('✅ [Service] Datos obtenidos directamente. Presupuestos: ${featuredBudgets.length}, Transacciones: ${recentTransactions.length}', name: _logName);

      // 4. Formateamos y guardamos los datos (lógica existente).
      final formattedBalance = NumberFormat.currency(
        locale: 'es_CO',
        symbol: '\$',
        decimalDigits: 0,
      ).format(totalBalance);

      final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      final isDarkMode = brightness == Brightness.dark;
      developer.log('ℹ️ [Service] 8a. Modo oscuro detectado: $isDarkMode', name: _logName);

      // (El código para generar el gráfico no necesita cambios)
      final analysisRepo = AnalysisRepository();
      final expenseData = await analysisRepo.getExpenseSummaryForWidget();
      String? chartPath;
      if (expenseData.isNotEmpty) {
        final chartBytes = await _createChartImageFromData(expenseData, isDarkMode: isDarkMode);
        if (chartBytes != null) {
          final dir = await getApplicationSupportDirectory();
          final path = '${dir.path}/widget_chart.png';
          final file = File(path);
          await file.writeAsBytes(chartBytes);
          chartPath = file.path;
          developer.log('✅ [Service] 8b. Imagen de gráfico guardada en: $path', name: _logName);
        }
      }

      // 5. Codificamos a JSON los datos que acabamos de obtener.
      final budgetsJson = jsonEncode(featuredBudgets.map((b) => b.toJson()).toList());
      final transactionsJson = jsonEncode(recentTransactions.take(3).map((tx) => tx.toJson()).toList());

      // 6. Guardamos los datos en el widget.
      await HomeWidget.saveWidgetData<String>('total_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>('widget_chart_path', chartPath ?? "");
      await HomeWidget.saveWidgetData<String>('featured_budgets_json', budgetsJson);
      await HomeWidget.saveWidgetData<String>('budgets_json', budgetsJson); // Clave duplicada por seguridad
      await HomeWidget.saveWidgetData<String>('recent_transactions_json', transactionsJson);

      // 7. Actualizamos los widgets.
      await HomeWidget.updateWidget(name: 'SasPerWidgetProvider');
      await HomeWidget.updateWidget(name: 'SasPerMediumWidgetProvider');
      await HomeWidget.updateWidget(name: 'SasPerLargeWidgetProvider');

      developer.log('✅ [Service] 9. Datos guardados y widgets actualizados con ÉXITO.', name: _logName);
    } catch (e, stackTrace) {
      developer.log('🔥 [Service] Error durante el guardado de datos del widget: $e', name: _logName, error: e, stackTrace: stackTrace);
    }
  }

  /// Genera una imagen de un gráfico de tarta a partir de los datos.
  /// Ahora acepta [isDarkMode] para ajustar los colores del texto.
  static Future<Uint8List?> _createChartImageFromData(
    List<ExpenseByCategory> data, {
    required bool isDarkMode,
  }) async {
    try {
      // ===== CAMBIO CLAVE: DEFINIR COLORES DE TEXTO SEGÚN EL TEMA =====
      final textColor = isDarkMode ? Colors.white : Colors.black;
      final subTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;

      final positiveData = data.map((e) => ExpenseByCategory(category: e.category, totalSpent: e.totalSpent.abs())).toList();
      
      final double width = 400;
      final double height = 200;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
      canvas.drawPaint(Paint()..color = Colors.transparent);

      final colors = [
        Colors.blue.shade400, Colors.red.shade400, Colors.green.shade400,
        Colors.orange.shade400, Colors.purple.shade400, Colors.yellow.shade700,
      ];

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
        canvas.drawArc(
          Rect.fromCircle(center: chartCenter, radius: chartRadius),
          startAngle, sweepAngle, true, paint,
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

        // Usamos los colores dinámicos que definimos arriba
        final textStyle = TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500);
        final pctStyle = TextStyle(color: subTextColor, fontSize: 14, fontWeight: FontWeight.normal);
        
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
      developer.log('🔥🔥🔥 [ChartCreator] ERROR FATAL al crear la imagen del gráfico: $e', name: _logName, error: e, stackTrace: stackTrace);
      return null;
    }
  }
}