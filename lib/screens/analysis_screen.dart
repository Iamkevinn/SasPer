// lib/screens/analysis_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA DE DISEÑO — Apple iOS                                            │
// │  • Jerarquía absoluta: insight → métricas → descubrimientos → gráficos.   │
// │  • Cada elemento tiene un propósito. Nada existe por decoración.           │
// │  • Animaciones de entrada escalonadas (stagger). Sin loops ni pulsos.      │
// │  • Colores semánticos únicamente donde codifican significado real.         │
// │  • El espacio en blanco es parte del diseño, no ausencia de él.            │
// │  • Separadores .5px en lugar de cards anidadas para agrupar contexto.      │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/insight_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/analysis_charts/average_analysis_section.dart';
import 'package:sasper/widgets/analysis_charts/category_comparison_chart.dart';
import 'package:sasper/widgets/analysis_charts/expense_pie_chart.dart';
import 'package:sasper/widgets/analysis_charts/heatmap_section.dart';
import 'package:sasper/widgets/analysis_charts/income_expense_bar_chart.dart';
import 'package:sasper/widgets/analysis_charts/income_pie_chart.dart';
import 'package:sasper/widgets/analysis_charts/monthly_cashflow_chart.dart';
import 'package:sasper/widgets/analysis_charts/mood_by_day_chart.dart';
import 'package:sasper/widgets/analysis_charts/mood_spending_analysis_card.dart';
import 'package:sasper/widgets/analysis_charts/net_worth_trend_chart.dart';
import 'package:sasper/widgets/analysis/insight_card.dart';

// ─── TOKENS DE DISEÑO iOS ────────────────────────────────────────────────────
abstract class _iOS {
  // Fondos y superficies
  static Color bg(BuildContext ctx) =>
      _dark(ctx) ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  static Color surface(BuildContext ctx) =>
      _dark(ctx) ? const Color(0xFF1C1C1E) : Colors.white;
  static Color surface2(BuildContext ctx) =>
      _dark(ctx) ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

  // Texto (jerarquía de 4 niveles, igual que UIKit)
  static Color label(BuildContext ctx) =>
      _dark(ctx) ? Colors.white : const Color(0xFF1C1C1E);
  static Color label2(BuildContext ctx) =>
      _dark(ctx) ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  static Color label3(BuildContext ctx) =>
      _dark(ctx) ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  static Color label4(BuildContext ctx) =>
      _dark(ctx) ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  // Separador
  static Color sep(BuildContext ctx) => _dark(ctx)
      ? const Color(0xFF38383A)
      : const Color(0xFFE5E5EA);

  // Colores semánticos iOS
  static const Color blue   = Color(0xFF007AFF);
  static const Color green  = Color(0xFF34C759);
  static const Color red    = Color(0xFFFF3B30);
  static const Color orange = Color(0xFFFF9F0A);
  static const Color purple = Color(0xFFAF52DE);
  static const Color teal   = Color(0xFF5AC8FA);

  // Espaciado
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;

  // Radios
  static const double rSM = 10.0;
  static const double rMD = 14.0;
  static const double rLG = 18.0;
  static const double rXL = 22.0;

  static bool _dark(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark;
}

// ─── PANTALLA ────────────────────────────────────────────────────────────────
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => AnalysisScreenState();
}

class AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AnalysisRepository.instance;

  late Future<({AnalysisData charts, List<Insight> insights})> _future;
  RealtimeChannel? _channel;
  Timer? _debounce;

  // Controlador de entrada del ícono IA — una vez, no en bucle
  late AnimationController _aiCtrl;
  late Animation<double> _aiScale;
  late Animation<double> _aiOpacity;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _setupRealtime();

    _aiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _aiScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _aiCtrl, curve: Curves.elasticOut),
    );
    _aiOpacity = CurvedAnimation(
      parent: _aiCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _aiCtrl.forward();
    });
  }

  Future<({AnalysisData charts, List<Insight> insights})> _load() async {
    final results = await Future.wait([
      _repo.fetchAllAnalysisData().catchError((_) => AnalysisData.empty()),
      _repo.getInsights().catchError((_) => <Insight>[]),
    ]);
    return (
      charts: results[0] as AnalysisData,
      insights: results[1] as List<Insight>,
    );
  }

  void _setupRealtime() {
    _channel = Supabase.instance.client
        .channel('analysis_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (_) => _debounceRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'insights',
          callback: (_) => _debounceRefresh(),
        )
        .subscribe();
  }

  void _debounceRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _dismissInsight(String id) async {
    HapticFeedback.mediumImpact();
    try {
      await _repo.markInsightAsRead(id);
    } catch (e) {
      developer.log('Error dismissing insight: $e');
      if (mounted) {
        NotificationHelper.show(
          message: 'No se pudo ocultar el consejo',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    _debounce?.cancel();
    _aiCtrl.dispose();
    super.dispose();
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _iOS.bg(context),
        body: FutureBuilder<({AnalysisData charts, List<Insight> insights})>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return _SkeletonLoader(context);
            }
            if (snap.hasError) {
              return _ErrorState(
                error: '${snap.error}',
                onRetry: _refresh,
              );
            }
            if (!snap.hasData ||
                (!snap.data!.charts.hasData &&
                    snap.data!.insights.isEmpty)) {
              return _EmptyState(onRefresh: _refresh);
            }
            return _Content(
              charts: snap.data!.charts,
              insights: snap.data!.insights,
              aiCtrl: _aiCtrl,
              aiScale: _aiScale,
              aiOpacity: _aiOpacity,
              onDismiss: _dismissInsight,
              onRefresh: _refresh,
            );
          },
        ),
      ),
    );
  }
}

// ─── CONTENIDO PRINCIPAL ─────────────────────────────────────────────────────
class _Content extends StatelessWidget {
  final AnalysisData charts;
  final List<Insight> insights;
  final AnimationController aiCtrl;
  final Animation<double> aiScale;
  final Animation<double> aiOpacity;
  final Future<void> Function(String) onDismiss;
  final Future<void> Function() onRefresh;

  const _Content({
    required this.charts,
    required this.insights,
    required this.aiCtrl,
    required this.aiScale,
    required this.aiOpacity,
    required this.onDismiss,
    required this.onRefresh,
  });

  String _statusMessage() {
    if (insights.isEmpty) return 'Analizando tu situación...';
    final pos =
        insights.where((i) => i.severity == InsightSeverity.success).length;
    if (pos > 0) return '$pos buenas noticias detectadas';
    return '${insights.length} descubrimientos disponibles';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _iOS.blue,
      strokeWidth: 1.5,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── HEADER ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            expandedHeight: 108,
            backgroundColor: _iOS.bg(context),
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: LayoutBuilder(
              builder: (ctx, constraints) {
                final pct = ((constraints.maxHeight - kToolbarHeight) /
                        (108 - kToolbarHeight))
                    .clamp(0.0, 1.0);
                return FlexibleSpaceBar(
                  titlePadding: EdgeInsets.zero,
                  title: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          _iOS.md, 0, _iOS.md, _iOS.sm),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: AnimatedOpacity(
                                  opacity: pct,
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    'INTELIGENCIA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.3,
                                      color: _iOS.blue,
                                    ),
                                  ),
                                ),
                              ),
                              // Ícono IA — entra una sola vez
                              FadeTransition(
                                opacity: aiOpacity,
                                child: ScaleTransition(
                                  scale: aiScale,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [_iOS.blue, _iOS.purple],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Iconsax.magic_star,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Financiero',
                            style: TextStyle(
                              fontSize: pct > 0.5 ? 28 : 20,
                              fontWeight: FontWeight.w800,
                              color: _iOS.label(ctx),
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: pct,
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              _statusMessage(),
                              style: TextStyle(
                                fontSize: 13,
                                color: _iOS.label3(ctx),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  background: Container(color: _iOS.bg(context)),
                );
              },
            ),
          ),

