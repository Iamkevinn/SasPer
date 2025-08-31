// lib/services/widget_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';
// NOVEDAD: Importamos SharedPreferences para leer las claves en segundo plano.
import 'package:shared_preferences/shared_preferences.dart';

// --- Constante de Logging ---
const String _logName = 'WidgetService';

/// Callback de nivel superior para la actualización periódica en segundo plano.
/// Este es el punto de entrada para TODAS las actualizaciones de widgets que se
/// ejecutan cuando la app está cerrada.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  developer.log('🚀 [BACKGROUND] Callback de HomeWidget iniciado.', name: _logName);
  
  // 1. Leer las claves guardadas desde SharedPreferences.
  final prefs = await SharedPreferences.getInstance();
  final supabaseUrl = prefs.getString('supabase_url');
  final supabaseApiKey = prefs.getString('supabase_api_key');

  if (supabaseUrl == null || supabaseApiKey == null) {
    developer.log('🔥 [BACKGROUND] ERROR: No se encontraron las claves de Supabase en SharedPreferences. Abortando actualización.', name: _logName);
    return; // No podemos continuar sin las claves.
  }

  try {
    // 2. Inicializar una instancia de Supabase DENTRO de este Isolate de fondo.
    // Usamos `Supabase.initialize` para configurar el singleton para este hilo.
    // Esto es SEGURO y NECESARIO.
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseApiKey);
    developer.log('✅ [BACKGROUND] Supabase inicializado correctamente en segundo plano.', name: _logName);

    // 3. Ahora que Supabase está listo, llamamos a nuestros métodos de actualización.
    // Estos métodos ahora pueden usar `Supabase.instance.client` de forma segura.
    await WidgetService.updateFinancialHealthWidget();
    await WidgetService.updateMonthlyComparisonWidget();
    await WidgetService.updateGoalsWidget();
    await WidgetService.updateUpcomingPaymentsWidget();
    await WidgetService.updateNextPaymentWidget();
    
    developer.log('✅ [BACKGROUND] Todas las tareas de actualización de widgets han sido llamadas.', name: _logName);

  } catch (e) {
    developer.log('🔥 [BACKGROUND] ERROR FATAL durante la actualización de widgets en segundo plano: $e', name: _logName);
  }
}

/// Clase de servicio que encapsula toda la lógica para los widgets de la pantalla de inicio.
class WidgetService {
  //static const String _healthWidgetName = 'FinancialHealthWidgetProvider';
  //static const String _comparisonWidgetName = 'MonthlyComparisonWidgetProvider';

  //============================================================================
  // SECCIÓN DE WIDGETS PRINCIPALES (Dashboard: Pequeño, Mediano, Grande)
  //============================================================================

  /// Prepara y guarda todos los datos necesarios para los widgets del dashboard.
  ///
  /// Esta función debe ser llamada desde el hilo principal de la UI, ya que
  /// contiene operaciones de renderizado (`dart:ui`) que no pueden ejecutarse
  /// en un Isolate secundario.
  static const String _goalsWidgetName = 'GoalsWidgetProvider';
  Future<void> updateAllWidgets(
      DashboardData data, BuildContext context) async {
    developer.log(
        '🚀 [UI_THREAD] Iniciando actualización completa de todos los widgets.',
        name: _logName);

    try {
      // 1. Formatear datos simples.
      final formattedBalance =
          NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
              .format(data.totalBalance);

      // 2. Serializar datos complejos a JSON.
      final budgetsJson =
          jsonEncode(data.featuredBudgets.map((b) => b.toJson()).toList());
      final transactionsJson = jsonEncode(
          data.recentTransactions.take(3).map((tx) => tx.toJson()).toList());

      // 3. Crear y guardar la imagen del gráfico (operación de UI/CPU).
      String? finalChartPath;
      if (data.expenseSummaryForWidget.isNotEmpty) {
        developer.log('📊 [UI_THREAD] Creando imagen del gráfico...',
            name: _logName);
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        final chartBytes = await _createChartImageFromData(
            data.expenseSummaryForWidget,
            isDarkMode: isDarkMode);

        if (chartBytes != null) {
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_chart.png');
          await file.writeAsBytes(chartBytes);
          finalChartPath = file.path;
          developer.log(
              '✅ [UI_THREAD] Imagen del gráfico guardada en: $finalChartPath',
              name: _logName);
        }
      }

      // 4. Persistir todos los datos usando HomeWidget.
      // Estas llamadas son asíncronas pero rápidas (escriben en SharedPreferences).
      await HomeWidget.saveWidgetData<String>(
          'total_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>(
          'widget_chart_path', finalChartPath ?? "");
      await HomeWidget.saveWidgetData<String>(
          'featured_budgets_json', budgetsJson);
      await HomeWidget.saveWidgetData<String>(
          'recent_transactions_json', transactionsJson);

      // 5. Notificar a los widgets nativos que sus datos han cambiado y deben redibujarse.
      await HomeWidget.updateWidget(name: 'SasPerMediumWidgetProvider');
      await HomeWidget.updateWidget(name: 'SasPerLargeWidgetProvider');
      // Asegúrate de incluir aquí los nombres de todos tus providers.
      // await HomeWidget.updateWidget(name: 'SasPerSmallWidgetProvider');

      developer.log('✅ [UI_THREAD] Actualización de widgets completada.',
          name: _logName);
    } catch (e, st) {
      developer.log('🔥🔥🔥 [UI_THREAD] ERROR FATAL al actualizar widgets: $e',
          name: _logName, error: e, stackTrace: st);
    }
  }

