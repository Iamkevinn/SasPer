// lib/screens/analysis_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA DE DISEÑO — Apple iOS                                            │
// │  • El AppBar no compite con el contenido. Título con padding generoso.     │
// │  • Jerarquía de información: insight principal → stats → gráficos.         │
// │  • Cada sección respira. El espacio en blanco es intencional.              │
// │  • Colores semánticos vivos pero controlados — siempre adaptativos.        │
// │  • El ícono de IA tiene su momento; no pulsa constantemente.               │
// │  • Las tarjetas de gráficos son contenedores neutros: el gráfico habla.    │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sasper/widgets/analysis_charts/average_analysis_section.dart';
import 'package:sasper/widgets/analysis_charts/mood_by_day_chart.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/insight_model.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/widgets/analysis_charts/mood_spending_analysis_card.dart';
import 'package:sasper/widgets/analysis_charts/heatmap_section.dart';
import 'package:sasper/widgets/analysis_charts/monthly_cashflow_chart.dart';
import 'package:sasper/widgets/analysis_charts/net_worth_trend_chart.dart';
import 'package:sasper/widgets/analysis_charts/income_expense_bar_chart.dart';
import 'package:sasper/widgets/analysis_charts/category_comparison_chart.dart';
import 'package:sasper/widgets/analysis_charts/expense_pie_chart.dart';
import 'package:sasper/widgets/analysis_charts/income_pie_chart.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/analysis/insight_card.dart';
import 'package:intl/intl.dart';

// ─── TOKENS DINÁMICOS ────────────────────────────────────────────────────────
class _C {
  final BuildContext ctx;
  _C(this.ctx);

  bool get isDark => Theme.of(ctx).brightness == Brightness.dark;

  // Superficies
  Color get bg =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get surface =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get surfaceRaised =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get separator =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  // Texto
  Color get label =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  Color get label2 =>
      isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color get label3 =>
      isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get label4 =>
      isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  // Semánticos — iOS colors
  static const Color expense = Color(0xFFFF3B30);
  static const Color income  = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color accent  = Color(0xFF0A84FF);
  static const Color purple  = Color(0xFFBF5AF2);

  // Espaciado
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;

  // Radios
  static const double rSM = 8.0;
  static const double rMD = 12.0;
  static const double rLG = 16.0;
  static const double rXL = 20.0;

  // Animaciones
  static const Duration fast  = Duration(milliseconds: 150);
  static const Duration mid   = Duration(milliseconds: 280);
  static const Duration slow  = Duration(milliseconds: 440);
  static const Curve curveOut = Curves.easeOutCubic;
}