          // ── INSIGHT PRINCIPAL ────────────────────────────────────────────
          if (insights.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                label: 'Insight principal',
                delay: 40,
              ),
            ),
            SliverToBoxAdapter(
              child: _FadeSlide(
                delay: 80,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: _iOS.md),
                  child: _HeroInsightCard(
                    insight: insights.first,
                    onDismiss: () => onDismiss(insights.first.id),
                  ),
                ),
              ),
            ),
          ],

          // ── MÉTRICAS RÁPIDAS ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionLabel(label: 'Resumen del mes', delay: 120),
          ),
          SliverToBoxAdapter(
            child: _FadeSlide(
              delay: 160,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: _iOS.md),
                child: _QuickStats(data: charts),
              ),
            ),
          ),

          // ── DESCUBRIMIENTOS SECUNDARIOS ──────────────────────────────────
          if (insights.length > 1) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                label: 'Descubrimientos',
                delay: 200,
              ),
            ),
            SliverToBoxAdapter(
              child: _FadeSlide(
                delay: 240,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: _iOS.md),
                  child: _InsightsList(
                    insights: insights.skip(1).toList(),
                    onDismiss: onDismiss,
                  ),
                ),
              ),
            ),
          ],

          // ── GRÁFICOS ─────────────────────────────────────────────────────
          if (charts.hasData) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(label: 'Análisis', delay: 280),
            ),
            _chartSliver(
              delay: 320,
              visible: charts.expensePieData.isNotEmpty,
              title: 'Distribución de gastos',
              subtitle: 'Dónde se va tu dinero este mes',
              icon: Iconsax.chart_1,
              color: _iOS.red,
              child: ExpensePieChart(data: charts.expensePieData),
            ),
            _chartSliver(
              delay: 360,
              visible: charts.cashflowBarData.isNotEmpty,
              title: 'Flujo de efectivo',
              subtitle: 'Balance mensual de los últimos meses',
              icon: Iconsax.chart_21,
              color: _iOS.green,
              child: MonthlyCashflowChart(data: charts.cashflowBarData),
            ),
            _chartSliver(
              delay: 400,
              visible: charts.moodAnalysisData.isNotEmpty,
              title: 'Estado emocional',
              subtitle: 'Cómo tu ánimo afecta tus decisiones',
              icon: Iconsax.emoji_happy,
              color: _iOS.purple,
              child: MoodSpendingAnalysisCard(
                  analysisData: charts.moodAnalysisData),
            ),
            _chartSliver(
              delay: 440,
              visible: charts.moodByDayData.isNotEmpty,
              title: 'Ánimo semanal',
              subtitle: 'Patrones por día de la semana',
              icon: Iconsax.calendar,
              color: _iOS.purple,
              child: MoodByDayChart(analysisData: charts.moodByDayData),
            ),
            _chartSliver(
              delay: 480,
              visible: charts.netWorthLineData.isNotEmpty,
              title: 'Tendencia patrimonial',
              subtitle: 'Tu evolución financiera',
              icon: Iconsax.trend_up,
              color: _iOS.blue,
              child: NetWorthTrendChart(data: charts.netWorthLineData),
            ),
            _chartSliver(
              delay: 520,
              visible: charts.incomeExpenseBarData.isNotEmpty,
              title: 'Ingresos vs Gastos',
              subtitle: 'Comparativa mensual',
              icon: Iconsax.money_recive,
              color: _iOS.green,
              child: IncomeExpenseBarChart(
                  data: charts.incomeExpenseBarData),
            ),
            _chartSliver(
              delay: 560,
              visible: charts.categoryComparisonData.isNotEmpty,
              title: 'Categorías',
              subtitle: 'Patrones de gasto por categoría',
              icon: Iconsax.category,
              color: _iOS.orange,
              child: CategoryComparisonChart(
                  data: charts.categoryComparisonData),
            ),
            _chartSliver(
              delay: 600,
              visible: charts.incomePieData.isNotEmpty,
              title: 'Fuentes de ingreso',
              subtitle: 'De dónde viene tu dinero',
              icon: Iconsax.wallet_money,
              color: _iOS.green,
              child: IncomePieChart(data: charts.incomePieData),
            ),
            _chartSliver(
              delay: 640,
              visible: charts.monthlyAverage.monthCount > 0 &&
                  charts.categoryAverages.isNotEmpty,
              title: 'Promedios históricos',
              subtitle: 'Tu comportamiento financiero promedio',
              icon: Iconsax.chart_square,
              color: _iOS.blue,
              child: AverageAnalysisSection(
                monthlyData: charts.monthlyAverage,
                categoryData: charts.categoryAverages,
              ),
            ),
            _chartSliver(
              delay: 680,
              visible: charts.heatmapData.isNotEmpty,
              title: 'Actividad diaria',
              subtitle: 'Tu comportamiento financiero día a día',
              icon: Iconsax.grid_1,
              color: _iOS.teal,
              child: HeatmapSection(
                data: charts.heatmapData,
                startDate:
                    DateTime.now().subtract(const Duration(days: 119)),
                endDate: DateTime.now(),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _chartSliver({
    required int delay,
    required bool visible,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    if (!visible) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: _FadeSlide(
        delay: delay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              _iOS.md, 0, _iOS.md, _iOS.sm + 2),
          child: _ChartCard(
            title: title,
            subtitle: subtitle,
            icon: icon,
            color: color,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── LABEL DE SECCIÓN ────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final int delay;

  const _SectionLabel({required this.label, required this.delay});

  @override
  Widget build(BuildContext context) {
    return _FadeSlide(
      delay: delay,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            _iOS.md, _iOS.lg, _iOS.md, _iOS.sm),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: _iOS.label3(context),
          ),
        ),
      ),
    );
  }
}