  static Future<void> updateFinancialHealthWidget() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
          "WidgetService: No hay usuario, no se puede actualizar el widget.");
      return;
    }

    try {
      debugPrint(
          "WidgetService: Llamando a RPC get_financial_health_metrics...");

      // 1. Llamar a la función SQL a través de RPC.
      // Usamos .select().single() para asegurarnos de que obtenemos un solo objeto Map
      // en lugar de una Lista, lo que simplifica el manejo.
      final data = await supabase
          .rpc('get_financial_health_metrics',
              params: {'user_id_param': user.id})
          .select()
          .single();

      if (kDebugMode) {
        print("📊 Datos recibidos de Supabase: $data");
      }

      // 2. Extraer los datos del Map. Los nombres de las claves aquí
      // coinciden con los nombres de las columnas devueltas por tu función SQL.
      final double spendingPace =
          (data['w_spending_pace'] as num?)?.toDouble() ?? 0.0;
      final double savingsRate =
          (data['w_savings_rate'] as num?)?.toDouble() ?? 0.0;
      // Puedes extraer los otros valores si los necesitas en el futuro
      // final String topCategory = data['w_top_category'] as String? ?? 'Ninguno';
      // final double topAmount = (data['w_top_amount'] as num?)?.toDouble() ?? 0.0;

      // 3. Guardar los datos para el widget USANDO LAS CLAVES CORRECTAS.
      // Este es el paso crucial. Las claves aquí deben coincidir con las que el
      // código Kotlin usa en `getNumberSafely("...")`.
      await HomeWidget.saveWidgetData<double>(
          'w_health_spending_pace', spendingPace);
      await HomeWidget.saveWidgetData<double>(
          'w_health_savings_rate', savingsRate);

      debugPrint(
          "WidgetService: Datos guardados. Ritmo: $spendingPace, Ahorro: $savingsRate");

      // 4. Notificar al sistema Android que el widget debe redibujarse.
      // El 'name' debe coincidir con el nombre de tu clase Kotlin.
      await HomeWidget.updateWidget(
        name: 'FinancialHealthWidgetProvider',
        androidName: 'FinancialHealthWidgetProvider',
      );

      debugPrint("✅ Widget de Salud Financiera actualizado exitosamente.");
    } catch (e, stackTrace) {
      debugPrint(
          "🔥🔥🔥 ERROR al actualizar el widget de Salud Financiera: $e");
      debugPrint(stackTrace.toString());
      // Opcional: podrías guardar valores por defecto para que el widget no se quede vacío
      await HomeWidget.saveWidgetData<double>('w_health_spending_pace', 0.0);
      await HomeWidget.saveWidgetData<double>('w_health_savings_rate', 0.0);
      await HomeWidget.updateWidget(
          name: 'FinancialHealthWidgetProvider',
          androidName: 'FinancialHealthWidgetProvider');
    }
  }

  static Future<void> updateMonthlyComparisonWidget() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
          "WidgetService: No hay usuario, no se puede actualizar el widget de comparación.");
      return;
    }

    try {
      debugPrint("WidgetService: Llamando a RPC get_monthly_comparison...");

      // 1. Llama a la nueva función SQL y obtén un único resultado.
      final data = await supabase
          .rpc('get_monthly_comparison', params: {'user_id_param': user.id})
          .select()
          .single();

      if (kDebugMode) {
        print("📊 Datos de comparación recibidos de Supabase: $data");
      }

      // 2. Extrae los valores. Las claves coinciden con las columnas de la función SQL.
      final double currentSpending =
          (data['current_month_spending'] as num?)?.toDouble() ?? 0.0;
      final double previousSpending =
          (data['previous_month_spending'] as num?)?.toDouble() ?? 0.0;

      // 3. [PASO CLAVE] Guarda los datos como STRING.
      // Tu código Kotlin ya espera recibir Strings, lo cual es muy robusto.
      await HomeWidget.saveWidgetData<String>(
          'comp_current_spending', currentSpending.toString());
      await HomeWidget.saveWidgetData<String>(
          'comp_previous_spending', previousSpending.toString());

      debugPrint(
          "WidgetService: Datos de comparación guardados. Actual: $currentSpending, Anterior: $previousSpending");

      // 4. Notifica al sistema para que redibuje el widget.
      // El nombre debe coincidir con la clase de Kotlin.
      await HomeWidget.updateWidget(
        name: 'MonthlyComparisonWidgetProvider',
        androidName: 'MonthlyComparisonWidgetProvider',
      );

      debugPrint("✅ Widget de Comparación Mensual actualizado exitosamente.");
    } catch (e, stackTrace) {
      debugPrint(
          "🔥🔥🔥 ERROR al actualizar el widget de Comparación Mensual: $e");
      debugPrint(stackTrace.toString());
    }
  }

  static Future<void> updateGoalsWidget() async {
    developer.log(
        '🔄 [WidgetService] Iniciando actualización del widget de metas...',
        name: 'WidgetService');
    try {
      // 1. Usa la instancia Singleton
      final goalRepo = GoalRepository.instance;

      // 2. Llama al nuevo método que devuelve un Future
      final goals = await goalRepo.getActiveGoals();

      final goalsListForWidget = goals
          .map((goal) => {
                'name': goal.name,
                'current_amount': goal.currentAmount,
                'target_amount': goal.targetAmount,
              })
          .toList();

      // Guardar los datos para que el widget nativo los lea
      await HomeWidget.saveWidgetData<String>(
          'goals_list', json.encode(goalsListForWidget));

      // Notificar al widget que se actualice
      await HomeWidget.updateWidget(
        name: _goalsWidgetName,
        androidName: _goalsWidgetName,
      );
      developer.log(
          '✅ [WidgetService] Widget de metas actualizado con ${goals.length} metas.',
          name: 'WidgetService');
    } catch (e) {
      developer.log(
          '🔥 [WidgetService] Error al actualizar el widget de metas: $e',
          name: 'WidgetService');
    }
  }

  /// Método estático privado para generar la imagen del gráfico.
  static Future<Uint8List?> _createChartImageFromData(
    List<ExpenseByCategory> data, {
    required bool isDarkMode,
  }) async {
    try {
      final textColor = isDarkMode ? Colors.white : Colors.black;
      final subTextColor =
          isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;
      final positiveData = data
          .map((e) => ExpenseByCategory(
              category: e.category, totalSpent: e.totalSpent.abs()))
          .toList();

      const double width = 400;
      const double height = 200;

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
            paint);
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

        final textStyle = TextStyle(
            color: textColor, fontSize: 15, fontWeight: FontWeight.w500);
        final pctStyle = TextStyle(
            color: subTextColor, fontSize: 14, fontWeight: FontWeight.normal);

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
      // Este log es crucial para capturar errores de renderizado.
      developer.log(
          '🔥🔥🔥 [ChartCreator] ERROR FATAL al crear la imagen del gráfico: $e',
          name: _logName,
          error: e,
          stackTrace: stackTrace);
      return null;
    }
  }

  //============================================================================
  // SECCIÓN DE WIDGET DE PRÓXIMOS PAGOS
  //============================================================================

  //============================================================================
  // SECCIÓN DE WIDGET DE PRÓXIMOS PAGOS (VERSIÓN FINAL Y CORRECTA)
  //============================================================================

  static Future<List<UpcomingPayment>> getUpcomingPayments() async {
    developer.log(
        '🔄 [WidgetService] Obteniendo datos para el widget de Próximos Pagos...',
        name: _logName);
    final List<UpcomingPayment> upcomingPayments = [];

    // --- Obtener Deudas (Esta parte ya está validada y es correcta) ---
    final debtRepo = DebtRepository.instance;
    final debts = await debtRepo.getActiveDebts();

    for (var debt in debts) {
      // CORRECTO: Usamos los campos `dueDate` y `currentBalance` del modelo `Debt`.
      if (debt.dueDate != null && debt.currentBalance > 0) {
        upcomingPayments.add(UpcomingPayment(
          id: 'debt_${debt.id}',
          concept: debt.name,
          amount: debt.currentBalance,
          nextDueDate: debt.dueDate!,
          type: UpcomingPaymentType.debt,
        ));
      }
    }

    // --- Obtener Transacciones Recurrentes (AHORA CON LA LÓGICA CORRECTA) ---
    // CORRECTO: Usamos la instancia Singleton del repositorio.
    final recurringRepo = RecurringRepository.instance;

    // CORRECTO: Usamos el método `getAll()` que existe en el repositorio.
    final recurringTxs = await recurringRepo.getAll();

    for (var tx in recurringTxs) {
      // LÓGICA FINAL Y CORRECTA:
      // Un pago recurrente es "próximo" si su `nextDueDate` es en el futuro.
      // No necesitamos verificar `endDate` aquí, porque asumimos que el backend
      // o una función de base de datos ya no generará una `nextDueDate` futura
      // si la transacción ha superado su `endDate`.
      if (tx.nextDueDate.isAfter(DateTime.now())) {
        upcomingPayments.add(UpcomingPayment(
          id: 'rec_${tx.id}',
          // CORRECTO: Usamos los campos `description`, `amount` y `nextDueDate` del modelo `RecurringTransaction`.
          concept: tx.description,
          amount: tx.amount,
          nextDueDate: tx.nextDueDate,
          type: UpcomingPaymentType.recurring,
        ));
      }
    }

    // Ordena la lista combinada para mostrar los pagos más cercanos primero.
    upcomingPayments.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    developer.log(
        '✅ [WidgetService] Se encontraron ${upcomingPayments.length} pagos próximos.',
        name: _logName);
    return upcomingPayments;
  }

  //============================================================================
  // [NUEVO] SECCIÓN DE WIDGET DE PRÓXIMO PAGO INDIVIDUAL
  //============================================================================
  static Future<void> updateNextPaymentWidget() async {
    developer.log(
        '🚀 [WidgetService] Iniciando actualización del widget de Próximo Pago Individual.',
        name: _logName);
    try {
      // 1. Reutilizamos la lógica que ya tenemos para obtener TODOS los pagos ordenados.
      final allPayments = await getUpcomingPayments();

      if (allPayments.isNotEmpty) {
        // 2. Tomamos solo el primer elemento de la lista.
        final nextPayment = allPayments.first;
        
        // 3. Lo convertimos a JSON.
        final jsonString = jsonEncode(nextPayment.toJson());

        // 4. Lo guardamos en SharedPreferences con una clave ÚNICA para este widget.
        await HomeWidget.saveWidgetData<String>('next_payment_data', jsonString);
        developer.log(
            '✅ [WidgetService] Próximo pago ("${nextPayment.concept}") guardado para el widget.',
            name: _logName);

      } else {
        // 5. Si no hay pagos, guardamos un valor nulo o vacío para que Kotlin lo sepa.
        await HomeWidget.saveWidgetData<String?>('next_payment_data', null);
        developer.log(
            '✅ [WidgetService] No hay pagos pendientes, se limpiaron los datos del widget.',
            name: _logName);
      }

      // 6. Notificamos al widget específico que debe actualizarse.
      await HomeWidget.updateWidget(
        name: 'NextPaymentWidgetProvider', // Debe coincidir con el nombre de la clase en Kotlin
        androidName: 'NextPaymentWidgetProvider',
      );

    } catch (e, st) {
      developer.log('🔥🔥🔥 Error en updateNextPaymentWidget: $e',
          name: _logName, error: e, stackTrace: st);
    }
  }
  
  // La función `updateUpcomingPaymentsWidget` se mantiene igual, ya que solo llama a la anterior.
  static Future<void> updateUpcomingPaymentsWidget() async {
    developer.log(
        '🚀 [WidgetService] Iniciando actualización del widget de Próximos Pagos.',
        name: _logName);
    try {
      final payments = await getUpcomingPayments();
      final jsonString = jsonEncode(payments.map((p) => p.toJson()).toList());
      await HomeWidget.saveWidgetData<String>(
          'upcoming_payments_data', jsonString);
      await HomeWidget.updateWidget(
        name: 'UpcomingPaymentsWidgetProvider',
        androidName: 'UpcomingPaymentsWidgetProvider',
      );
      developer.log(
          '✅ [WidgetService] Widget de Próximos Pagos notificado para actualizar.',
          name: _logName);
    } catch (e, st) {
      developer.log('🔥🔥🔥 Error en updateUpcomingPaymentsWidget: $e',
          name: _logName, error: e, stackTrace: st);
    }
  }
}
