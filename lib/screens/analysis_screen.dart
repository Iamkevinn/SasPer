// lib/screens/analysis_screen.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/widgets/analysis_charts/average_analysis_section.dart';
import 'package:sasper/widgets/analysis_charts/mood_by_day_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Repositorios y Modelos
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/insight_model.dart';

// --- NUEVAS IMPORTACIONES ---
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
// NOVEDAD: Importa el nuevo widget de análisis que acabamos de crear.
import 'package:sasper/widgets/analysis_charts/mood_spending_analysis_card.dart';

// Widgets de la Pantalla
import 'package:sasper/widgets/analysis_charts/heatmap_section.dart';
import 'package:sasper/widgets/analysis_charts/monthly_cashflow_chart.dart';
import 'package:sasper/widgets/analysis_charts/net_worth_trend_chart.dart';
import 'package:sasper/widgets/analysis_charts/income_expense_bar_chart.dart';
import 'package:sasper/widgets/analysis_charts/category_comparison_chart.dart';
import 'package:sasper/widgets/analysis_charts/expense_pie_chart.dart';
import 'package:sasper/widgets/analysis_charts/income_pie_chart.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/analysis/insight_card.dart';

// Placeholder para el modelo de Insight. Reemplázalo cuando lo crees.

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => AnalysisScreenState();
}

class AnalysisScreenState extends State<AnalysisScreen> {
  final AnalysisRepository _repository = AnalysisRepository.instance;

