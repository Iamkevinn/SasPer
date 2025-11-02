// lib/screens/dashboard_screen.dart
// VERSIÓN REDISEÑADA - PREMIUM, MODERNA Y ASPIRACIONAL

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

  @override
  void initState() {
    super.initState();
    developer.log(
        "✅ [DashboardV2] initState: Configurando streams y carga inicial...",
        name: "Dashboard");

    _dashboardDataStream = _dashboardRepository.getDashboardDataStream();
    _dashboardRepository.forceRefresh(silent: true);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await _dashboardRepository.forceRefresh(silent: false);
  }

  void _navigateToAiAnalysisScreen() =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => const AiFinancialAnalysisScreen()));
  void _navigateToCanIAffordIt() => Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CanIAffordItScreen()));
  void _navigateToTransactionsScreen() => Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TransactionsScreen()));
  void _navigateToGoalsScreen() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (context) => const GoalsScreen()));

  Future<void> _checkAndShowCelebrations(DashboardData data) async {
    // Solo ejecutamos esto una vez por carga para evitar múltiples pop-ups.
    if (_hasShownCelebration) return;
    _hasShownCelebration = true;

    try {
      // 1. Llama al repositorio para obtener los retos recién completados.
      final newlyCompleted =
          await ChallengeRepository.instance.checkUserChallengesStatus();

      // Si no hay nada nuevo, no hacemos nada.
      if (newlyCompleted.isEmpty || !mounted) {
        return;
      }

      // 2. Itera sobre cada reto completado y muestra un diálogo.
      for (var userChallenge in newlyCompleted) {
        // Usamos un pequeño delay entre cada diálogo si hay más de uno.
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false, // El usuario debe cerrarlo activamente
            builder: (context) => _buildCelebrationDialog(userChallenge),
          );
        }
      }
    } catch (e) {
      developer.log("🔥 Error al chequear retos para celebración: $e",
          name: "Dashboard");
    }
  }

  /// Construye el widget del diálogo de celebración.
  Widget _buildCelebrationDialog(UserChallenge userChallenge) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animación Lottie
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

            // --- CÓDIGO VERIFICADO Y CORRECTO ---
            // Accedemos a las propiedades a través de 'challengeDetails'.
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
              _hasShownCelebration = true;
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
              pulseAnimation: _pulseAnimation,
              onAiTap: _navigateToAiAnalysisScreen,
              minExtent: 110,
              maxExtent: 140,
            ),
          ),
          SliverToBoxAdapter(
            child: _BalanceHeroCard(
              data: data,
              onSimulateTap: () {},
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          ),
          SliverToBoxAdapter(
            child: _QuickActions(
              onSimulateTap: _navigateToCanIAffordIt,
              onAddTap: _navigateToTransactionsScreen,
              onGoalsTap: _navigateToGoalsScreen,
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          ),
          SliverToBoxAdapter(
            child: _BudgetsCarousel(
              budgets: data.featuredBudgets,
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
          ),
          SliverToBoxAdapter(
            child: const ActiveChallengesWidget()
                .animate()
                .fadeIn(delay: 500.ms)
                .slideY(begin: 0.2),
          ),
          SliverToBoxAdapter(
            child: CategorySpendingChart(
              spendingData: data.categorySpendingSummary,
            ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _PremiumHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DashboardData data;
  final Animation<double> pulseAnimation;
  final VoidCallback onAiTap;
  @override
  final double minExtent;
  @override
  final double maxExtent;

  _PremiumHeaderDelegate({
    required this.data,
    required this.pulseAnimation,
    required this.onAiTap,
    required this.minExtent,
    required this.maxExtent,
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
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 10),
          color: theme.scaffoldBackgroundColor.withOpacity(0.85),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hola, ${data.fullName.split(' ').first} 👋',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tu Central Financiera',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _FinancialHealthMeter(
                    score: data.healthScore,
                    progress: progress,
                  ),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: pulseAnimation.value,
                        child: IconButton(
                          onPressed: onAiTap,
                          icon: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF0D9488),
                                  Color(0xFF0EA5A5)
                                ]),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0D9488)
                                        .withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]),
                            child: const Icon(Iconsax.magic_star,
                                color: Colors.white),
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
        onAiTap != oldDelegate.onAiTap;
  }
}

class _BalanceHeroCard extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onSimulateTap;

  const _BalanceHeroCard({required this.data, required this.onSimulateTap});

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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D9488), const Color(0xFF0EA5A5)]
              : [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF0EA5A5) : const Color(0xFF0D9488))
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
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9)),
              ),
              if (data.alerts.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(Iconsax.danger, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                          '${data.alerts.length} Alerta${data.alerts.length > 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: data.totalBalance),
            duration: 1500.ms,
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                currencyFormat.format(value),
                style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1.5),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Proyección fin de mes: ${currencyFormat.format(data.monthlyProjection)}',
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.white.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

class _BudgetsCarousel extends StatelessWidget {
  final List<Budget> budgets;
  const _BudgetsCarousel({required this.budgets});

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24)),
          child: const Row(children: [
            Icon(Iconsax.wallet_add),
            SizedBox(width: 16),
            Expanded(
                child: Text(
                    "Aún no tienes presupuestos. ¡Crea uno para empezar a controlar tu gasto!")),
          ]),
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
              Text('Tus Presupuestos',
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const BudgetsScreen())),
                child: const Text('Ver todos'),
              )
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _BudgetCard(budget: budgets[index]),
          ),
        ),
      ],
    );
  }
}

class _FinancialHealthMeter extends StatelessWidget {
  final double score;
  final double progress;

  const _FinancialHealthMeter({required this.score, required this.progress});

  (Color, String) getHealthStatus(double score) {
    if (score >= 80) return (Colors.green, 'Excelente');
    if (score >= 60) return (Colors.blue, 'Bueno');
    if (score >= 40) return (Colors.orange, 'Regular');
    return (Colors.red, 'Peligro');
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = getHealthStatus(score);
    final textStyle = GoogleFonts.poppins(
        fontSize: 12, fontWeight: FontWeight.bold, color: color);

    return Opacity(
      opacity: (progress * 2 - 0.5).clamp(0, 1),
      child: Transform.scale(
        scale: progress.clamp(0.8, 1.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(0.5))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CircularScoreIndicator(score: score, color: color),
              const SizedBox(width: 8),
              Text(label, style: textStyle),
            ],
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
      width: 20,
      height: 20,
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

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  const _BudgetCard({required this.budget});

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
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => BudgetDetailsScreen(budgetId: budget.id))),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.folder_2,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        budget.category,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
                      fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
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
