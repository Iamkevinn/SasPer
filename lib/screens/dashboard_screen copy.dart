// lib/screens/dashboard_screen.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/main.dart';
import 'package:sasper/widgets/dashboard/active_challenges_widget.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Pantallas
import 'edit_transaction_screen.dart';
import 'transactions_screen.dart';
import 'package:sasper/screens/can_i_afford_it_screen.dart';
import 'package:sasper/widgets/dashboard/category_spending_chart.dart';

// Widgets
import 'package:sasper/widgets/dashboard/ai_analysis_section.dart';
import 'package:sasper/widgets/dashboard/balance_card.dart';
import 'package:sasper/widgets/dashboard/budgets_section.dart';
import 'package:sasper/widgets/dashboard/dashboard_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> 
    with SingleTickerProviderStateMixin {
  // --- DEPENDENCIAS (SINGLETONS) ---
  final DashboardRepository _dashboardRepository = DashboardRepository.instance;
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  final WidgetService _widgetService = WidgetService();

  // --- GESTIÓN DE STREAMS Y ESTADO ---
  late final Stream<DashboardData> _dashboardDataStream;
  StreamSubscription<DashboardData>? _widgetUpdateSubscription;
  Timer? _widgetUpdateDebounce;

  // --- ANIMACIÓN PARA EL BOTÓN DE IA ---
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Bandera para celebración de retos
  bool _hasShownCelebration = false;

  @override
  void initState() {
    super.initState();
    developer.log(
        "✅ [Dashboard] initState: Configurando streams y carga inicial...",
        name: "Dashboard");

    // 1. Inicializa el stream que alimenta la UI principal
    _dashboardDataStream = _dashboardRepository.getDashboardDataStream();

    // 2. Escucha los cambios en los datos para actualizar los widgets
    _listenForWidgetUpdates();

    // 3. Primera carga de datos
    _dashboardRepository.forceRefresh(silent: true);

    // 4. Actualiza widgets en segundo plano
    _updateAllBackgroundWidgets();

    // 5. Inicializa la animación del pulso para el botón IA
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _widgetUpdateSubscription?.cancel();
    _widgetUpdateDebounce?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Comprueba si hay retos recién completados y muestra un diálogo de celebración
  Future<void> _checkAndShowCelebrations() async {
    try {
      final newlyCompleted =
          await ChallengeRepository.instance.checkUserChallengesStatus();

      for (var challenge in newlyCompleted) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => _buildCelebrationDialog(challenge),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error al chequear retos para celebración: $e");
      }
    }
  }

  Widget _buildCelebrationDialog(UserChallenge userChallenge) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset('assets/animations/confetti_celebration.json',
              height: 150),
          const SizedBox(height: 16),
          Text(
            '¡Reto Completado!',
            style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            userChallenge.challengeDetails.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Chip(
            label: Text('+${userChallenge.challengeDetails.rewardXp} XP',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.amber.shade200,
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE CARGA Y ACTUALIZACIÓN ---

  Future<void> _updateAllBackgroundWidgets() async {
    try {
      developer.log(
          "🚀 [Background] Iniciando actualización de TODOS los widgets...",
          name: "Dashboard");
      await Future.wait([
        WidgetService.updateFinancialHealthWidget(),
        WidgetService.updateMonthlyComparisonWidget(),
        WidgetService.updateGoalsWidget(),
        WidgetService.updateUpcomingPaymentsWidget(),
        WidgetService.updateNextPaymentWidget(),
      ]);
      developer.log("✅ [Background] Actualización de widgets completada.",
          name: "Dashboard");
    } catch (e, stackTrace) {
      developer.log("🔥 [Background] Error fatal al actualizar widgets: $e",
          name: "Dashboard", error: e, stackTrace: stackTrace);
    }
  }

  void _listenForWidgetUpdates() {
    _widgetUpdateSubscription = _dashboardDataStream.listen((data) {
      if (!data.isLoading) {
        _widgetUpdateDebounce?.cancel();
        _widgetUpdateDebounce = Timer(const Duration(seconds: 2), () {
          developer.log(
              "🔄 [Debounce] Actualizando widgets dependientes de datos...",
              name: "Dashboard");
          _widgetService.updateAllWidgets(data, context);
        });
      }
    });
  }

  Future<void> _handleRefresh() async {
    await _dashboardRepository.forceRefresh(silent: false);
    await _updateAllBackgroundWidgets();
  }

  // --- NAVEGACIÓN ---

  void _navigateToCanIAffordIt() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CanIAffordItScreen()),
    );
  }

  void _navigateToTransactionsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TransactionsScreen()),
    );
  }

  void _handleTransactionTap(Transaction transaction) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );
  }

  Future<bool> _handleTransactionDelete(Transaction transaction) async {
    final bool? confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.0)),
          backgroundColor:
              Theme.of(dialogContext).colorScheme.surface.withOpacity(0.9),
          title: const Text('Confirmar Acción'),
          content:
              const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(dialogContext).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(dialogContext).colorScheme.onErrorContainer),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _transactionRepository.deleteTransaction(transaction.id);
        if (mounted) {
          NotificationHelper.show(
              message: 'Transacción eliminada.',
              type: NotificationType.success);
        }
        return true;
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
              message: 'Error al eliminar.', type: NotificationType.error);
        }
        return false;
      }
    }
    return false;
  }

  // --- CONSTRUCCIÓN DE LA UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: StreamBuilder<DashboardData>(
          stream: _dashboardDataStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error al cargar los datos: ${snapshot.error}'));
            }

            final isLoading = !snapshot.hasData || snapshot.data!.isLoading;
            final data = isLoading ? DashboardData.empty() : snapshot.data!;

            // Lógica de celebración
            if (!isLoading && !_hasShownCelebration) {
              _hasShownCelebration = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkAndShowCelebrations();
              });
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        physics: data.isLoading
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        slivers: [
          // HEADER PREMIUM CON IA
          _buildPremiumHeader(colorScheme, isDark, data),

          // BALANCE CARD (TU WIDGET EXISTENTE)
          SliverToBoxAdapter(
            child: BalanceCard(totalBalance: data.totalBalance),
          ),

          // QUICK ACTIONS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: _buildQuickActions(colorScheme, isDark),
            ),
          ),

          // BUDGETS SECTION (TU WIDGET EXISTENTE)
          SliverToBoxAdapter(
            child: BudgetsSection(budgets: data.featuredBudgets),
          ),

          // AI ANALYSIS (TU WIDGET EXISTENTE)
          const SliverToBoxAdapter(
            child: AiAnalysisSection(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ACTIVE CHALLENGES (TU WIDGET EXISTENTE)
          const SliverToBoxAdapter(
            child: ActiveChallengesWidget(),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // CATEGORY SPENDING CHART (TU WIDGET EXISTENTE)
          SliverToBoxAdapter(
            child: CategorySpendingChart(
              spendingData: data.categorySpendingSummary,
            ),
          ),

          // BOTTOM SPACING PARA NAVIGATION BAR
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ==================== HEADER PREMIUM ====================
  Widget _buildPremiumHeader(
      ColorScheme colorScheme, bool isDark, DashboardData data) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: colorScheme.surface.withOpacity(0.95),
      toolbarHeight: 80,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: DashboardHeader(userName: data.fullName),
      actions: [
        // AI Button con animación de pulso
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () {
                    // Navegar a análisis IA o mostrar insights
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.tertiary],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Iconsax.magic_star,
                      size: 20,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Botón de simulación
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: FilledButton.tonalIcon(
            onPressed: _navigateToCanIAffordIt,
            icon: const Icon(Iconsax.calculator, size: 18),
            label: const Text('Simular'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== QUICK ACTIONS ====================
  Widget _buildQuickActions(ColorScheme colorScheme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            colorScheme,
            Iconsax.calculator,
            'Simular',
            _navigateToCanIAffordIt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionButton(
            colorScheme,
            Iconsax.add_circle,
            'Agregar',
            _navigateToTransactionsScreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionButton(
            colorScheme,
            Iconsax.chart_21,
            'Análisis',
            () {
              // Navegar a análisis detallado
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    ColorScheme colorScheme,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 24, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}