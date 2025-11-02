// lib/screens/analysis_screen.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
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

import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
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

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => AnalysisScreenState();
}

class AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  final AnalysisRepository _repository = AnalysisRepository.instance;

  late Future<({AnalysisData charts, List<Insight> insights})> _analysisFuture;

  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  // Animación para el ícono de IA
  late AnimationController _aiPulseController;
  late Animation<double> _aiPulseAnimation;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _fetchAllScreenData();
    _setupRealtimeSubscription();

    // Inicializar animación del ícono IA
    _aiPulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _aiPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _aiPulseController, curve: Curves.easeInOut),
    );
  }

  Future<({AnalysisData charts, List<Insight> insights})>
      _fetchAllScreenData() async {
    final results = await Future.wait([
      _repository.fetchAllAnalysisData().catchError((e) {
        developer.log('Fallo al cargar datos de gráficos',
            name: 'AnalysisScreen', error: e);
        return AnalysisData.empty();
      }),
      _repository.getInsights().catchError((e) {
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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'insights',
          callback: (_) => _triggerRefreshWithDebounce(),
        )
        .subscribe();
  }

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
    _aiPulseController.dispose();
    super.dispose();
  }

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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: FutureBuilder<({AnalysisData charts, List<Insight> insights})>(
            future: _analysisFuture,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

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

              return _buildAnalysisContent(chartData, insights);
            },
          ),
        ),
      ),
    );
  }

  // ==================== CONTENIDO PRINCIPAL ====================
  Widget _buildAnalysisContent(AnalysisData chartData, List<Insight> insights) {
    developer.log(
      '--- ESTADO DE DATOS PARA GRÁFICOS ---\n'
      'Tendencia Patrimonial: ${chartData.netWorthLineData.length} items\n'
      'Análisis Emocional: ${chartData.moodAnalysisData.length} items\n'
      'Flujo de Efectivo: ${chartData.cashflowBarData.length} items\n'
      'Comparativa Categoría: ${chartData.categoryComparisonData.length} items\n'
      'Análisis de Promedios: ${chartData.monthlyAverage.monthCount} meses\n'
      'Ingresos vs Gastos: ${chartData.incomeExpenseBarData.length} items\n'
      'Gráfico Gastos (Pie): ${chartData.expensePieData.length} items\n'
      'Gráfico Ingresos (Pie): ${chartData.incomePieData.length} items\n'
      'Ánimo por Día: ${chartData.moodByDayData.length} items\n'
      'Mapa de Calor: ${chartData.heatmapData.length} items',
      name: 'AnalysisScreen',
    );
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // HEADER PREMIUM CON IA
        _buildPremiumHeader(colorScheme, isDark, insights),

        // INSIGHT HERO CARD (EL MÁS IMPORTANTE)
        if (insights.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildHeroInsightCard(insights.first, colorScheme, isDark),
            ),
          ),

        // QUICK STATS (3 MÉTRICAS CLAVE)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _buildQuickStats(chartData, colorScheme, isDark),
          ),
        ),

        // SECCIÓN: INSIGHTS SECUNDARIOS
        if (insights.length > 1) ...[
          _buildSectionHeader('Descubrimientos Clave', colorScheme),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: insights.length - 1, // Excluimos el hero
              itemBuilder: (context, index) =>
                  InsightCard(insight: insights[index + 1])
                      .animate()
                      .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                      .slideY(begin: 0.2, curve: Curves.easeOutCubic),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],

        // SECCIÓN: GRÁFICOS PRIORITARIOS
        if (chartData.hasData) ...[
          _buildSectionHeader('Análisis Detallado', colorScheme),

          // GRÁFICO 1: Balance proyectado (NetWorth)
          if (chartData.netWorthLineData.isNotEmpty)
            _buildChartSection(
              title: 'Tendencia Patrimonial',
              subtitle: 'Tu evolución financiera en el tiempo',
              icon: Iconsax.trend_up,
              child: NetWorthTrendChart(data: chartData.netWorthLineData),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 2: Comportamiento emocional (PRIORIDAD ALTA)
          if (chartData.moodAnalysisData.isNotEmpty)
            _buildChartSection(
              title: 'Análisis Emocional de Gastos',
              subtitle: 'Cómo tu estado de ánimo afecta tus finanzas',
              icon: Iconsax.emoji_happy,
              child: MoodSpendingAnalysisCard(
                  analysisData: chartData.moodAnalysisData),
              colorScheme: colorScheme,
              isHighlight: true,
            ),

          // GRÁFICO 3: Flujo de caja
          if (chartData.cashflowBarData.isNotEmpty)
            _buildChartSection(
              title: 'Flujo de Efectivo Mensual',
              subtitle: 'Balance entre ingresos y gastos',
              icon: Iconsax.chart_21,
              child: MonthlyCashflowChart(data: chartData.cashflowBarData),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 4: Comparativa de categorías
          if (chartData.categoryComparisonData.isNotEmpty)
            _buildChartSection(
              title: 'Comparativa por Categoría',
              subtitle: 'Tus patrones de gasto mensuales',
              icon: Iconsax.category,
              child: CategoryComparisonChart(
                  data: chartData.categoryComparisonData),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 5: Promedios y análisis
          if (chartData.monthlyAverage.monthCount > 0 &&
              chartData.categoryAverages.isNotEmpty)
            _buildChartSection(
              title: 'Análisis de Promedios',
              subtitle: 'Tu comportamiento financiero promedio',
              icon: Iconsax.chart_square,
              child: AverageAnalysisSection(
                monthlyData: chartData.monthlyAverage,
                categoryData: chartData.categoryAverages,
              ),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 6: Ingresos vs Gastos
          if (chartData.incomeExpenseBarData.isNotEmpty)
            _buildChartSection(
              title: 'Ingresos vs Gastos',
              subtitle: 'Comparativa mensual detallada',
              icon: Iconsax.money_recive,
              child:
                  IncomeExpenseBarChart(data: chartData.incomeExpenseBarData),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 7: Distribución de gastos (Pie)
          if (chartData.expensePieData.isNotEmpty)
            _buildChartSection(
              title: 'Distribución de Gastos',
              subtitle: 'Dónde se va tu dinero',
              icon: Iconsax.chart_1,
              child: ExpensePieChart(data: chartData.expensePieData),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 8: Distribución de ingresos (Pie)
          if (chartData.incomePieData.isNotEmpty)
            _buildChartSection(
              title: 'Fuentes de Ingreso',
              subtitle: 'De dónde proviene tu dinero',
              icon: Iconsax.wallet_money,
              child: IncomePieChart(data: chartData.incomePieData),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 9: Estado de ánimo por día
          if (chartData.moodByDayData.isNotEmpty)
            _buildChartSection(
              title: 'Ánimo por Día de la Semana',
              subtitle: 'Patrones emocionales semanales',
              icon: Iconsax.calendar,
              child: MoodByDayChart(analysisData: chartData.moodByDayData),
              colorScheme: colorScheme,
            ),

          // GRÁFICO 10: Heatmap de actividad
          if (chartData.heatmapData.isNotEmpty)
            _buildChartSection(
              title: 'Mapa de Calor de Actividad',
              subtitle: 'Tu comportamiento financiero diario',
              icon: Iconsax.grid_1,
              child: HeatmapSection(
                data: chartData.heatmapData,
                startDate: DateTime.now().subtract(const Duration(days: 119)),
                endDate: DateTime.now(),
              ),
              colorScheme: colorScheme,
            ),

          // SPACING PARA NAVIGATION BAR
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ],
    );
  }

  // ==================== HEADER PREMIUM ====================
  Widget _buildPremiumHeader(
      ColorScheme colorScheme, bool isDark, List<Insight> insights) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: colorScheme.surface.withOpacity(0.95),
      toolbarHeight: 100,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Inteligencia Financiera',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _aiPulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _aiPulseAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Iconsax.magic_star,
                        size: 16,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _getFinancialStatusMessage(insights),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _getFinancialStatusMessage(List<Insight> insights) {
    if (insights.isEmpty) return 'Analizando tu situación financiera...';

    // Filtra por la SEVERIDAD del insight, no por su tipo.
    final positiveInsights =
        insights.where((i) => i.severity == InsightSeverity.success);

    if (positiveInsights.isNotEmpty) {
      // Puedes personalizar el mensaje si quieres.
      return '${positiveInsights.length} buenas noticias detectadas';
    }

    return '${insights.length} insights disponibles';
  }

  // ==================== HERO INSIGHT CARD ====================
  Widget _buildHeroInsightCard(
      Insight insight, ColorScheme colorScheme, bool isDark) {
    // 1. Obtiene el color principal y el icono directamente desde la extensión.
    final Color iconColor = insight.severity.getColor(context);
    final IconData icon = insight.severity.icon;

    // 2. El color de fondo del card puede ser el mismo color con baja opacidad.
    final Color cardColor = iconColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardColor.withOpacity(0.15),
            cardColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cardColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insight Principal',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      insight.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.description,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: cardColor.withOpacity(0.2),
              foregroundColor: iconColor,
            ),
            child: const Text('Ver detalles'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3);
  }

  // ==================== QUICK STATS ====================
  Widget _buildQuickStats(
      AnalysisData data, ColorScheme colorScheme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Balance',
            data.netWorthLineData.isNotEmpty
                ? '\$${data.netWorthLineData.last.totalBalance.toStringAsFixed(0)}'
                : '\$0',
            Iconsax.wallet_3,
            colorScheme.primary,
            colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Este Mes',
            data.cashflowBarData.isNotEmpty
                ? '\$${data.cashflowBarData.last.cashFlow.toStringAsFixed(0)}'
                : '\$0',
            Iconsax.trend_up,
            Colors.green,
            colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Gastos',
            data.expensePieData.isNotEmpty
                ? '\$${data.expensePieData.fold<double>(0, (sum, item) => sum + item.totalSpent).toStringAsFixed(0)}'
                : '\$0',
            Iconsax.card,
            Colors.orange,
            colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon,
      Color accentColor, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accentColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SECTION HEADER ====================
  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  // ==================== CHART SECTION ====================
  Widget _buildChartSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    required ColorScheme colorScheme,
    bool isHighlight = false,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: isHighlight
                ? Border.all(
                    color: colorScheme.primary.withOpacity(0.3), width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 20, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              child,
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2),
      ),
    );
  }

  // ==================== ESTADOS DE CARGA Y ERROR ====================

  Widget _buildErrorState(Object? error) {
    developer.log(
      'Error capturado por FutureBuilder en AnalysisScreen',
      name: 'AnalysisScreen',
      error: error,
    );

    return Center(
      child: EmptyStateCard(
        title: 'Ocurrió un Error',
        message:
            'No se pudieron cargar los datos de análisis.\n\nError: $error',
        icon: Iconsax.warning_2,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Container(width: 250, height: 28.0, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLottieEmptyState({required Future<void> Function() onRefresh}) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Stack(
        children: [
          ListView(),
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
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Registra algunas transacciones para empezar a ver tus análisis inteligentes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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

// ==================== EXTENSIÓN ====================
extension on AnalysisData {
  bool get hasData =>
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
