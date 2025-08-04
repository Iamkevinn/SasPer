// lib/screens/analysis_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Repositorios y Modelos
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/insight_model.dart'; 

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
  Future<({AnalysisData charts, List<Insight> insights})> _fetchAllScreenData() async {
    final results = await Future.wait([
      _repository.fetchAllAnalysisData(),
      // Descomenta esta línea cuando implementes el método en el repositorio.
      // _repository.getInsights(),
      _repository.getInsights(),// Placeholder mientras no existe el método real.
    ]);
    
    return (charts: results[0] as AnalysisData, insights: results[1] as List<Insight>);
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmer();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }
            if (!snapshot.hasData) {
              return _buildEmptyState(onRefresh: _handleRefresh);
            }

            final data = snapshot.data!;
            final chartData = data.charts;
            final insights = data.insights;

            final bool hasAnyData = insights.isNotEmpty || chartData.hasData;

            if (!hasAnyData) {
              return _buildEmptyState(onRefresh: _handleRefresh);
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text('Análisis', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  centerTitle: false,
                  elevation: 0,
                  pinned: true, // El título se queda fijo al hacer scroll.
                  floating: true, // El appbar reaparece al hacer scroll hacia arriba.
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(240),
                ),
                
                // --- SECCIÓN DE INSIGHTS ---
                // Solo se muestra si la lista de insights no está vacía.
                if (insights.isNotEmpty) ...[
                  _buildSectionHeader("Tus Descubrimientos"),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList.separated(
                      itemCount: insights.length,
                      itemBuilder: (context, index) => InsightCard(insight: insights[index]),
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                      itemBuilder: (context, index) => _buildChartWidget(chartData, index),
                      separatorBuilder: (context, index) => const SizedBox(height: 32),
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
      if (data.heatmapData.isNotEmpty) HeatmapSection(data: data.heatmapData, startDate: DateTime.now().subtract(const Duration(days: 119)), endDate: DateTime.now()),
      if (data.cashflowBarData.isNotEmpty) MonthlyCashflowChart(data: data.cashflowBarData),
      if (data.netWorthLineData.isNotEmpty) NetWorthTrendChart(data: data.netWorthLineData),
      if (data.incomeExpenseBarData.isNotEmpty) IncomeExpenseBarChart(data: data.incomeExpenseBarData),
      if (data.categoryComparisonData.isNotEmpty) CategoryComparisonChart(data: data.categoryComparisonData),
      if (data.expensePieData.isNotEmpty) ExpensePieChart(data: data.expensePieData),
      if (data.incomePieData.isNotEmpty) IncomePieChart(data: data.incomePieData),
    ];
    return widgets[index];
  }

  Widget _buildErrorState(Object? error) {
    return Center(child: EmptyStateCard(title: 'Ocurrió un Error', message: 'No se pudieron cargar los datos.\nError: $error', icon: Iconsax.warning_2));
  }

  Widget _buildEmptyState({required Future<void> Function() onRefresh}) {
    // Envolvemos el estado vacío en un RefreshIndicator para que el usuario pueda reintentar.
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack( // Stack permite que el ListView exista para habilitar el pull-to-refresh
        children: [
          ListView(),
          const Center(child: EmptyStateCard(title: 'Sin Datos Suficientes', message: 'Aún no hay transacciones para generar un análisis.', icon: Iconsax.chart_21)),
        ],
      ),
    );
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
                Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                const SizedBox(height: 12),
                Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
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
                Container(height: 250, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
                const SizedBox(height: 32),
                Container(height: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Extensión para simplificar la comprobación de si hay datos de gráficos para mostrar.
extension on AnalysisData {
  bool get hasData =>
      expensePieData.isNotEmpty ||
      cashflowBarData.isNotEmpty ||
      netWorthLineData.isNotEmpty ||
      categoryComparisonData.isNotEmpty ||
      incomePieData.isNotEmpty ||
      incomeExpenseBarData.isNotEmpty ||
      heatmapData.isNotEmpty;
}