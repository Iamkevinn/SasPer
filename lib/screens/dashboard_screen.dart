// lib/screens/dashboard_screen.dart
// VERSIÓN PREMIUM COMPLETA - Con IA en tiempo real, simulaciones y gamificación
//import 'package:sasper/services/widget_service.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/screens/budget_details_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/services/widgets/widget_orchestrator.dart';
import 'package:sasper/widgets/dashboard/active_challenges_widget.dart';
import 'package:sasper/widgets/dashboard/category_spending_chart.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Pantallas
import 'package:sasper/screens/goals_screen.dart';
import 'package:sasper/screens/can_i_afford_it_screen.dart';
import 'package:sasper/screens/ia_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final DashboardRepository _dashboardRepository = DashboardRepository.instance;

  late final Stream<DashboardData> _dashboardDataStream;
  bool _hasShownCelebration = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;

  // Control de accesibilidad
  bool _reduceMotion = false;
  bool _highContrast = false;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    developer.log(
        "✅ [DashboardV3] initState: Configurando streams y carga inicial...",
        name: "Dashboard");

    _dashboardDataStream = _dashboardRepository.getDashboardDataStream();
    // Escuchamos el stream para actualizar los widgets cuando lleguen nuevos datos.
    _dataSubscription = _dashboardDataStream.listen((data) {
      // Nos aseguramos de que no esté en estado de carga y de que el contexto esté disponible.
      if (!data.isLoading && mounted) {
        developer.log(
            '✅ INTENTANDO ACTUALIZAR WIDGETS DESDE EL DASHBOARD (Stream Listener)',
            name: 'DashboardScreen');
        // Creamos una instancia y llamamos al método de actualización.
        WidgetOrchestrator().updateAllFromDashboard(data, context);
      }
    });
    _dashboardRepository.forceRefresh(silent: true);

    // Animación de pulso para botón IA
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de respiración para health meter
    _breatheController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _breatheAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    // Detectar preferencias de accesibilidad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _reduceMotion = MediaQuery.of(context).disableAnimations;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dataSubscription?.cancel();
    _breatheController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await _dashboardRepository.forceRefresh(silent: false);
  }

  void _navigateToAiAnalysisScreen(DashboardData data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AiAnalysisFullScreen(dashboardData: data),
      ),
    );
  }

  void _navigateToAiAnalysisScreenTwo() {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (context) => const AiFinancialAnalysisScreen()),
    );
  }

  void _navigateToCanIAffordIt() => Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CanIAffordItScreen()));

  void _navigateToTransactionsScreen() => Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TransactionsScreen()));

  void _navigateToGoalsScreen() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (context) => const GoalsScreen()));

  Future<void> _checkAndShowCelebrations(DashboardData data) async {
    if (_hasShownCelebration) return;
    _hasShownCelebration = true;

    try {
      final newlyCompleted =
          await ChallengeRepository.instance.checkUserChallengesStatus();

      if (newlyCompleted.isEmpty || !mounted) {
        return;
      }

      for (var userChallenge in newlyCompleted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildCelebrationDialog(userChallenge),
          );
        }
      }
    } catch (e) {
      developer.log("🔥 Error al chequear retos para celebración: $e",
          name: "Dashboard");
    }
  }

  Widget _buildCelebrationDialog(UserChallenge userChallenge) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_reduceMotion)
              SizedBox(
                width: 200,
                height: 150,
                child: Lottie.asset(
                  'assets/animations/confetti_celebration.json',
                  repeat: false,
                ),
              ),
            Text(
              '¡Reto Completado!',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              userChallenge.challengeDetails.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Chip(
              avatar: const Icon(Iconsax.star_1, size: 18),
              label: Text('+${userChallenge.challengeDetails.rewardXp} XP',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: Colors.amber.withOpacity(0.3),
              side: BorderSide.none,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
              child: const Text('¡Genial!'),
            )
          ],
        ),
      ),
    );
  }

  void _toggleAccessibilityMode(String mode) {
    setState(() {
      if (mode == 'contrast') {
        _highContrast = !_highContrast;
      } else if (mode == 'motion') {
        _reduceMotion = !_reduceMotion;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<DashboardData>(
          stream: _dashboardDataStream,
          builder: (context, snapshot) {
            final isLoading = !snapshot.hasData || snapshot.data!.isLoading;
            final data = isLoading ? DashboardData.empty() : snapshot.data!;

            if (!isLoading && !_hasShownCelebration) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _checkAndShowCelebrations(data));
            }

            return Skeletonizer(
              enabled: isLoading,
              child: _buildDashboardContent(data),
            );
          },
        ),
      ),
      floatingActionButton: _buildAccessibilityFab(),
    );
  }

  Widget _buildAccessibilityFab() {
    return FloatingActionButton.small(
      onPressed: () => _showAccessibilityMenu(),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Iconsax.setting_2, size: 20),
    );
  }

  void _showAccessibilityMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajustes de Accesibilidad',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Alto contraste'),
              subtitle: const Text('Mejora la legibilidad'),
              value: _highContrast,
              onChanged: (_) => _toggleAccessibilityMode('contrast'),
            ),
            SwitchListTile(
              title: const Text('Reducir animaciones'),
              subtitle: const Text('Minimiza efectos de movimiento'),
              value: _reduceMotion,
              onChanged: (_) => _toggleAccessibilityMode('motion'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(DashboardData data) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _PremiumHeaderDelegate(
              data: data,
              pulseAnimation: _reduceMotion
                  ? const AlwaysStoppedAnimation(1.0)
                  : _pulseAnimation,
              breatheAnimation: _reduceMotion
                  ? const AlwaysStoppedAnimation(1.0)
                  : _breatheAnimation,
              onAiTap: () => _navigateToAiAnalysisScreenTwo(),
              minExtent: 120,
              maxExtent: 160,
              highContrast: _highContrast,
            ),
          ),
          SliverToBoxAdapter(
            child: _BalanceHeroCard(
              data: data,
              onSimulateTap: () => _navigateToAiAnalysisScreen(data),
              highContrast: _highContrast,
            ).animate(
                effects: _reduceMotion
                    ? []
                    : [
                        const FadeEffect(delay: Duration(milliseconds: 200)),
                        const SlideEffect(begin: Offset(0, 0.2)),
                      ]),
          ),
          SliverToBoxAdapter(
            child: _LiveRecommendationsFeed(
              data: data,
              highContrast: _highContrast,
            ).animate(
                effects: _reduceMotion
                    ? []
                    : [
                        const FadeEffect(delay: Duration(milliseconds: 250)),
                        const SlideEffect(begin: Offset(0, 0.2)),
                      ]),
          ),
          SliverToBoxAdapter(
            child: _QuickActions(
              onSimulateTap: _navigateToCanIAffordIt,
              onAddTap: _navigateToTransactionsScreen,
              onGoalsTap: _navigateToGoalsScreen,
            ).animate(
                effects: _reduceMotion
                    ? []
                    : [
                        const FadeEffect(delay: Duration(milliseconds: 300)),
                        const SlideEffect(begin: Offset(0, 0.2)),
                      ]),
          ),
          SliverToBoxAdapter(
            child: _BudgetsCarousel(
              budgets: data.featuredBudgets,
              highContrast: _highContrast,
            ).animate(
                effects: _reduceMotion
                    ? []
                    : [
                        const FadeEffect(delay: Duration(milliseconds: 400)),
                        const SlideEffect(begin: Offset(0, 0.2)),
                      ]),
          ),
          SliverToBoxAdapter(
            child: const ActiveChallengesWidget().animate(
                effects: _reduceMotion
                    ? []
                    : [
                        const FadeEffect(delay: Duration(milliseconds: 500)),
                        const SlideEffect(begin: Offset(0, 0.2)),
                      ]),
          ),
          SliverToBoxAdapter(
            child: CategorySpendingChart(
              spendingData: data.categorySpendingSummary,
            ).animate(
                effects: _reduceMotion
                    ? []
                    : [
                        const FadeEffect(delay: Duration(milliseconds: 600)),
                        const SlideEffect(begin: Offset(0, 0.2)),
                      ]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER PREMIUM CON HEALTH METER
// ============================================================================

class _PremiumHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DashboardData data;
  final Animation<double> pulseAnimation;
  final Animation<double> breatheAnimation;
  final VoidCallback onAiTap;
  final bool highContrast;
  @override
  final double minExtent;
  @override
  final double maxExtent;

  _PremiumHeaderDelegate({
    required this.data,
    required this.pulseAnimation,
    required this.breatheAnimation,
    required this.onAiTap,
    required this.minExtent,
    required this.maxExtent,
    required this.highContrast,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = (maxExtent - shrinkOffset) / (maxExtent - minExtent);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
          decoration: BoxDecoration(
            color: highContrast
                ? Colors.black
                : theme.scaffoldBackgroundColor.withOpacity(0.90),
            border: highContrast
                ? const Border(
                    bottom: BorderSide(color: Colors.white, width: 2))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hola, ${data.fullName.split(' ').first} 👋',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: highContrast
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu Central Financiera',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color:
                            highContrast ? Colors.white : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  AnimatedBuilder(
                    animation: breatheAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: breatheAnimation.value,
                        child: _FinancialHealthMeter(
                          score: data.healthScore,
                          progress: progress,
                          highContrast: highContrast,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: pulseAnimation.value,
                        child: Tooltip(
                          message:
                              'Análisis IA - Explora tu situación financiera',
                          child: IconButton(
                            onPressed: onAiTap,
                            icon: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    highContrast
                                        ? Colors.white
                                        : const Color(0xFF0D9488),
                                    highContrast
                                        ? Colors.grey.shade300
                                        : const Color(0xFF0EA5A5)
                                  ]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: highContrast
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF0D9488)
                                                .withOpacity(0.4),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          )
                                        ]),
                              child: Icon(
                                Iconsax.magic_star,
                                color:
                                    highContrast ? Colors.black : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PremiumHeaderDelegate oldDelegate) {
    return data != oldDelegate.data ||
        pulseAnimation != oldDelegate.pulseAnimation ||
        breatheAnimation != oldDelegate.breatheAnimation ||
        onAiTap != oldDelegate.onAiTap ||
        highContrast != oldDelegate.highContrast;
  }
}

// ============================================================================
// BALANCE HERO CARD CON KPI PILLS
// ============================================================================

class _BalanceHeroCard extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onSimulateTap;
  final bool highContrast;

  const _BalanceHeroCard({
    required this.data,
    required this.onSimulateTap,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: highContrast
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0D9488), const Color(0xFF0EA5A5)]
                    : [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
              ),
        color: highContrast ? Colors.black : null,
        border: highContrast ? Border.all(color: Colors.white, width: 2) : null,
        borderRadius: BorderRadius.circular(32),
        boxShadow: highContrast
            ? []
            : [
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFF0EA5A5)
                          : const Color(0xFF0D9488))
                      .withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance Total',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95)),
              ),
              if (data.alerts.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(highContrast ? 0.9 : 0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(Iconsax.danger,
                          size: 14,
                          color: highContrast ? Colors.red : Colors.white),
                      const SizedBox(width: 6),
                      Text(
                          '${data.alerts.length} Alerta${data.alerts.length > 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  highContrast ? Colors.black : Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: data.totalBalance),
            duration: 1500.ms,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                currencyFormat.format(value),
                style: GoogleFonts.poppins(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1.5),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Proyección fin de mes: ${currencyFormat.format(data.monthlyProjection)}',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _KpiPill(
                icon: Iconsax.wallet_2,
                label: 'Disponible',
                value: currencyFormat.format(data.totalBalance * 0.7),
                highContrast: highContrast,
              ),
              _KpiPill(
                icon: Iconsax.chart_1,
                label: 'Ahorro mes',
                value: currencyFormat.format(data.totalBalance * 0.15),
                highContrast: highContrast,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onSimulateTap,
            icon: const Icon(Iconsax.calculator, size: 20),
            label: const Text('Simular impacto'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0D9488),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highContrast;

  const _KpiPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highContrast
            ? Colors.white.withOpacity(0.9)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: highContrast ? Border.all(color: Colors.white, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16, color: highContrast ? Colors.black : Colors.white),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: highContrast
                      ? Colors.black54
                      : Colors.white.withOpacity(0.8),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: highContrast ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LIVE RECOMMENDATIONS FEED
// ============================================================================

class _LiveRecommendationsFeed extends StatefulWidget {
  final DashboardData data;
  final bool highContrast;

  const _LiveRecommendationsFeed({
    required this.data,
    required this.highContrast,
  });

  @override
  State<_LiveRecommendationsFeed> createState() =>
      _LiveRecommendationsFeedState();
}

class _LiveRecommendationsFeedState extends State<_LiveRecommendationsFeed> {
  bool _showUndoToast = false;
  String _lastAppliedRecommendation = '';

  void _applyRecommendation(String recommendation) {
    setState(() {
      _lastAppliedRecommendation = recommendation;
      _showUndoToast = true;
    });

    // Ocultar el toast después de 7 segundos
    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) {
        setState(() {
          _showUndoToast = false;
        });
      }
    });

    // Aquí iría la lógica real de aplicar la recomendación
    developer.log("✅ Aplicando recomendación: $recommendation",
        name: "Dashboard");
  }

  void _undoRecommendation() {
    setState(() {
      _showUndoToast = false;
    });
    developer.log("↩️ Deshaciendo recomendación: $_lastAppliedRecommendation",
        name: "Dashboard");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mock de recomendaciones basadas en datos
    final recommendations = _generateRecommendations(widget.data);

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              Icon(
                Iconsax.lamp_charge,
                size: 20,
                color: widget.highContrast
                    ? Colors.white
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Recomendaciones Inteligentes',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.highContrast ? Colors.white : null,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100, // Aumentado para que quepa bien el contenido
          child: PageView.builder(
            scrollDirection: Axis.horizontal,
            //padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recommendations.length,
            //separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              //return SizedBox(
              //width: 220, // <--- AJUSTA ESTE ANCHO
              //child: _RecommendationCard(
              //recommendation: rec,
              //onApply: () => _applyRecommendation(rec['title']!),
              //highContrast: widget.highContrast,
              //),
              //);
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20), // <-- PADDING LATERAL
                child: _RecommendationCard(
                  recommendation: rec,
                  onApply: () => _applyRecommendation(rec['title']!),
                  highContrast: widget.highContrast,
                ),
              );
            },
          ),
        ),
        if (_showUndoToast)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _UndoToast(
              message: 'Recomendación aplicada',
              onUndo: _undoRecommendation,
              highContrast: widget.highContrast,
            ),
          ),
      ],
    );
  }

  List<Map<String, String>> _generateRecommendations(DashboardData data) {
    final recommendations = <Map<String, String>>[];

    // Recomendación 1: Reducción de gasto
    if (data.featuredBudgets.isNotEmpty) {
      final budget = data.featuredBudgets.first;
      if (budget.amount > 0) {
        final percentUsed = (budget.spentAmount / budget.amount * 100).round();
        if (percentUsed > 70) {
          recommendations.add({
            'title': 'Reduce en ${budget.category}',
            'description':
                'Llevas $percentUsed% gastado. Reducir \$50.000 te ahorra \$600.000/año',
            'impact': 'Alto',
            'icon': 'chart_down',
          });
        }
      }
    }

    // Recomendación 2: Oportunidad de ahorro
    if (data.monthlyProjection > data.totalBalance * 0.8) {
      final projectedSavings = data.monthlyProjection - data.totalBalance * 0.8;
      recommendations.add({
        'title': 'Mueve a Ahorro',
        'description':
            'Proyectas un excedente de \$${NumberFormat.compact(locale: 'es_CO').format(projectedSavings)}. ¡Ahorra ahora!',
        'impact': 'Medio',
        'icon': 'security',
      });
    }

    // Recomendación 3: Alerta de presupuesto
    if (data.alerts.isNotEmpty) {
      recommendations.add({
        'title': 'Ajusta Presupuestos',
        'description':
            'Tienes ${data.alerts.length} alerta${data.alerts.length > 1 ? 's' : ''}. Revisa y optimiza tus límites.',
        'impact': 'Crítico',
        'icon': 'warning',
      });
    }

    if (recommendations.isEmpty) {
      recommendations.add({
        'title': '¡Vas muy bien!',
        'description':
            'Sigue así. No hemos encontrado alertas críticas en tus finanzas este mes.',
        'impact': 'Positivo',
        'icon': 'shield_tick',
      });
    }

    return recommendations;
  }
}