// ─── HERO INSIGHT CARD ───────────────────────────────────────────────────────
class _HeroInsightCard extends StatefulWidget {
  final Insight insight;
  final VoidCallback onDismiss;

  const _HeroInsightCard({
    required this.insight,
    required this.onDismiss,
  });

  @override
  State<_HeroInsightCard> createState() => _HeroInsightCardState();
}

class _HeroInsightCardState extends State<_HeroInsightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _dismissCtrl;
  late Animation<double> _dismissOpacity;
  late Animation<double> _dismissScale;
  late Animation<double> _dismissHeight;

  @override
  void initState() {
    super.initState();
    _dismissCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _dismissOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
          parent: _dismissCtrl,
          curve: const Interval(0, .6, curve: Curves.easeOut)),
    );
    _dismissScale = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _dismissCtrl, curve: Curves.easeOut),
    );
    _dismissHeight = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
          parent: _dismissCtrl,
          curve: const Interval(.4, 1, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _dismissCtrl.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    HapticFeedback.lightImpact();
    _dismissCtrl.forward().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.insight.severity.getColor(context);
    final icon = widget.insight.severity.icon;

    return AnimatedBuilder(
      animation: _dismissCtrl,
      builder: (ctx, child) {
        return SizeTransition(
          sizeFactor: _dismissHeight,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _dismissOpacity,
            child: ScaleTransition(
              scale: _dismissScale,
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => HapticFeedback.selectionClick(),
        child: Container(
          decoration: BoxDecoration(
            color: _iOS.surface(context),
            borderRadius: BorderRadius.circular(_iOS.rXL),
            border: Border.all(
              color: color.withOpacity(0.18),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(_iOS.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chip de severidad
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.insight.severity.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Ícono + título
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(_iOS.rMD),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  const SizedBox(width: _iOS.md),
                  Expanded(
                    child: Text(
                      widget.insight.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _iOS.label(context),
                        letterSpacing: -0.3,
                        height: 1.25,
                      ),
                    ),
                  ),
                  // Botón cerrar minimalista
                  GestureDetector(
                    onTap: _handleDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _iOS.label4(context),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Descripción
              Text(
                widget.insight.displayDescription,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: _iOS.label2(context),
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 18),

              // Acciones
              Row(
                children: [
                  GestureDetector(
                    onTap: _handleDismiss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(_iOS.rSM),
                      ),
                      child: Text(
                        'Entendido',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── LISTA DE INSIGHTS AGRUPADOS ─────────────────────────────────────────────
// Estilo iOS: filas agrupadas con separador interno, no cards individuales
class _InsightsList extends StatelessWidget {
  final List<Insight> insights;
  final Future<void> Function(String) onDismiss;

  const _InsightsList({
    required this.insights,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_iOS.rLG),
      child: Container(
        color: _iOS.surface(context),
        child: Column(
          children: List.generate(insights.length, (i) {
            final insight = insights[i];
            final color = insight.severity.getColor(context);
            final isLast = i == insights.length - 1;

            return _InsightRow(
              insight: insight,
              color: color,
              showSeparator: !isLast,
              onDismiss: () => onDismiss(insight.id),
            );
          }),
        ),
      ),
    );
  }
}

class _InsightRow extends StatefulWidget {
  final Insight insight;
  final Color color;
  final bool showSeparator;
  final VoidCallback onDismiss;

  const _InsightRow({
    required this.insight,
    required this.color,
    required this.showSeparator,
    required this.onDismiss,
  });

  @override
  State<_InsightRow> createState() => _InsightRowState();
}

class _InsightRowState extends State<_InsightRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    _ctrl.forward().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => HapticFeedback.selectionClick(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _pressed
              ? _iOS.surface2(context)
              : _iOS.surface(context),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: _iOS.md, vertical: 13),
                child: Row(
                  children: [
                    // Ícono semántico
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        widget.insight.severity.icon,
                        size: 15,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Texto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.insight.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _iOS.label(context),
                              letterSpacing: -0.1,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.insight.displayDescription,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: _iOS.label3(context),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Dismiss
                    GestureDetector(
                      onTap: _dismiss,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: _iOS.label4(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Separador interno .5px — solo si no es el último
              if (widget.showSeparator)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 62),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: _iOS.sep(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── QUICK STATS ─────────────────────────────────────────────────────────────
class _QuickStats extends StatelessWidget {
  final AnalysisData data;

  const _QuickStats({required this.data});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    // Datos reales de las RPCs
    final balance = data.netWorthLineData.isNotEmpty
        ? data.netWorthLineData.last.totalBalance
        : 0.0;
    final cashflow = data.cashflowBarData.isNotEmpty
        ? data.cashflowBarData.last.cashFlow
        : 0.0;
    final totalExpenses = data.expensePieData.isNotEmpty
        ? data.expensePieData.fold<double>(
            0, (s, e) => s + e.totalSpent)
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Balance',
            value: fmt.format(balance),
            icon: Iconsax.wallet_3,
            color: balance >= 0 ? _iOS.green : _iOS.red,
          ),
        ),
        const SizedBox(width: _iOS.sm + 2),
        Expanded(
          child: _StatTile(
            label: 'Flujo',
            value: fmt.format(cashflow),
            icon: Iconsax.trend_up,
            color: cashflow >= 0 ? _iOS.green : _iOS.red,
          ),
        ),
        const SizedBox(width: _iOS.sm + 2),
        Expanded(
          child: _StatTile(
            label: 'Gastos',
            value: fmt.format(totalExpenses),
            icon: Iconsax.card,
            color: _iOS.red,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => HapticFeedback.selectionClick(),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(_iOS.md),
          decoration: BoxDecoration(
            color: _iOS.surface(context),
            borderRadius: BorderRadius.circular(_iOS.rLG),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, size: 14, color: widget.color),
              ),
              const SizedBox(height: _iOS.sm + 2),
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _iOS.label(context),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: _iOS.label3(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── CHART CARD ──────────────────────────────────────────────────────────────
class _ChartCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () => HapticFeedback.selectionClick(),
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: _iOS.surface(context),
            borderRadius: BorderRadius.circular(_iOS.rXL),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    _iOS.md, _iOS.md, _iOS.md, 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(widget.icon,
                          size: 16, color: widget.color),
                    ),
                    const SizedBox(width: _iOS.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _iOS.label(context),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: _iOS.label3(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Separador .5px
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: _iOS.md,
                endIndent: _iOS.md,
                color: _iOS.sep(context),
              ),

              // Contenido del gráfico
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ESTADOS ─────────────────────────────────────────────────────────────────
Widget _EmptyState({required Future<void> Function() onRefresh}) {
  return Builder(builder: (context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _iOS.blue,
      strokeWidth: 1.5,
      child: Stack(
        children: [
          ListView(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(_iOS.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/animations/analysis_animation.json',
                    width: 180,
                    height: 180,
                  ),
                  const SizedBox(height: _iOS.lg),
                  Text(
                    'Sin datos aún',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _iOS.label(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: _iOS.sm),
                  Text(
                    'Registra algunas transacciones para ver tus análisis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: _iOS.label3(context),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  });
}

Widget _ErrorState({
  required String error,
  required Future<void> Function() onRetry,
}) {
  return Builder(builder: (context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_iOS.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _iOS.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.warning_2,
                  size: 26, color: _iOS.red),
            ),
            const SizedBox(height: _iOS.lg),
            Text(
              'Algo salió mal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _iOS.label(context),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: _iOS.sm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: _iOS.label3(context)),
            ),
            const SizedBox(height: _iOS.lg),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _iOS.lg, vertical: 12),
                decoration: BoxDecoration(
                  color: _iOS.blue,
                  borderRadius: BorderRadius.circular(_iOS.rMD),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  });
}

// ─── SKELETON LOADER ─────────────────────────────────────────────────────────
Widget _SkeletonLoader(BuildContext context) {
  return _ShimmerLoader();
}

class _ShimmerLoader extends StatefulWidget {
  @override
  State<_ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<_ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        final shimmer = Color.lerp(
          _iOS.surface(ctx),
          _iOS.surface2(ctx),
          _anim.value,
        )!;

        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 108,
                color: _iOS.bg(ctx),
                padding: const EdgeInsets.fromLTRB(
                    _iOS.md, 60, _iOS.md, _iOS.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(shimmer, 70, 9, 4),
                    const SizedBox(height: 6),
                    _box(shimmer, 150, 20, 6),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    _iOS.md, _iOS.lg, _iOS.md, 0),
                child: _box(shimmer, double.infinity, 130, _iOS.rXL),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    _iOS.md, _iOS.md, _iOS.md, 0),
                child: Row(
                  children: [
                    Expanded(
                        child: _box(shimmer, double.infinity, 88,
                            _iOS.rLG)),
                    const SizedBox(width: _iOS.sm),
                    Expanded(
                        child: _box(shimmer, double.infinity, 88,
                            _iOS.rLG)),
                    const SizedBox(width: _iOS.sm),
                    Expanded(
                        child: _box(shimmer, double.infinity, 88,
                            _iOS.rLG)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  _iOS.md, _iOS.lg, _iOS.md, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: _iOS.sm + 2),
                    child:
                        _box(shimmer, double.infinity, 200, _iOS.rXL),
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

  Widget _box(Color c, double w, double h, double r) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(r),
        ),
      );
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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(
      Duration(milliseconds: widget.delay),
      () { if (mounted) _ctrl.forward(); },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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

// ─── EXTENSIÓN SEVERIDAD — solo label (getColor e icon viven en insight_model.dart) ──
extension _InsightSeverityLabel on InsightSeverity {
  String get label {
    switch (this) {
      case InsightSeverity.success:
        return 'Buenas noticias';
      case InsightSeverity.warning:
        return 'Atención recomendada';
      case InsightSeverity.alert:
        return 'Acción necesaria';
      case InsightSeverity.info:
        return 'Para tu información';
    }
  }
}