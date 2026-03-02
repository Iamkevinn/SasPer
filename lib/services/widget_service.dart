// lib/services/widget_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/models/upcoming_payment_model.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// NOVEDAD: Importamos SharedPreferences para leer las claves en segundo plano.
import 'package:sasper/data/analysis_repository.dart'; // <-- AÑADIR ESTA IMPORTACIÓN
import 'package:sasper/models/manifestation_model.dart';

// --- Constante de Logging ---
const String _logName = 'WidgetService';

/// Callback de nivel superior para la actualización periódica en segundo plano.
/// Este es el punto de entrada para TODAS las actualizaciones de widgets que se
/// ejecutan cuando la app está cerrada.
// =====> AÑADE ESTA NUEVA FUNCIÓN <=====
  Future<void> handleWidgetAction(String action) async {
    // La inicialización de Supabase ya la hace el router central,
    // así que podemos llamar directamente a los métodos de actualización.
    developer.log(
        '🚀 [BACKGROUND-ROUTED] Acción recibida para widget financiero: $action',
        name: _logName);
        
    try {
      // Aquí replicamos lo que hacía la antigua `backgroundCallback`.
      // Si el propósito del callback era actualizar todo, hacemos eso.
      // Si era para acciones específicas, las pondríamos en un switch.
      // Basado en tu código, parece que una actualización general es lo correcto.
      
      // Asumimos que la acción principal es refrescar todos los datos
      if (action == 'refresh' || action == 'updateAll' || action == 'refresh_next_payment') { // O cualquier acción que uses
          await WidgetService.updateFinancialHealthWidget();
          await WidgetService.updateMonthlyComparisonWidget();
          await WidgetService.updateGoalsWidget();
          await WidgetService.updateUpcomingPaymentsWidget();
          await WidgetService.updateNextPaymentWidget();
          developer.log(
              '✅ [BACKGROUND-ROUTED] Todas las actualizaciones financieras completadas.',
              name: _logName);
      } else {
           developer.log(
              '❓ [BACKGROUND-ROUTED] Acción "$action" no manejada para widgets financieros.',
              name: _logName);
      }
      
    } catch (e) {
      developer.log(
          '🔥 [BACKGROUND-ROUTED] ERROR FATAL durante la actualización: $e',
          name: _logName);
    }
  }