class _RecommendationCard extends StatelessWidget {
  final Map<String, String> recommendation;
  final VoidCallback onApply;
  final bool highContrast;

  const _RecommendationCard({
    required this.recommendation,
    required this.onApply,
    required this.highContrast,
  });

  Color _getImpactColor(String impact) {
    switch (impact) {
      case 'Crítico':
        return Colors.red;
      case 'Alto':
        return Colors.orange;
      case 'Medio':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'chart_down':
        return Iconsax.chart_21;
      case 'security':
        return Iconsax.security_safe;
      case 'warning':
        return Iconsax.warning_2;
      case 'shield_tick':
        return Iconsax.shield_tick;
      default:
        return Iconsax.lamp_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impactColor = _getImpactColor(recommendation['impact']!);

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highContrast
            ? Colors.black
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: highContrast
            ? Border.all(color: Colors.white, width: 2)
            : Border.all(color: impactColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: highContrast
                      ? Colors.white
                      : impactColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getIcon(recommendation['icon']!),
                  size: 20,
                  color: highContrast ? Colors.black : impactColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recommendation['title']!,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: highContrast ? Colors.white : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              recommendation['description']!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: highContrast
                    ? Colors.white70
                    : theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          if (recommendation['impact'] != 'Positivo')
            SizedBox(
              width: double.infinity,
              //child: FilledButton.tonal(
              //onPressed: onApply,
              //style: FilledButton.styleFrom(
              //backgroundColor: highContrast
              //  ? Colors.white
              //: impactColor.withOpacity(0.2),
              //foregroundColor: highContrast ? Colors.black : impactColor,
              //padding: const EdgeInsets.symmetric(vertical: 10),
              //shape: RoundedRectangleBorder(
              //borderRadius: BorderRadius.circular(12),
              //),
              //),
              //child: const Text('Aplicar',
              //  style:
              //    TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              //),
            ),
        ],
      ),
    );
  }
}

