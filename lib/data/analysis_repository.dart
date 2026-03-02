// lib/data/analysis_repository.dart

import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:sasper/models/insight_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/mood_analysis_model.dart';
import 'package:sasper/models/mood_by_day_analysis_model.dart';

class AnalysisRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // Constructor privado para forzar el uso del Singleton `instance`.
  AnalysisRepository._internal();
  static final AnalysisRepository instance = AnalysisRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  /// Se ejecuta automáticamente la primera vez que se accede al cliente de Supabase.
  void _ensureInitialized() {
    // Esta lógica solo se ejecuta una vez en todo el ciclo de vida de la app.
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      developer.log('✅ AnalysisRepository inicializado PEREZOSAMENTE.',
          name: 'AnalysisRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  /// Activa la inicialización perezosa cuando es necesario.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception(
          "¡ERROR FATAL! Supabase no está disponible para AnalysisRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient client) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  // <-- NUEVO MÉTODO -->
  /// Obtiene el ingreso mensual promedio del usuario.
  /// Se apoya en una función RPC de Supabase para eficiencia.
  Future<double> getAverageMonthlyIncome() async {
    developer.log("💰 [Repo] Obteniendo ingreso mensual promedio...",
        name: 'AnalysisRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Usuario no autenticado");

      // Debes crear una función RPC en Supabase llamada 'get_average_monthly_income'
      // que devuelva un solo valor, ej: SELECT avg(total) FROM (SELECT sum(amount) as total FROM transactions WHERE type = 'income' AND user_id = user_id_param GROUP BY strftime('%Y-%m', date))
      final result = await client.rpc('get_average_monthly_income',
          params: {'user_id_param': userId});

      // El resultado de una RPC simple puede ser un número directamente
      if (result is num) {
        developer.log('✅ [Repo] Ingreso promedio recibido: ${result.toDouble()}',
            name: 'AnalysisRepository');
        return result.toDouble();
      }
      return 0.0;
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error en getAverageMonthlyIncome: $e',
          name: 'AnalysisRepository', stackTrace: stackTrace);
      return 0.0; // Devolver 0 en caso de error para no romper la UI.
    }
  }
  
  /// Obtiene los datos para el widget de "Salud Financiera".
  Future<FinancialHealthInsight> getFinancialHealthInsightForWidget() async {
    developer.log("🩺 [Repo] Obteniendo datos para widget con RPC...",
        name: 'AnalysisRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Usuario no autenticado");

      // Volvemos a la llamada RPC, que es mucho más eficiente.
      final result = await client.rpc('get_financial_health_metrics',
          params: {'user_id_param': userId});

      // El resultado de un RPC que devuelve una tabla con una fila es una Lista que contiene un Mapa.
      final data = (result as List).first as Map<String, dynamic>;

      developer.log('📊 [Repo] Datos recibidos de RPC: $data',
          name: 'AnalysisRepository');

      return FinancialHealthInsight(
        spendingPace: (data['w_spending_pace'] as num? ?? 0).toDouble(),
        savingsRate: (data['w_savings_rate'] as num? ?? 0).toDouble(),
        topCategoryName: data['w_top_category'] as String? ?? 'N/A',
        topCategoryAmount: (data['w_top_amount'] as num? ?? 0).toDouble(),
      );
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error en getFinancialHealthInsightForWidget: $e',
          name: 'AnalysisRepository', stackTrace: stackTrace);
      return const FinancialHealthInsight(
          spendingPace: 0,
          savingsRate: 0,
          topCategoryName: 'Error',
          topCategoryAmount: 0);
    }
  }

  /// Obtiene los datos para el widget de "Comparativa Mensual".
  Future<MonthlyComparison> getMonthlySpendingComparisonForWidget() async {
    developer.log(
        "📊 [Repo] Obteniendo datos para widget de Comparativa Mensual...",
        name: 'AnalysisRepository');
    try {
      // De igual forma, necesitarás una RPC llamada 'get_monthly_spending_comparison'.
      final result = await client.rpc('get_monthly_spending_comparison');
      final data = result as Map<String, dynamic>;

      return MonthlyComparison(
        currentMonthSpending:
            (data['current_month_spending'] as num? ?? 0).toDouble(),
        previousMonthSpending:
            (data['previous_month_spending'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      developer.log('🔥 Error en getMonthlyComparisonForWidget: $e',
          name: 'AnalysisRepository');
      return const MonthlyComparison(
          currentMonthSpending: 0, previousMonthSpending: 0);
    }
  }

  /// Obtiene la lista de insights no leídos para el usuario actual.
  Future<List<Insight>> getInsights() async {
    developer.log('🧠 [Repo] Obteniendo insights inteligentes...',
        name: 'AnalysisRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return []; // No hay usuario, no hay insights.

      final response = await client
          .from('insights')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false) // Opcional: solo traer los no leídos
          .order('created_at', ascending: false)
          .limit(5); // Traer solo los 5 más recientes para no saturar la UI

      return (response as List).map((data) => Insight.fromMap(data)).toList();
    } catch (e) {
      developer.log('🔥 Error obteniendo insights: $e',
          name: 'AnalysisRepository');
      return []; // Devolver lista vacía en caso de error.
    }
  }

  Future<void> markInsightAsRead(String insightId) async {
  try {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Ejecutamos la actualización asegurando que pertenezca al usuario
    final response = await client
        .from('insights')
        .update({'is_read': true})
        .eq('id', insightId)
        .eq('user_id', userId)
        .select(); // El select ayuda a confirmar que se hizo algo

    if (response.isEmpty) {
      developer.log('⚠️ No se encontró el insight o no tienes permiso: $insightId');
    } else {
      developer.log('✅ Insight $insightId marcado como leído');
    }
  } catch (e) {
    developer.log('🔥 Error al marcar insight como leído: $e');
    rethrow; // Importante para que la UI sepa que falló
  }
}
  /// Obtiene solo el resumen de gastos, ideal para widgets o cargas rápidas.
  Future<List<ExpenseByCategory>> getExpenseSummaryForWidget() async {
    developer.log("📈 [Repo] Obteniendo resumen de gastos para widget...",
        name: 'AnalysisRepository');
    try {
      // Todos los métodos ahora usan el getter `client` que asegura la inicialización.
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final clientDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final result = await client.rpc('get_expense_summary_by_category',
          params: {'p_user_id': userId, 'client_date': clientDate});

      // Aseguramos que el resultado sea una lista antes de mapear.
      if (result is List) {
        return result.map((e) => ExpenseByCategory.fromMap(e)).toList();
      }
      return [];
    } catch (e) {
      developer.log('🔥 Error en getExpenseSummaryForWidget: $e',
          name: 'AnalysisRepository');
      return [];
    }
  }

  // NOVEDAD: Añadimos el nuevo método para obtener el análisis por estado de ánimo.
  /// Obtiene un análisis de los gastos agrupados por categoría y estado de ánimo.
  Future<List<MoodAnalysis>> getMoodSpendingAnalysis() async {
    developer.log("😊 [Repo] Obteniendo análisis de gastos por mood...",
        name: 'AnalysisRepository');
    try {
      // Llamamos a la nueva función RPC que creamos en Supabase.
      final result = await client.rpc('get_mood_spending_analysis');

      if (result is List) {
        final analysis = result.map((e) => MoodAnalysis.fromMap(e)).toList();
        developer.log(
            '✅ [Repo] Encontrados ${analysis.length} registros de análisis por mood.',
            name: 'AnalysisRepository');
        return analysis;
      }
      return [];
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error en getMoodSpendingAnalysis: $e',
          name: 'AnalysisRepository', stackTrace: stackTrace);
      // Devolvemos una lista vacía en caso de error para no romper la UI.
      return [];
    }
  }

  // NOVEDAD: Añadimos el nuevo método para el análisis temporal.
  Future<List<MoodByDayAnalysis>> getMoodSpendingByDayOfWeek() async {
    developer.log("📅 [Repo] Obteniendo análisis de mood por día...",
        name: 'AnalysisRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await client.rpc(
        'get_mood_spending_by_day_of_week',
        params: {'p_user_id': userId},
      );

      if (result is List) {
        return result.map((e) => MoodByDayAnalysis.fromMap(e)).toList();
      }
      return [];
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error en getMoodSpendingByDayOfWeek: $e',
          name: 'AnalysisRepository', stackTrace: stackTrace);
      return [];
    }
  }

  /// Obtiene el conjunto completo de datos para la pantalla de análisis.
  Future<AnalysisData> fetchAllAnalysisData() async {
    developer.log("📈 [Repo] Obteniendo todos los datos de análisis...",
        name: 'AnalysisRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return AnalysisData.empty();
      }

      final today = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd')
          .format(today.subtract(const Duration(days: 120)));
      final endDate = DateFormat('yyyy-MM-dd').format(today);
      final clientDate = DateFormat('yyyy-MM-dd').format(today);

      // Usamos Future.wait para eficiencia.
      // El .catchError en cada futuro previene que un solo error detenga todas las demás peticiones.
      final results = await Future.wait([
        client.rpc('get_expense_summary_by_category', params: {
          'p_user_id': userId,
          'client_date': clientDate
        }).catchError((_) => []),
        client.rpc('get_net_worth_trend', params: {
          'p_user_id': userId,
          'client_date': clientDate
        }).catchError((_) => []),
        client.rpc('get_monthly_cash_flow',
            params: {'p_user_id': userId}).catchError((_) => []),
        client.rpc('get_category_spending_comparison',
            params: {'p_user_id': userId}).catchError((_) => []),
        client.rpc('get_income_summary_by_category', params: {
          'p_user_id': userId,
          'client_date': clientDate
        }).catchError((_) => []),
        client.rpc('get_monthly_income_expense_summary', params: {
          'p_user_id': userId,
          'client_date': clientDate
        }).catchError((_) => []),
        client.rpc('get_daily_net_flow', params: {
          'p_user_id': userId,
          'start_date': startDate,
          'end_date': endDate
        }).catchError((_) => []),
        // NOVEDAD: Añadimos nuestra nueva función a la lista de llamadas en paralelo.
        getMoodSpendingAnalysis().catchError((_) => const <MoodAnalysis>[]),
        // Ahora la lista tiene 9 elementos, con índices del 0 al 8.
        getMoodSpendingByDayOfWeek().catchError((_) => const <MoodByDayAnalysis>[]), // Índice 8
        client
            .rpc('get_average_monthly_spending')
            .catchError((_) => []), // Índice 9
        client
            .rpc('get_average_spending_per_category')
            .catchError((_) => []), // Índice 10
      ]);

      // Función auxiliar robusta para parsear los resultados de Future.wait.
      List<T> parseResult<T>(
          dynamic result, T Function(Map<String, dynamic>) fromJson) {
        if (result is List) {
          return result
              .map((e) => fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      }

      // --- PARSEAMOS LOS NUEVOS DATOS ---

      // Promedio Mensual Total (Índice 9)
      MonthlyAverageResult monthlyAverage;
      if (results[9] is List && (results[9] as List).isNotEmpty) {
        final data = (results[9] as List).first;
        monthlyAverage = MonthlyAverageResult(
          averageSpending: (data['average_spending'] as num? ?? 0).toDouble(),
          monthCount: data['month_count'] as int? ?? 0,
        );
      } else {
        monthlyAverage =
            const MonthlyAverageResult(averageSpending: 0, monthCount: 0);
      }

      // Promedio por Categoría (Índice 10)
      final List<CategoryAverageResult> categoryAverages = parseResult(
        results[10],
        (item) => CategoryAverageResult(
          categoryName: item['category_name'] as String,
          averageAmount: (item['average_amount'] as num? ?? 0).toDouble(),
          color: item['color'] as String?,
        ),
      );

      // --- CORRECCIÓN Y DEPURACIÓN ---
      final heatmapRawData = {
        if (results[6] is List)
          for (var item in (results[6] as List))
            if (DateTime.tryParse(item['day']) != null)
              DateTime.parse(item['day']):
                  (item['net_amount'] as num? ?? 0).toInt()
      };

      // MODIFICA ESTA LÍNEA para que sea más fácil de encontrar
      developer.log(
          'PASO 1 (REPOSITORIO) -> Datos enviados al widget: $heatmapRawData',
          name: 'HEATMAP_DEBUG');

      developer.log('📊 [Repo] Heatmap Data being sent: $heatmapRawData',
          name: 'AnalysisRepository');

      return AnalysisData(
        expensePieData: parseResult(results[0], ExpenseByCategory.fromMap),
        netWorthLineData: parseResult(results[1], NetWorthDataPoint.fromJson),
        cashflowBarData: parseResult(results[2], MonthlyCashflowData.fromJson),
        categoryComparisonData:
            parseResult(results[3], CategorySpendingComparisonData.fromJson),
        incomePieData: parseResult(results[4], IncomeByCategory.fromJson),
        incomeExpenseBarData:
            parseResult(results[5], MonthlyIncomeExpenseSummaryData.fromJson),
        heatmapData: {
          if (results[6] is List)
            for (var item in (results[6] as List))
              if (DateTime.tryParse(item['day']) != null)
                // --- ¡CORRECCIÓN DEFINITIVA! Eliminamos la inversión de signo. ---
                // El valor 'net_amount' de la RPC ya es correcto.
                DateTime.parse(item['day']):
                    (item['net_amount'] as num? ?? 0).toInt()
        },
        // NOVEDAD: Asignamos el resultado del análisis de mood.
        // `results[7]` corresponde a la nueva llamada que añadimos. El tipo ya es `List<MoodAnalysis>`.
        moodAnalysisData: results[7] as List<MoodAnalysis>,
        moodByDayData: results[8] as List<MoodByDayAnalysis>,
        monthlyAverage: monthlyAverage,
        categoryAverages: categoryAverages,
      );
    } catch (e, stackTrace) {
      developer.log("🔥 [Repo] ERROR CRÍTICO obteniendo datos de análisis: $e",
          name: 'AnalysisRepository', error: e, stackTrace: stackTrace);
      return AnalysisData.empty();
    }
  }
}