Future<void> saveManifestationsToWidget(
    List<Manifestation> manifestations) async {
  if (manifestations.isEmpty) return;

  // 1. Convertimos la lista completa a un JSON que Kotlin pueda entender.
  //    Esto es CRUCIAL para que los botones "siguiente/anterior" funcionen.
  final List<Map<String, String?>> widgetDataList = manifestations.map((m) {
    return {
      'title': m.title,
      'description': m.description ?? "", // Incluimos la descripción
      'image_url': m.imageUrl,
    };
  }).toList();
  final String jsonStringList = jsonEncode(widgetDataList);

  // 2. Guardamos la lista completa. La clave 'manifestations_list' coincide con KEY_LIST en Kotlin.
  await HomeWidget.saveWidgetData<String>(
      'manifestations_list', jsonStringList);

  // 3. Guardamos los datos del primer elemento para la vista inicial.
  final Manifestation firstManifestation = manifestations.first;
  await HomeWidget.saveWidgetData<String>('manifestation_index', '0');
  await HomeWidget.saveWidgetData<String>(
      'manifestation_title', firstManifestation.title);
  // AÑADIDO: Guardamos la descripción del primer elemento.
  await HomeWidget.saveWidgetData<String>(
      'manifestation_description', firstManifestation.description ?? "");
  await HomeWidget.saveWidgetData<String>(
      'manifestation_image_path', firstManifestation.imageUrl ?? "");

  // 4. Actualizamos el widget.
  await HomeWidget.updateWidget(
    androidName: 'ManifestationWidgetProvider',
  );
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

  // ---> CREA ESTA NUEVA FUNCIÓN <---
  /// Orquesta la actualización de TODOS los widgets desde el hilo principal.
  /// Llama a los métodos individuales que actualizan cada tipo de widget.
  Future<void> updateAllWidgetsFromDashboard(
      DashboardData data, BuildContext context) async {
        // Verificar timestamps antes de actualizar
    final lastUpdate = await HomeWidget.getWidgetData<int>(
      'last_update_timestamp',
      defaultValue: 0,
    );
    
    if (lastUpdate != null && 
        DateTime.now().millisecondsSinceEpoch - lastUpdate < 5000) {
      developer.log('⏱️ Actualización demasiado reciente, saltando...');
      return;
    }

    if (!context.mounted) return; 

    // 1. Llama a la función que ya tenías para los widgets principales.
    await updateAllWidgets(data, context);

    // 2. Llama explícitamente a las funciones de actualización para los otros widgets.
    //    Estas funciones ya están diseñadas para funcionar en segundo plano,
    //    por lo que también funcionarán perfectamente aquí.
    developer.log(
        '🚀 [UI_THREAD] Disparando actualizaciones para widgets secundarios...',
        name: _logName);
    await Future.wait([
      WidgetService.updateFinancialHealthWidget(),
      WidgetService.updateMonthlyComparisonWidget(),
      WidgetService.updateGoalsWidget(),
      WidgetService.updateUpcomingPaymentsWidget(),
      WidgetService.updateNextPaymentWidget(),
    ]);

    developer.log(
        '✅ [UI_THREAD] Todas las actualizaciones de widgets han sido llamadas.',
        name: _logName);
  }

  Future<void> updateAllWidgets(
      DashboardData data, BuildContext context) async {
    developer.log(
        '🚀 [UI_THREAD] Iniciando actualización completa de todos los widgets.',
        name: _logName);

    developer.log(
        '📊 Datos recibidos: Balance=${data.totalBalance}, Presupuestos=${data.featuredBudgets.length}, Transacciones=${data.recentTransactions.length}',
        name: _logName);

    try {
      // 1. Formatear datos simples.
      final formattedBalance =
          NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
              .format(data.totalBalance);

      // ====================================================================
      // 2. [CORRECCIÓN DEFINITIVA] Serializar datos complejos a JSON.
      // ====================================================================
      final budgetsJson = jsonEncode(data.featuredBudgets
          .map((b) => {
                // La clave 'category_name' es la que espera Kotlin.
                // El valor viene de 'b.category' según tu modelo.
                'category_name': b.category,
                'progress': b.progress,
              })
          .toList());

      final transactionsJson = jsonEncode(data.recentTransactions
          .take(3)
          .map((tx) => {
                'description': tx.description,
                // 'tx.category' ya es un String, lo pasamos directamente.
                'category': tx.category,
                'amount': tx.amount,
                // 'tx.type' ya es un String, lo pasamos directamente.
                'type': tx.type,
              })
          .toList());

      // Logs para verificar el JSON que estamos generando
      developer.log('SAVING BUDGETS JSON -> $budgetsJson',
          name: 'WidgetService-SAVE');
      developer.log('SAVING TRANSACTIONS JSON -> $transactionsJson',
          name: 'WidgetService-SAVE');
      // ====================================================================

      // 3. Crear y guardar la imagen del gráfico (tu código existente).
      String? finalChartPath;
      if (data.expenseSummaryForWidget.isNotEmpty) {
        // ... tu código para generar el gráfico se mantiene igual ...
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final chartBytes = await _createChartImageFromData(
            data.expenseSummaryForWidget,
            isDarkMode: isDarkMode);
        if (chartBytes != null) {
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_dashboard_chart.png');
          await file.writeAsBytes(chartBytes);
          finalChartPath = file.path;
        }
      }

      // 4. Persistir todos los datos usando HomeWidget.
      await HomeWidget.saveWidgetData<String>(
          'total_balance', formattedBalance);
      await HomeWidget.saveWidgetData<String>(
          'widget_chart_path', finalChartPath ?? "");
      await HomeWidget.saveWidgetData<String>(
          'featured_budgets_json', budgetsJson);
      await HomeWidget.saveWidgetData<String>(
          'recent_transactions_json', transactionsJson);

      // 5. Notificar a los widgets nativos.
      await HomeWidget.updateWidget(name: 'SasPerMediumWidgetProvider');
      await HomeWidget.updateWidget(name: 'SasPerLargeWidgetProvider');

      developer.log('✅ [UI_THREAD] Actualización de widgets completada.',
          name: _logName);
    } catch (e, st) {
      developer.log('🔥🔥🔥 [UI_THREAD] ERROR FATAL al actualizar widgets: $e',
          name: _logName, error: e, stackTrace: st);
    }
  }

  //============================================================================
// [NUEVO] SECCIÓN DE WIDGET DE MANIFESTACIÓN
//============================================================================

  /// Actualiza el widget de manifestación con los datos de una manifestación específica.
  /// Esta función debe ser llamada desde la UI cuando el usuario selecciona qué manifestar.
  /// // Este método guarda la lista de IDs y el índice inicial (0)
  /// 
  
  static Future<void> setManifestationForWidget(
      Manifestation manifestation) async {
    developer.log(
        '🚀 [UI_THREAD] Fijando manifestación "${manifestation.title}" para el widget.',
        name: _logName);
    try {
      String? finalImagePath;

      // 1. Si la imagen es una URL remota, la descargamos localmente.
      // 1. Verificamos si existe una imagen primero
      if (manifestation.imageUrl != null &&
          manifestation.imageUrl!.isNotEmpty) {
        final imageUrl = manifestation.imageUrl!.trim();

        if (imageUrl.startsWith('http')) {
          // Imagen remota: descargar
          final httpClient = HttpClient();
          final request = await httpClient.getUrl(Uri.parse(imageUrl));
          final response = await request.close();
          if (response.statusCode == 200) {
            final bytes = await consolidateHttpClientResponseBytes(response);
            final dir = await getApplicationSupportDirectory();
            final file = File('${dir.path}/manifestation_image.png');
            await file.writeAsBytes(bytes);
            finalImagePath = file.path;
          } else {
            developer.log(
                '⚠️ No se pudo descargar la imagen. Código: ${response.statusCode}',
                name: _logName);
          }
        } else {
          // Imagen local
          finalImagePath = imageUrl;
        }
      } else {
        // No hay imagen
        developer.log('ℹ️ La manifestación no tiene imagen asociada.',
            name: _logName);
        finalImagePath = null;
      }

      // 3. Guardar los datos del widget con las claves CORRECTAS.
      await HomeWidget.saveWidgetData<String>(
          'simple_manifest_title', manifestation.title); // <-- CORREGIDO
      await HomeWidget.saveWidgetData<String>(
          'simple_manifest_description', manifestation.description ?? ""); // <-- CORREGIDO
      await HomeWidget.saveWidgetData<String>(
          'simple_manifest_image_url', finalImagePath ?? ""); // <-- CORREGIDO
      await HomeWidget.saveWidgetData<String>(
          'manifestation_id', manifestation.id);

      // 4. Notificar al widget nativo (asegúrate que el nombre coincida en Kotlin)
      var result = await HomeWidget.updateWidget(
        name: 'ManifestationWidgetProvider',
        androidName: 'ManifestationWidgetProvider',
      );

      developer.log(
          '✅ [UI_THREAD] Widget de manifestación actualizado ($result).',
          name: _logName);
    } catch (e, st) {
      developer.log(
          '🔥 [UI_THREAD] Error al actualizar el widget de manifestación: $e',
          name: _logName,
          error: e,
          stackTrace: st);
    }
  }

  static Future<void> updateFinancialHealthWidget() async {
    // La inicialización de Supabase ya está garantizada por backgroundCallback
    // por lo que no necesitamos 'Supabase.instance.client' aquí, podemos
    // confiar en el singleton del repositorio.

    developer.log(
        '🔄 [WidgetService] Actualizando widget de Salud Financiera usando AnalysisRepository...',
        name: _logName);

    try {
      // 1. [CAMBIO CLAVE] Llama al método de tu repositorio. ¡Nuestra única fuente de verdad!
      final healthInsight = await AnalysisRepository.instance
          .getFinancialHealthInsightForWidget();

      // 2. Extrae los datos del objeto que devuelve el repositorio.
      final double spendingPace = healthInsight.spendingPace;
      final double savingsRate = healthInsight.savingsRate;

      // 3. Guarda los datos para el widget. Las claves ya son correctas.
      await HomeWidget.saveWidgetData<double>(
          'w_health_spending_pace', spendingPace);
      await HomeWidget.saveWidgetData<double>(
          'w_health_savings_rate', savingsRate);

      developer.log(
          "✅ [WidgetService] Datos de salud guardados. Ritmo: $spendingPace, Ahorro: $savingsRate",
          name: _logName);

      // 4. Notifica al sistema Android para que redibuje el widget.
      await HomeWidget.updateWidget(
        name: 'FinancialHealthWidgetProvider',
        androidName: 'FinancialHealthWidgetProvider',
      );
    } catch (e, stackTrace) {
      developer.log(
          "🔥🔥🔥 ERROR al actualizar el widget de Salud Financiera: $e",
          name: _logName,
          stackTrace: stackTrace);

      // Guarda valores por defecto en caso de error.
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
      final goalRepo = GoalRepository.instance;
      final goals = await goalRepo.getActiveGoals();

      // [CORRECCIÓN] Mapeamos TODOS los campos necesarios para el widget.
      final goalsListForWidget = goals
          .map((goal) => {
                'id': goal.id, // Esencial para los clicks
                'name': goal.name,
                'current_amount': goal.currentAmount,
                'target_amount': goal.targetAmount,
                'deadline': goal.targetDate
                    ?.toIso8601String(), // Enviamos en formato estándar
                'icon_type': goal
                    .category, // Asumiendo que el ícono depende de la categoría
              })
          .toList();

      final jsonString = json.encode(goalsListForWidget);
      developer.log('SAVING GOALS DATA -> $jsonString',
          name: 'WidgetService-SAVE');

      await HomeWidget.saveWidgetData<String>('goals_list', jsonString);
      await HomeWidget.updateWidget(
        name: 'GoalsWidgetProvider', // Asegúrate de que el nombre es correcto
        androidName: 'GoalsWidgetProvider',
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

      // -----------------------------------------------------------
      // Ajustes de Dimensiones y Layout para CENTRAR
      // -----------------------------------------------------------
      const double widgetWidth = 400; // Ancho total del área de dibujo
      const double widgetHeight = 200; // Alto total del área de dibujo

      // Definimos el espacio que ocupará el gráfico de pastel
      const double pieChartAreaWidth =
          widgetWidth * 0.55; // 55% del ancho para el pastel
      const double legendAreaWidth =
          widgetWidth * 0.45; // 45% del ancho para la leyenda

      // Diámetro del pastel, ajustado para caber en su área y con un pequeño margen
      // Usamos el mínimo entre el ancho de su área y el alto total para asegurar que es un círculo
      const double chartPadding =
          40; // Espacio alrededor del pastel dentro de su área
      final double chartDiameter =
          min(pieChartAreaWidth, widgetHeight) - chartPadding;
      final double chartRadius = chartDiameter / 2;

      // Calcular el centro del pastel para que esté centrado DENTRO de su 'pieChartAreaWidth'
      // El punto de inicio de la 'pieChartAreaWidth' es 0, así que el centro es (pieChartAreaWidth / 2)
      final chartCenter = Offset(pieChartAreaWidth / 2, widgetHeight / 2);

      // Calcular el punto de inicio X de la leyenda para que empiece después del área del pastel
      final double legendStartX = pieChartAreaWidth + chartPadding / 4;
      // Ancho disponible para el texto de la leyenda dentro de su propia área
      final double legendTextMaxWidth =
          legendAreaWidth - (chartPadding * 2); // Dejar margen a ambos lados
      // -----------------------------------------------------------

      final recorder = ui.PictureRecorder();
      final canvas =
          Canvas(recorder, Rect.fromLTWH(0, 0, widgetWidth, widgetHeight));
      canvas
          .drawPaint(Paint()..color = Colors.transparent); // Fondo transparente

      final colors = [
        Colors.blue.shade400,
        Colors.red.shade400,
        Colors.green.shade400,
        Colors.orange.shade400,
        Colors.purple.shade400,
        Colors.yellow.shade700,
        Colors.teal.shade400,
        Colors.indigo.shade400,
        Colors.brown.shade400,
        Colors.cyan.shade400,
      ];

      final total =
          positiveData.fold<double>(0.0, (sum, e) => sum + e.totalSpent);
      if (total <= 0) return null;

      positiveData.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
      final int maxIndividualItems = 4;
      List<ExpenseByCategory> dataToDraw =
          positiveData.take(maxIndividualItems).toList();

      double othersAmount = 0.0;
      if (positiveData.length > maxIndividualItems) {
        othersAmount = positiveData
            .skip(maxIndividualItems)
            .fold<double>(0.0, (sum, e) => sum + e.totalSpent);
        if (othersAmount > 0) {
          dataToDraw.add(
              ExpenseByCategory(category: 'Otros', totalSpent: othersAmount));
        }
      }

      double startAngle = -pi / 2;

      // -----------------------------------------------------------
      // Dibujo del Gráfico de Pastel (sin cambios en la lógica de dibujo, solo en su centro y radio)
      // -----------------------------------------------------------
      for (var i = 0; i < dataToDraw.length; i++) {
        final item = dataToDraw[i];
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

      // -----------------------------------------------------------
      // Dibujo de la Leyenda (ajustes en el posicionamiento)
      // -----------------------------------------------------------
      // Calcular el espacio total que ocupará la leyenda verticalmente
      final double totalLegendHeight =
          dataToDraw.length * 25.0; // 25.0 es el alto de cada línea de leyenda

      // Centrar la leyenda verticalmente dentro del widgetHeight
      double legendY = (widgetHeight - totalLegendHeight) / 2;
      if (legendY < 5) legendY = 5; // Asegurar que no se salga por arriba

      for (var i = 0; i < dataToDraw.length; i++) {
        final item = dataToDraw[i];
        if (item.totalSpent <= 0) continue;
        final pct = (item.totalSpent / total) * 100;

        final colorPaint = Paint()..color = colors[i % colors.length];
        canvas.drawCircle(Offset(legendStartX, legendY), 6, colorPaint);

        final textStyle = TextStyle(
            color: textColor, fontSize: 13, fontWeight: FontWeight.w500);
        final pctStyle = TextStyle(
            color: subTextColor, fontSize: 12, fontWeight: FontWeight.normal);

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

        textPainter.layout(minWidth: 0, maxWidth: legendTextMaxWidth);
        textPainter.paint(canvas,
            Offset(legendStartX + 15, legendY - textPainter.height / 2));

        legendY += 25.0;

        if (legendY + 20 > widgetHeight) {
          developer.log(
              '⚠️ [ChartCreator] Leyenda cortada por falta de espacio.',
              name: _logName);
          break;
        }
      }

      final picture = recorder.endRecording();
      final image =
          await picture.toImage(widgetWidth.toInt(), widgetHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e, stackTrace) {
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

    // ── 1. DEUDAS ─────────────────────────────────────────────────────────────
    // Sin cambios respecto al código original.
    try {
      final debtRepo = DebtRepository.instance;
      final debts = await debtRepo.getActiveDebts();
      for (var debt in debts) {
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
      developer.log(
          '✅ [WidgetService] ${upcomingPayments.length} deudas añadidas.',
          name: _logName);
    } catch (e) {
      developer.log('⚠️ [WidgetService] Error al cargar deudas: $e',
          name: _logName);
    }

    // ── 2. TRANSACCIONES RECURRENTES ──────────────────────────────────────────
    // Sin cambios respecto al código original.
    try {
      final recurringRepo = RecurringRepository.instance;
      final recurringTxs = await recurringRepo.getAll();
      final countBefore = upcomingPayments.length;
      for (var tx in recurringTxs) {
        if (tx.nextDueDate.isAfter(DateTime.now())) {
          upcomingPayments.add(UpcomingPayment(
            id: 'rec_${tx.id}',
            concept: tx.description,
            amount: tx.amount,
            nextDueDate: tx.nextDueDate,
            type: UpcomingPaymentType.recurring,
          ));
        }
      }
      developer.log(
          '✅ [WidgetService] ${upcomingPayments.length - countBefore} recurrentes añadidas.',
          name: _logName);
    } catch (e) {
      developer.log('⚠️ [WidgetService] Error al cargar recurrentes: $e',
          name: _logName);
    }

    // ── 3. PRUEBAS GRATUITAS ──────────────────────────────────────────────────
    // Fuente: tabla `free_trials` en Supabase.
    // Criterios de inclusión:
    //   · is_cancelled = false  (el usuario no la canceló manualmente)
    //   · end_date > ahora      (aún no venció — la vencida ya cobró o se perdió)
    //
    // Importante: si future_price = 0, igual la incluimos porque el usuario
    // necesita saber que su prueba vence aunque el precio sea desconocido.
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final now = DateTime.now();
        final trialRows = await supabase
            .from('free_trials')
            .select()
            .eq('user_id', userId)
            .eq('is_cancelled', false)
            .gt('end_date', now.toIso8601String())
            .order('end_date');

        final countBefore = upcomingPayments.length;
        for (final row in trialRows) {
          final endDate = DateTime.parse(row['end_date'] as String);
          final price = (row['future_price'] as num?)?.toDouble() ?? 0.0;
          final name = (row['service_name'] as String?)?.trim();
          if (name == null || name.isEmpty) continue;
          final id = row['id'] as String;

          upcomingPayments.add(UpcomingPayment(
            id: 'trial_$id',
            concept: name,
            amount: price,
            nextDueDate: endDate,
            type: UpcomingPaymentType.freeTrial,
            // El widget Kotlin muestra `subtype` en tv_payment_category.
            // Así el usuario ve "Prueba gratuita" en vez de "freeTrial".
            subtype: 'Prueba gratuita',
          ));
        }
        developer.log(
            '✅ [WidgetService] ${upcomingPayments.length - countBefore} pruebas gratuitas añadidas.',
            name: _logName);
      }
    } catch (e) {
      // Error no fatal — el widget sigue funcionando con deudas y recurrentes.
      developer.log('⚠️ [WidgetService] Error al cargar pruebas gratuitas: $e',
          name: _logName);
    }

    // ── 4. CUOTAS DE TARJETA DE CRÉDITO ──────────────────────────────────────
    // Fuente: tabla `transactions` con is_installment = true.
    //
    // Criterios de inclusión:
    //   · is_installment = true
    //   · installments_current <= installments_total  (cuotas pendientes)
    //
    // Fecha estimada de próximo pago:
    //   La tabla no tiene payment_due_date — usamos la fecha de la transacción
    //   como base y calculamos el siguiente vencimiento mensual:
    //   nextPayment = transaction_date + (installments_current) meses.
    //   Esto asume ciclos mensuales, que es lo habitual en Colombia.
    //
    // Si la fecha estimada ya pasó (cuota teóricamente cobrada), la omitimos.
    //
    // Monto por cuota:
    //   installmentAmount = |amount| / installments_total
    //
    // Ejemplo: compra de $1.200.000 en 12 cuotas, cuota actual = 3
    //   → nextPayment = transactionDate + 3 meses
    //   → monto = $100.000
    //   → concept = "Cuota 3 de 12 · descripción"
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final now = DateTime.now();
        final installmentRows = await supabase
            .from('transactions')
            .select()
            .eq('user_id', userId)
            .eq('is_installment', true)
            .order('transaction_date', ascending: false);

        final countBefore = upcomingPayments.length;
        for (final row in installmentRows) {
          final total = row['installments_total'] as int?;
          final current = row['installments_current'] as int?;

          // Validar que la cuota aún esté activa
          if (total == null || current == null) continue;
          if (current > total) continue; // Todas las cuotas ya están pagadas

          final rawAmount = (row['amount'] as num).toDouble().abs();
          final installmentAmount = rawAmount / total;
          final txDate = DateTime.parse(row['transaction_date'] as String);
          final description =
              (row['description'] as String?)?.trim() ?? 'Cuota pendiente';
          final txId = row['id'] as int;

          // Calcular la fecha del próximo pago (mismo día del mes, un mes adelante
          // por cada cuota completada).
          // current = 1 → primera cuota → un mes después de la compra
          // current = 3 → tercera cuota → tres meses después de la compra
          final nextPaymentDate = DateTime(
            txDate.year,
            txDate.month + current, // current meses después de la compra
            txDate.day,
          );

          // Si la fecha calculada ya pasó, esta cuota ya debió haberse cobrado.
          // La omitimos para no mostrar datos obsoletos.
          if (nextPaymentDate.isBefore(now)) continue;

          upcomingPayments.add(UpcomingPayment(
            id: 'installment_$txId',
            // concept incluye la descripción de la compra para contexto
            concept: description,
            amount: installmentAmount,
            nextDueDate: nextPaymentDate,
            type: UpcomingPaymentType.creditCard,
            // subtype visible en el widget como "categoría"
            subtype: 'Cuota $current de $total',
          ));
        }
        developer.log(
            '✅ [WidgetService] ${upcomingPayments.length - countBefore} cuotas de tarjeta añadidas.',
            name: _logName);
      }
    } catch (e) {
      developer.log('⚠️ [WidgetService] Error al cargar cuotas: $e',
          name: _logName);
    }

    // ── Ordenar por fecha más próxima ─────────────────────────────────────────
    upcomingPayments.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    developer.log(
        '✅ [WidgetService] Total: ${upcomingPayments.length} pagos próximos '
        '(deudas + recurrentes + pruebas gratuitas + cuotas).',
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
        await HomeWidget.saveWidgetData<String>(
            'next_payment_data', jsonString);
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
        name:
            'NextPaymentWidgetProvider', // Debe coincidir con el nombre de la clase en Kotlin
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