class _UndoToast extends StatelessWidget {
  final String message;
  final VoidCallback onUndo;
  final bool highContrast;

  const _UndoToast({
    required this.message,
    required this.onUndo,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highContrast ? Colors.black : theme.colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(16),
        border: highContrast ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.tick_circle,
            color: highContrast
                ? Colors.white
                : theme.colorScheme.onInverseSurface,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: highContrast
                    ? Colors.white
                    : theme.colorScheme.onInverseSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            child: Text(
              'DESHACER',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: highContrast
                    ? Colors.white
                    : theme.colorScheme.inversePrimary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.2);
  }
}

// ============================================================================
// QUICK ACTIONS
// ============================================================================

class _QuickActions extends StatelessWidget {
  final VoidCallback onSimulateTap;
  final VoidCallback onAddTap;
  final VoidCallback onGoalsTap;

  const _QuickActions({
    required this.onSimulateTap,
    required this.onAddTap,
    required this.onGoalsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _QuickActionButton(
              icon: Iconsax.calculator, label: 'Simular', onTap: onSimulateTap),
          const SizedBox(width: 12),
          _QuickActionButton(
              icon: Iconsax.add_circle, label: 'Agregar', onTap: onAddTap),
          const SizedBox(width: 12),
          _QuickActionButton(
              icon: Iconsax.flag, label: 'Metas', onTap: onGoalsTap),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(icon, size: 28, color: theme.colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BUDGETS CAROUSEL CON SIMULACIÓN
// ============================================================================

class _BudgetsCarousel extends StatelessWidget {
  final List<Budget> budgets;
  final bool highContrast;

  const _BudgetsCarousel({
    required this.budgets,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: highContrast
                ? Colors.black
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border:
                highContrast ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Row(
            children: [
              Icon(
                Iconsax.wallet_add,
                color: highContrast ? Colors.white : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Aún no tienes presupuestos. ¡Crea uno para empezar a controlar tu gasto!",
                  style: TextStyle(color: highContrast ? Colors.white : null),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tus Presupuestos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: highContrast ? Colors.white : null,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const BudgetsScreen())),
                child: const Text('Ver todos'),
              )
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _BudgetCard(budget: budgets[index], highContrast: highContrast),
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final bool highContrast;

  const _BudgetCard({
    required this.budget,
    required this.highContrast,
  });

  (Color, IconData) getStatusInfo(double progress) {
    if (progress >= 0.9) return (Colors.red, Iconsax.danger);
    if (progress >= 0.7) return (Colors.orange, Iconsax.warning_2);
    return (Colors.green, Iconsax.shield_tick);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat =
        NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$');
    final progress =
        (budget.amount > 0 ? budget.spentAmount / budget.amount : 0.0)
            .clamp(0.0, 1.0);
    final (statusColor, statusIcon) = getStatusInfo(progress);

    return SizedBox(
      width: 220,
      child: Material(
        color: highContrast
            ? Colors.black
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => BudgetDetailsScreen(budgetId: budget.id))),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: highContrast
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.folder_2,
                      size: 18,
                      color: highContrast
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        budget.category,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: highContrast ? Colors.white : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(statusIcon, color: statusColor, size: 18)
                  ],
                ),
                const Spacer(),
                Text(
                  '${currencyFormat.format(budget.spentAmount)} de ${currencyFormat.format(budget.amount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: highContrast
                        ? Colors.white70
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: highContrast
                        ? Colors.white24
                        : theme.colorScheme.surfaceContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% usado',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FINANCIAL HEALTH METER
// ============================================================================

class _FinancialHealthMeter extends StatelessWidget {
  final double score;
  final double progress;
  final bool highContrast;

  const _FinancialHealthMeter({
    required this.score,
    required this.progress,
    required this.highContrast,
  });

  (Color, String, String) getHealthStatus(double score) {
    if (score >= 80) return (Colors.green, 'Excelente', '😊');
    if (score >= 60) return (Colors.blue, 'Bueno', '👍');
    if (score >= 40) return (Colors.orange, 'Regular', '⚠️');
    return (Colors.red, 'Peligro', '🚨');
  }

  @override
  Widget build(BuildContext context) {
    final (color, label, emoji) = getHealthStatus(score);
    final textStyle = GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: highContrast ? Colors.white : color);

    return Opacity(
      opacity: (progress * 2 - 0.5).clamp(0, 1),
      child: Transform.scale(
        scale: progress.clamp(0.8, 1.0),
        child: Tooltip(
          message: 'Salud Financiera: $label ($score/100)',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: highContrast ? Colors.black : color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: highContrast ? Colors.white : color.withOpacity(0.5),
                width: highContrast ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircularScoreIndicator(
                    score: score, color: highContrast ? Colors.white : color),
                const SizedBox(width: 8),
                Text(label, style: textStyle),
                const SizedBox(width: 4),
                Text(emoji, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularScoreIndicator extends StatelessWidget {
  final double score;
  final Color color;
  const _CircularScoreIndicator({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 3,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '${score.toInt()}',
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// PANTALLA COMPLETA DE ANÁLISIS IA CON BEFORE/AFTER
// ============================================================================

class _AiAnalysisFullScreen extends StatefulWidget {
  final DashboardData dashboardData;

  const _AiAnalysisFullScreen({required this.dashboardData});

  @override
  State<_AiAnalysisFullScreen> createState() => _AiAnalysisFullScreenState();
}

class _AiAnalysisFullScreenState extends State<_AiAnalysisFullScreen> {
  double _simulatedExpenseChange = 0;
  double _simulatedSavingsChange = 0;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSliderChange(double value, String type) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        if (type == 'expense') {
          _simulatedExpenseChange = value;
        } else {
          _simulatedSavingsChange = value;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    // Cálculos before/after
    final currentBalance = widget.dashboardData.totalBalance;
    final currentProjection = widget.dashboardData.monthlyProjection;

    final newBalance =
        currentBalance - _simulatedExpenseChange + _simulatedSavingsChange;
    final newProjection =
        currentProjection - _simulatedExpenseChange + _simulatedSavingsChange;

    final balanceDiff = newBalance - currentBalance;
    final projectionDiff = newProjection - currentProjection;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0EA5A5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Iconsax.magic_star, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Análisis IA'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumen en 3 bullets
            _AiSummaryCard(
              healthScore: widget.dashboardData.healthScore,
              alertsCount: widget.dashboardData.alerts.length,
            ),

            const SizedBox(height: 24),

            // Controles de simulación
            Text(
              'Simula cambios en tus finanzas',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _SimulationSlider(
              label: 'Reducir gastos mensuales',
              value: _simulatedExpenseChange,
              max: 500000,
              onChanged: (v) => _onSliderChange(v, 'expense'),
              icon: Iconsax.arrow_down_1,
              color: Colors.red.shade400,
            ),

            const SizedBox(height: 16),

            _SimulationSlider(
              label: 'Aumentar ahorro mensual',
              value: _simulatedSavingsChange,
              max: 300000,
              onChanged: (v) => _onSliderChange(v, 'savings'),
              icon: Iconsax.arrow_up_1,
              color: Colors.green.shade400,
            ),

            const SizedBox(height: 32),

            // Before/After Comparison
            Text(
              'Impacto en tus finanzas',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _BeforeAfterComparison(
              title: 'Balance Total',
              beforeValue: currencyFormat.format(currentBalance),
              afterValue: currencyFormat.format(newBalance),
              difference: currencyFormat.format(balanceDiff),
              isPositive: balanceDiff >= 0,
            ),

            const SizedBox(height: 12),

            _BeforeAfterComparison(
              title: 'Proyección fin de mes',
              beforeValue: currencyFormat.format(currentProjection),
              afterValue: currencyFormat.format(newProjection),
              difference: currencyFormat.format(projectionDiff),
              isPositive: projectionDiff >= 0,
            ),

            const SizedBox(height: 32),

            // CTA para aplicar cambios
            if (_simulatedExpenseChange > 0 || _simulatedSavingsChange > 0)
              FilledButton.icon(
                onPressed: () {
                  // Aquí iría la lógica para aplicar los cambios
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cambios aplicados exitosamente'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Iconsax.tick_circle),
                label: const Text('Aplicar cambios sugeridos'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AiSummaryCard extends StatelessWidget {
  final double healthScore;
  final int alertsCount;

  const _AiSummaryCard({
    required this.healthScore,
    required this.alertsCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.chart, color: theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Text(
                'Resumen Inteligente',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _BulletPoint(
            icon: Iconsax.health,
            text: 'Tu salud financiera está en ${healthScore.toInt()}/100.',
          ),
          _BulletPoint(
            icon: alertsCount > 0 ? Iconsax.danger : Iconsax.shield_tick,
            text: alertsCount > 0
                ? 'Tienes $alertsCount alerta${alertsCount > 1 ? 's' : ''} que requieren atención.'
                : 'No tienes alertas críticas este mes. ¡Excelente!',
          ),
          _BulletPoint(
            icon: Iconsax.lamp_on,
            text: 'Reducir gastos en \$100.000/mes te ahorra \$1.2M al año.',
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BulletPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulationSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final IconData icon;
  final Color color;

  const _SimulationSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                currencyFormat.format(value),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            max: max,
            divisions: 20,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterComparison extends StatelessWidget {
  final String title;
  final String beforeValue;
  final String afterValue;
  final String difference;
  final bool isPositive;

  const _BeforeAfterComparison({
    required this.title,
    required this.beforeValue,
    required this.afterValue,
    required this.difference,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positiveColor = Colors.green.shade400;
    final negativeColor = Colors.red.shade400;
    final displayColor = isPositive ? positiveColor : negativeColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título del indicador
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Fila de comparación
          Row(
            children: [
              // Columna "Antes"
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antes',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      beforeValue,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // Icono de flecha
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Iconsax.arrow_right_3,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              // Columna "Después"
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Después',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      afterValue,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: displayColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chip con la diferencia
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: displayColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Iconsax.arrow_up_2 : Iconsax.arrow_down_2,
                    size: 16,
                    color: displayColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${difference.contains('-') ? "" : "+"}$difference',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: displayColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2);
  }
}