  // Usamos un "Record" para manejar ambos futuros en un solo estado.
  late Future<({AnalysisData charts, List<Insight> insights})> _analysisFuture;

  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _fetchAllScreenData();
    _setupRealtimeSubscription();
  }

  /// Carga en paralelo los datos de los gráficos y los insights para una carga más rápida.
  /// Carga en paralelo los datos de los gráficos y los insights de forma resiliente.
  Future<({AnalysisData charts, List<Insight> insights})>
      _fetchAllScreenData() async {
    // Usamos Future.wait con manejo de errores individual, similar a como lo
    // hace tu AnalysisRepository. Esto asegura que si una parte falla, la otra no.
    final results = await Future.wait([
      _repository.fetchAllAnalysisData().catchError((e) {
        // Si falla la carga de gráficos, logueamos el error y devolvemos datos vacíos.
        developer.log('Fallo al cargar datos de gráficos',
            name: 'AnalysisScreen', error: e);
        return AnalysisData.empty();
      }),
      _repository.getInsights().catchError((e) {
        // Si falla la carga de insights, logueamos y devolvemos una lista vacía.
        developer.log('Fallo al cargar insights',
            name: 'AnalysisScreen', error: e);
        return <Insight>[];
      }),
    ]);

    return (
      charts: results[0] as AnalysisData,
      insights: results[1] as List<Insight>
    );
  }

  /// Configura la escucha de cambios en tiempo real en la base de datos.
  void _setupRealtimeSubscription() {
    final client = Supabase.instance.client;
    _realtimeChannel = client
        .channel('public:analysis_screen_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (_) => _triggerRefreshWithDebounce(),
        )
        // Descomenta cuando crees la tabla 'insights'.
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'insights',
          callback: (_) => _triggerRefreshWithDebounce(),
        )
        .subscribe();
  }

  /// Agrupa múltiples llamadas de refresco en una sola para evitar sobrecargar la red.
  void _triggerRefreshWithDebounce() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _handleRefresh();
    });
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _debounce?.cancel();
    super.dispose();
  }

  /// Vuelve a cargar todos los datos de la pantalla.
  Future<void> _handleRefresh() async {
    if (mounted) {
      setState(() {
        _analysisFuture = _fetchAllScreenData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos un CustomScrollView para combinar diferentes tipos de listas (Slivers),
      // lo que nos da un control superior sobre el scroll y las cabeceras.
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FutureBuilder<({AnalysisData charts, List<Insight> insights})>(
          future: _analysisFuture,
          builder: (context, snapshot) {
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            // Usamos Skeletonizer para el estado de carga
            if (isLoading) {
              return _buildShimmer();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }
            if (!snapshot.hasData) {
              return _buildLottieEmptyState(onRefresh: _handleRefresh);
            }

            final data = snapshot.data!;
            final chartData = data.charts;
            final insights = data.insights;

            final bool hasAnyData = insights.isNotEmpty || chartData.hasData;

            if (!hasAnyData) {
              return _buildLottieEmptyState(onRefresh: _handleRefresh);
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text('Análisis',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  centerTitle: false,
                  elevation: 0,
                  pinned: true, // El título se queda fijo al hacer scroll.
                  floating:
                      true, // El appbar reaparece al hacer scroll hacia arriba.
                  backgroundColor:
                      Theme.of(context).scaffoldBackgroundColor.withAlpha(240),
                ),

                // --- SECCIÓN DE INSIGHTS ---
                // Solo se muestra si la lista de insights no está vacía.
                if (insights.isNotEmpty) ...[
                  _buildSectionHeader("Tus Descubrimientos"),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList.separated(
                      itemCount: insights.length,
                      itemBuilder: (context, index) =>
                          InsightCard(insight: insights[index])
                              .animate()
                              .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                              .slideY(begin: 0.2, curve: Curves.easeOutCubic),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                    ),
                  ),
                ],

                // --- SECCIÓN DE GRÁFICOS ---
                // Solo se muestra si hay datos para al menos un gráfico.
                if (chartData.hasData) ...[
                  _buildSectionHeader("Explora tus Datos"),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
                    sliver: SliverList.separated(
                      itemCount: _getChartCount(chartData),
                      itemBuilder: (context, index) =>
                          _buildChartWidget(chartData, index)
                              .animate()
                              .fadeIn(duration: 600.ms, delay: (200 * index).ms)
                              .moveY(begin: 30, curve: Curves.easeOutCubic),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 32),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES PARA MANTENER EL `build` LIMPIO Y LEGIBLE ---

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Text(
          title,
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  int _getChartCount(AnalysisData data) {
    int count = 0;
    if (data.monthlyAverage.monthCount > 0 && data.categoryAverages.isNotEmpty) count++;
    if (data.moodAnalysisData.isNotEmpty) count++;
    if (data.moodByDayData.isNotEmpty) count++;
    if (data.heatmapData.isNotEmpty) count++;
    if (data.cashflowBarData.isNotEmpty) count++;
    if (data.netWorthLineData.isNotEmpty) count++;
    if (data.incomeExpenseBarData.isNotEmpty) count++;
    if (data.categoryComparisonData.isNotEmpty) count++;
    if (data.expensePieData.isNotEmpty) count++;
    if (data.incomePieData.isNotEmpty) count++;
    return count;
  }

  Widget _buildChartWidget(AnalysisData data, int index) {
    final widgets = [
      if (data.monthlyAverage.monthCount > 0 && data.categoryAverages.isNotEmpty)
        AverageAnalysisSection(
          monthlyData: data.monthlyAverage,
          categoryData: data.categoryAverages,
        ),
      // NOVEDAD: Añadimos nuestro nuevo widget a la lista, preferiblemente al principio.
      if (data.moodAnalysisData.isNotEmpty)
        MoodSpendingAnalysisCard(analysisData: data.moodAnalysisData),
      if (data.moodByDayData.isNotEmpty)
        MoodByDayChart(analysisData: data.moodByDayData),
      if (data.heatmapData.isNotEmpty)
        HeatmapSection(
            data: data.heatmapData,
            startDate: DateTime.now().subtract(const Duration(days: 119)),
            endDate: DateTime.now()),
      if (data.cashflowBarData.isNotEmpty)
        MonthlyCashflowChart(data: data.cashflowBarData),
      if (data.netWorthLineData.isNotEmpty)
        NetWorthTrendChart(data: data.netWorthLineData),
      if (data.incomeExpenseBarData.isNotEmpty)
        IncomeExpenseBarChart(data: data.incomeExpenseBarData),
      if (data.categoryComparisonData.isNotEmpty)
        CategoryComparisonChart(data: data.categoryComparisonData),
      if (data.expensePieData.isNotEmpty)
        ExpensePieChart(data: data.expensePieData),
      if (data.incomePieData.isNotEmpty)
        IncomePieChart(data: data.incomePieData),
    ];
    // Devuelve un contenedor vacío temporalmente para que no haya errores
    if (widgets.isEmpty) {
      return const SizedBox(
          height: 1, child: Text("Gráfico desactivado temporalmente"));
    }
    return widgets[index];
  }

  Widget _buildErrorState(Object? error) {
    // NOVEDAD: Logueamos el error para verlo completo en la consola.
    developer.log(
      'Error capturado por FutureBuilder en AnalysisScreen',
      name: 'AnalysisScreen',
      error: error,
      // Si tienes el stackTrace del snapshot, añádelo también:
      // stackTrace: snapshot.stackTrace,
    );

    return Center(
        child: EmptyStateCard(
            title: 'Ocurrió un Error',
            // NOVEDAD: Mostramos el error real en la UI.
            message:
                'No se pudieron cargar los datos de análisis.\n\nError: $error',
            icon: Iconsax.warning_2));
  }

  Widget _buildShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Shimmer para la cabecera de Insights
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Container(width: 250, height: 28.0, color: Colors.white),
          ),
          // Shimmer para 2 tarjetas de Insight
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Container(
                    height: 80,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16))),
                const SizedBox(height: 12),
                Container(
                    height: 80,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16))),
              ],
            ),
          ),
          // Shimmer para la cabecera de Gráficos
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Container(width: 220, height: 28.0, color: Colors.white),
          ),
          // Shimmer para 3 bloques de Gráficos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Container(
                    height: 250,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20))),
                const SizedBox(height: 32),
                Container(
                    height: 300,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET DE ESTADO VACÍO CON LOTTIE ---
  Widget _buildLottieEmptyState({required Future<void> Function() onRefresh}) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          ListView(), // Para habilitar pull-to-refresh
          Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/animations/analysis_animation.json',
                      width: 250,
                      height: 250,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin Datos Suficientes',
                      style: GoogleFonts.poppins(
                          fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registra algunas transacciones para empezar a ver tus análisis inteligentes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

/// Extensión para simplificar la comprobación de si hay datos de gráficos para mostrar.
extension on AnalysisData {
  bool get hasData =>
      // NOVEDAD: Añadimos el nuevo análisis a la comprobación general.
      moodByDayData.isNotEmpty ||
      moodAnalysisData.isNotEmpty ||
      expensePieData.isNotEmpty ||
      cashflowBarData.isNotEmpty ||
      netWorthLineData.isNotEmpty ||
      categoryComparisonData.isNotEmpty ||
      incomePieData.isNotEmpty ||
      incomeExpenseBarData.isNotEmpty ||
      heatmapData.isNotEmpty;
}