// ─── PANTALLA PRINCIPAL ──────────────────────────────────────────────────────
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

  // Controlador de animación del ícono IA — solo en la entrada, no en bucle
  late AnimationController _aiEntryController;
  late Animation<double> _aiScale;
  late Animation<double> _aiOpacity;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _fetchAllScreenData();
    _setupRealtimeSubscription();

    // Entra suavemente una sola vez — no pulsa infinitamente
    _aiEntryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _aiScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _aiEntryController, curve: Curves.elasticOut),
    );

    _aiOpacity = CurvedAnimation(
      parent: _aiEntryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    // Inicia la animación del ícono IA con un delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _aiEntryController.forward();
    });
  }

  Future<({AnalysisData charts, List<Insight> insights})>
      _fetchAllScreenData() async {
    final results = await Future.wait([
      _repository.fetchAllAnalysisData().catchError((e) {
        developer.log('Error gráficos', name: 'AnalysisScreen', error: e);
        return AnalysisData.empty();
      }),
      _repository.getInsights().catchError((e) {
        developer.log('Error insights', name: 'AnalysisScreen', error: e);
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
    _aiEntryController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (mounted) {
      setState(() => _analysisFuture = _fetchAllScreenData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _C(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            c.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: _C.accent,
          strokeWidth: 1.5,
          child: FutureBuilder<({AnalysisData charts, List<Insight> insights})>(
            future: _analysisFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _SkeletonLoader(c: c);
              }
              if (snapshot.hasError) {
                return _ErrorState(
                    error: '${snapshot.error}', c: c,
                    onRetry: _handleRefresh);
              }
              if (!snapshot.hasData) {
                return _EmptyState(c: c, onRefresh: _handleRefresh);
              }

              final data = snapshot.data!;
              if (!data.charts.hasData && data.insights.isEmpty) {
                return _EmptyState(c: c, onRefresh: _handleRefresh);
              }

              return _buildContent(data.charts, data.insights, c);
            },
          ),
        ),
      ),
    );
  }

  // ── Contenido principal ──────────────────────────────────────────────────
  Widget _buildContent(
      AnalysisData chartData, List<Insight> insights, _C c) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── HEADER ────────────────────────────────────────────────────────
        _buildSliverHeader(insights, c),

        // ── INSIGHT HERO ──────────────────────────────────────────────────
        if (insights.isNotEmpty)
          SliverToBoxAdapter(
            child: _FadeSlide(
              delay: 60,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    _C.md, _C.md, _C.md, 0),
                child: _HeroInsightCard(
                    insight: insights.first, c: c),
              ),
            ),
          ),

        // ── QUICK STATS ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _FadeSlide(
            delay: 100,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  _C.md, _C.md, _C.md, 0),
              child: _QuickStats(data: chartData, c: c),
            ),
          ),
        ),

        // ── INSIGHTS SECUNDARIOS ──────────────────────────────────────────
        if (insights.length > 1) ...[
          SliverToBoxAdapter(
            child: _SectionLabel(
              label: 'Descubrimientos clave',
              c: c,
              topPadding: _C.lg,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _C.md),
            sliver: SliverList.separated(
              itemCount: insights.length - 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: _C.sm + 2),
              itemBuilder: (context, i) => _FadeSlide(
                delay: 140 + i * 50,
                child: InsightCard(insight: insights[i + 1]),
              ),
            ),
          ),
        ],

        // ── GRÁFICOS ──────────────────────────────────────────────────────
        if (chartData.hasData) ...[
          SliverToBoxAdapter(
            child: _SectionLabel(
              label: 'Análisis detallado',
              c: c,
              topPadding: _C.lg,
            ),
          ),

          _chartSliver(
            delay: 160,
            title: 'Tendencia patrimonial',
            subtitle: 'Tu evolución financiera',
            icon: Iconsax.trend_up,
            color: _C.accent,
            c: c,
            visible: chartData.netWorthLineData.isNotEmpty,
            child: NetWorthTrendChart(data: chartData.netWorthLineData),
          ),

          _chartSliver(
            delay: 200,
            title: 'Análisis emocional',
            subtitle: 'Cómo tu ánimo afecta tus finanzas',
            icon: Iconsax.emoji_happy,
            color: _C.purple,
            c: c,
            visible: chartData.moodAnalysisData.isNotEmpty,
            highlight: true,
            child: MoodSpendingAnalysisCard(
                analysisData: chartData.moodAnalysisData),
          ),

          _chartSliver(
            delay: 240,
            title: 'Flujo de efectivo',
            subtitle: 'Balance mensual',
            icon: Iconsax.chart_21,
            color: _C.income,
            c: c,
            visible: chartData.cashflowBarData.isNotEmpty,
            child: MonthlyCashflowChart(data: chartData.cashflowBarData),
          ),

          _chartSliver(
            delay: 280,
            title: 'Categorías',
            subtitle: 'Patrones de gasto mensuales',
            icon: Iconsax.category,
            color: _C.warning,
            c: c,
            visible: chartData.categoryComparisonData.isNotEmpty,
            child: CategoryComparisonChart(
                data: chartData.categoryComparisonData),
          ),

          _chartSliver(
            delay: 320,
            title: 'Promedios',
            subtitle: 'Comportamiento financiero promedio',
            icon: Iconsax.chart_square,
            color: _C.accent,
            c: c,
            visible: chartData.monthlyAverage.monthCount > 0 &&
                chartData.categoryAverages.isNotEmpty,
            child: AverageAnalysisSection(
              monthlyData: chartData.monthlyAverage,
              categoryData: chartData.categoryAverages,
            ),
          ),

          _chartSliver(
            delay: 360,
            title: 'Ingresos vs Gastos',
            subtitle: 'Comparativa mensual',
            icon: Iconsax.money_recive,
            color: _C.income,
            c: c,
            visible: chartData.incomeExpenseBarData.isNotEmpty,
            child: IncomeExpenseBarChart(
                data: chartData.incomeExpenseBarData),
          ),

          _chartSliver(
            delay: 400,
            title: 'Distribución de gastos',
            subtitle: 'Dónde se va tu dinero',
            icon: Iconsax.chart_1,
            color: _C.expense,
            c: c,
            visible: chartData.expensePieData.isNotEmpty,
            child: ExpensePieChart(data: chartData.expensePieData),
          ),

          _chartSliver(
            delay: 440,
            title: 'Fuentes de ingreso',
            subtitle: 'De dónde viene tu dinero',
            icon: Iconsax.wallet_money,
            color: _C.income,
            c: c,
            visible: chartData.incomePieData.isNotEmpty,
            child: IncomePieChart(data: chartData.incomePieData),
          ),

          _chartSliver(
            delay: 480,
            title: 'Ánimo semanal',
            subtitle: 'Patrones emocionales por día',
            icon: Iconsax.calendar,
            color: _C.purple,
            c: c,
            visible: chartData.moodByDayData.isNotEmpty,
            child: MoodByDayChart(analysisData: chartData.moodByDayData),
          ),

          _chartSliver(
            delay: 520,
            title: 'Actividad diaria',
            subtitle: 'Tu comportamiento financiero',
            icon: Iconsax.grid_1,
            color: _C.accent,
            c: c,
            visible: chartData.heatmapData.isNotEmpty,
            child: HeatmapSection(
              data: chartData.heatmapData,
              startDate:
                  DateTime.now().subtract(const Duration(days: 119)),
              endDate: DateTime.now(),
            ),
          ),
        ],

        // Espacio para la nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────
  // El título está indentado para no chocar con el botón de regreso.
  // Usa padding explícito en lugar de depender del default del AppBar.
  Widget _buildSliverHeader(List<Insight> insights, _C c) {
    final statusMsg = _statusMessage(insights);

    return SliverAppBar(
      pinned: true,
      floating: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: 110,
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,

      // Sin leading — esta pantalla es un tab, no tiene back button.
      // Si en tu app tiene back button, el padding ya lo compensa.
      automaticallyImplyLeading: false,

      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final percent = ((constraints.maxHeight - kToolbarHeight) /
                  (110 - kToolbarHeight))
              .clamp(0.0, 1.0);

          return FlexibleSpaceBar(
            titlePadding: EdgeInsets.zero,
            title: SafeArea(
              bottom: false,
              child: Padding(
                // Padding izquierdo generoso: nunca choca con el back button
                padding: const EdgeInsets.fromLTRB(
                    _C.md, 0, _C.md, _C.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Eyebrow — solo visible cuando está expandido
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: percent,
                            duration: _C.mid,
                            child: Text(
                              'INTELIGENCIA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: _C.accent,
                              ),
                            ),
                          ),
                        ),
                        // Ícono IA — entra animado una sola vez
                        FadeTransition(
                          opacity: _aiOpacity,
                          child: ScaleTransition(
                            scale: _aiScale,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_C.accent, _C.purple],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Iconsax.magic_star,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Título principal
                    Text(
                      'Financiero',
                      style: TextStyle(
                        fontSize: percent > 0.5 ? 28 : 20,
                        fontWeight: FontWeight.w800,
                        color: c.label,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    // Subtítulo — desaparece al colapsar
                    AnimatedOpacity(
                      opacity: percent,
                      duration: _C.mid,
                      child: Text(
                        statusMsg,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.label3,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            background: Container(color: c.bg),
          );
        },
      ),
    );
  }

  String _statusMessage(List<Insight> insights) {
    if (insights.isEmpty) return 'Analizando tu situación...';
    final positive =
        insights.where((i) => i.severity == InsightSeverity.success).length;
    if (positive > 0) return '$positive buenas noticias detectadas';
    return '${insights.length} insights disponibles';
  }

  // ── Sliver de gráfico ────────────────────────────────────────────────────
  Widget _chartSliver({
    required int delay,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required _C c,
    required bool visible,
    required Widget child,
    bool highlight = false,
  }) {
    if (!visible) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: _FadeSlide(
        delay: delay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              _C.md, 0, _C.md, _C.md),
          child: _ChartCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color,
            c: c,
            highlight: highlight,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── LABEL DE SECCIÓN ────────────────────────────────────────────────────────
// Devuelve un Widget normal — el llamador decide si lo envuelve en Sliver.
class _SectionLabel extends StatelessWidget {
  final String label;
  final _C c;
  final double topPadding;

  const _SectionLabel({
    required this.label,
    required this.c,
    this.topPadding = _C.md,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_C.md, topPadding, _C.md, _C.sm),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: c.label3,
        ),
      ),
    );
  }
}

// ─── HERO INSIGHT CARD ───────────────────────────────────────────────────────
// El insight más importante. Tiene peso visual propio pero no grita.
class _HeroInsightCard extends StatelessWidget {
  final Insight insight;
  final _C c;

  const _HeroInsightCard({required this.insight, required this.c});

  @override
  Widget build(BuildContext context) {
    final color = insight.severity.getColor(context);
    final icon  = insight.severity.icon;

    return Container(
      padding: const EdgeInsets.all(_C.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(c.isDark ? 0.12 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: ícono + etiqueta + título
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(c.isDark ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(_C.rMD),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: _C.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSIGHT PRINCIPAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: c.label3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insight.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: _C.md),

          // Descripción
          Text(
            insight.description,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: c.label2,
              letterSpacing: 0.1,
            ),
          ),

          const SizedBox(height: _C.md),

          // CTA mínimo
          GestureDetector(
            onTap: () => HapticFeedback.selectionClick(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ver detalles',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: color, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QUICK STATS ─────────────────────────────────────────────────────────────
// 3 métricas clave. Compactas, legibles, con un color por métrica.
class _QuickStats extends StatelessWidget {
  final AnalysisData data;
  final _C c;

  const _QuickStats({required this.data, required this.c});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    final balance = data.netWorthLineData.isNotEmpty
        ? data.netWorthLineData.last.totalBalance
        : 0.0;
    final cashflow = data.cashflowBarData.isNotEmpty
        ? data.cashflowBarData.last.cashFlow
        : 0.0;
    final totalExpenses = data.expensePieData.isNotEmpty
        ? data.expensePieData.fold<double>(
            0, (sum, item) => sum + item.totalSpent)
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Balance',
            value: fmt.format(balance),
            icon: Iconsax.wallet_3,
            color: balance >= 0 ? _C.income : _C.expense,
            c: c,
          ),
        ),
        const SizedBox(width: _C.sm),
        Expanded(
          child: _StatTile(
            label: 'Flujo',
            value: fmt.format(cashflow),
            icon: Iconsax.trend_up,
            color: cashflow >= 0 ? _C.income : _C.expense,
            c: c,
          ),
        ),
        const SizedBox(width: _C.sm),
        Expanded(
          child: _StatTile(
            label: 'Gastos',
            value: fmt.format(totalExpenses),
            icon: Iconsax.card,
            color: _C.expense,
            c: c,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final _C c;

  const _StatTile({
    required this.label, required this.value,
    required this.icon, required this.color, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rLG),
        border: Border.all(color: c.separator.withOpacity(0.5), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.2 : 0.04),
            blurRadius: 8, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(c.isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(_C.rSM),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: _C.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.label,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: c.label3),
          ),
        ],
      ),
    );
  }
}

// ─── CHART CARD ──────────────────────────────────────────────────────────────
// Contenedor neutro para cada gráfico.
// El gráfico habla; la tarjeta solo lo enmarca.
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final _C c;
  final Widget child;
  final bool highlight;

  const _ChartCard({
    required this.title, required this.subtitle, required this.icon,
    required this.color, required this.c, required this.child,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: highlight
            ? Border.all(
                color: color.withOpacity(0.25),
                width: 1,
              )
            : Border.all(color: c.separator.withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.18 : 0.04),
            blurRadius: 12, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la tarjeta
          Padding(
            padding: const EdgeInsets.fromLTRB(
                _C.md, _C.md, _C.md, _C.sm),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(c.isDark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(_C.rSM + 2),
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: _C.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.label,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: c.label3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Línea separadora sutil
          Container(
              height: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: _C.md),
              color: c.separator),

          // El gráfico en sí — sin padding adicional para que respire su propia manera
          child,
        ],
      ),
    );
  }
}

// ─── ESTADOS ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _C c;
  final Future<void> Function() onRefresh;

  const _EmptyState({required this.c, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _C.accent,
      strokeWidth: 1.5,
      child: Stack(
        children: [
          ListView(), // hace que el RefreshIndicator funcione
          Center(
            child: Padding(
              padding: const EdgeInsets.all(_C.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animations/analysis_animation.json',
                    width: 200, height: 200,
                  ),
                  const SizedBox(height: _C.lg),
                  Text(
                    'Sin datos aún',
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: c.label, letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: _C.sm),
                  Text(
                    'Registra algunas transacciones para ver tus análisis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: c.label3, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final _C c;
  final VoidCallback onRetry;

  const _ErrorState(
      {required this.error, required this.c, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_C.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _C.expense.withOpacity(c.isDark ? 0.18 : 0.09),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.warning_2,
                  size: 28, color: _C.expense),
            ),
            const SizedBox(height: _C.lg),
            Text('Algo salió mal',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: c.label, letterSpacing: -0.3,
                )),
            const SizedBox(height: _C.sm),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.label3)),
            const SizedBox(height: _C.lg),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _C.lg, vertical: 12),
                decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(_C.rMD)),
                child: const Text('Reintentar',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SKELETON LOADER ─────────────────────────────────────────────────────────
class _SkeletonLoader extends StatefulWidget {
  final _C c;
  const _SkeletonLoader({required this.c});

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this)
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer =
            Color.lerp(c.surface, c.surfaceRaised, _anim.value)!;

        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            // Simula el header
            SliverToBoxAdapter(
              child: Container(
                height: 110,
                color: c.bg,
                padding: const EdgeInsets.fromLTRB(
                    _C.md, 60, _C.md, _C.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(shimmer, 80, 10, _C.rSM),
                    const SizedBox(height: 6),
                    _shimmerBox(shimmer, 160, 22, _C.rSM),
                  ],
                ),
              ),
            ),

            // Hero card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    _C.md, _C.md, _C.md, 0),
                child: _shimmerBox(shimmer, double.infinity, 140, _C.rXL),
              ),
            ),

            // Quick stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    _C.md, _C.md, _C.md, 0),
                child: Row(
                  children: [
                    Expanded(
                        child: _shimmerBox(
                            shimmer, double.infinity, 90, _C.rLG)),
                    const SizedBox(width: _C.sm),
                    Expanded(
                        child: _shimmerBox(
                            shimmer, double.infinity, 90, _C.rLG)),
                    const SizedBox(width: _C.sm),
                    Expanded(
                        child: _shimmerBox(
                            shimmer, double.infinity, 90, _C.rLG)),
                  ],
                ),
              ),
            ),

            // Gráficos
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  _C.md, _C.lg, _C.md, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: _C.md),
                    child: _shimmerBox(
                        shimmer, double.infinity, 220, _C.rXL),
                  ),
                  childCount: 3,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _shimmerBox(
      Color color, double w, double h, double radius) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius)),
    );
  }
}

// ─── ANIMACIÓN DE ENTRADA ────────────────────────────────────────────────────
class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;
  const _FadeSlide({required this.child, required this.delay});

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: _C.slow, vsync: this);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _ctrl, curve: _C.curveOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─── EXTENSIÓN ───────────────────────────────────────────────────────────────
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