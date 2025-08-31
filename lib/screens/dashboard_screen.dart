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
//import 'package:sasper/services/event_service.dart';
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
import 'package:sasper/widgets/dashboard/recent_transactions_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  // --- DEPENDENCIAS (SINGLETONS) ---
  final DashboardRepository _dashboardRepository = DashboardRepository.instance;
  final TransactionRepository _transactionRepository =
      TransactionRepository.instance;
  final WidgetService _widgetService = WidgetService();

  // --- GESTIÓN DE STREAMS Y ESTADO ---
  late final Stream<DashboardData> _dashboardDataStream;
  StreamSubscription<DashboardData>? _widgetUpdateSubscription;
  Timer? _widgetUpdateDebounce;

  // --- CAMBIO 1: Añadimos una bandera para controlar la celebración ---
  //final bool _hasCheckedForCelebrations = false;

  // Bandera para asegurar que la celebración solo se muestre una vez por sesión.
  bool _hasShownCelebration = false;

  // --- ARQUITECTURA DE DATOS ---
  // La lógica de esta pantalla se divide en dos partes:
  // 1. EL STREAM DE LA UI: `_dashboardDataStream` alimenta el `StreamBuilder` para construir la pantalla
  //    de forma reactiva, mostrando un esqueleto de carga (`Skeletonizer`) mientras los datos llegan.
  // 2. LA CARGA ASÍNCRONA DE WIDGETS: Las funciones en `_updateAllBackgroundWidgets` se ejecutan en
  //    segundo plano (`fire-and-forget`) sin bloquear la UI, asegurando que la app inicie instantáneamente.

  @override
  void initState() {
    super.initState();
    developer.log(
        "✅ [Dashboard] initState: Configurando streams y carga inicial...",
        name: "Dashboard");

    // 1. Inicializa el stream que alimenta la UI principal.
    _dashboardDataStream = _dashboardRepository.getDashboardDataStream();

    // 2. Escucha los cambios en los datos para actualizar los widgets grandes (con debounce).
    _listenForWidgetUpdates();

    // 3. Pide la primera carga de datos para la UI. silent:true evita mostrar un spinner innecesario.
    _dashboardRepository.forceRefresh(silent: true);

    // 4. Lanza la actualización de TODOS los widgets en segundo plano. NO se usa 'await'.
    _updateAllBackgroundWidgets();

    //_checkChallenges();

    // --- CAMBIO 2: Eliminamos la llamada a la celebración desde aquí ---
    // La lógica de `_checkChallenges` para actualizar el estado está bien aquí,
    // pero la de MOSTRAR el diálogo debe moverse.
  }

  @override
  void dispose() {
    _widgetUpdateSubscription?.cancel();
    _widgetUpdateDebounce?.cancel();
    super.dispose();
  }

  /// Comprueba si hay retos recién completados y muestra un diálogo de celebración.
  Future<void> _checkAndShowCelebrations() async {
    try {
      final newlyCompleted =
          await ChallengeRepository.instance.checkUserChallengesStatus();

      for (var challenge in newlyCompleted) {
        // 'mounted' comprueba si el widget todavía está en el árbol de widgets.
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

  //Future<void> _checkChallengesAndShowCelebration() async {
  //  try {
  //    final newlyCompleted = await ChallengeRepository.instance.checkUserChallengesStatus();
  //
  //    // Si hay retos recién completados, mostramos una celebración por cada uno
  //    for (var challenge in newlyCompleted) {
  //      if (mounted) {
  //        showDialog(
  //          context: context,
  //          builder: (context) => _buildCelebrationDialog(challenge),
  //        );
  //      }
  //    }
  //  } catch (e) {
  //    if (kDebugMode) {
  //      print("Error al chequear retos para celebración: $e");
  //    }
  //  }
  //}

  Widget _buildCelebrationDialog(UserChallenge userChallenge) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Asume que tienes una animación de celebración. ¡Busca una en LottieFiles!
          Lottie.asset('assets/animations/confetti_celebration.json',
              height: 150),
          const SizedBox(height: 16),
          Text(
            '¡Reto Completado!',
            style:
                GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
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

  //uture<void> _checkChallenges() async {
  // // Sin esperar, para no bloquear la UI
  // try {
  //   await ChallengeRepository.instance.checkUserChallengesStatus();
  // } catch (e) {
  //   if (kDebugMode) {
  //     print("Error al chequear retos: $e");
  //   }
  // }
  //
  // --- LÓGICA DE CARGA Y ACTUALIZACIÓN ---

  /// Lanza la actualización de todos los widgets de la pantalla de inicio en paralelo.
  /// Se ejecuta en segundo plano sin bloquear la UI.
  Future<void> _updateAllBackgroundWidgets() async {
    try {
      developer.log(
          "🚀 [Background] Iniciando actualización de TODOS los widgets...",
          name: "Dashboard");
      // Future.wait ejecuta todas las llamadas en paralelo para máxima eficiencia.
      await Future.wait([
        WidgetService.updateFinancialHealthWidget(),
        WidgetService.updateMonthlyComparisonWidget(),
        WidgetService
            .updateGoalsWidget(), // Si el método es estático, se llama así
        WidgetService.updateUpcomingPaymentsWidget(),
        WidgetService.updateNextPaymentWidget(),
      ]);
      developer.log("✅ [Background] Actualización de widgets completada.",
          name: "Dashboard");
    } catch (e, stackTrace) {
      developer.log("🔥🔥🔥 [Background] Error fatal al actualizar widgets: $e",
          name: "Dashboard", error: e, stackTrace: stackTrace);
    }
  }

  /// Escucha el stream de datos principal y actualiza los widgets que dependen de él.
  /// Usa un "debounce" para no actualizar los widgets en cada micro-cambio.
  void _listenForWidgetUpdates() {
    _widgetUpdateSubscription = _dashboardDataStream.listen((data) {
      // Solo actualiza si los datos no están en estado de carga.
      if (!data.isLoading) {
        _widgetUpdateDebounce?.cancel();
        _widgetUpdateDebounce = Timer(const Duration(seconds: 2), () {
          developer.log(
              "🔄 [Debounce] Actualizando widgets dependientes de datos (Medio/Grande)...",
              name: "Dashboard");
          // El widget grande que muestra el gráfico y presupuestos sí necesita los datos.
          _widgetService.updateAllWidgets(data, context);
        });
      }
    });
  }

  /// Maneja la acción de "deslizar para refrescar".
  Future<void> _handleRefresh() async {
    await _dashboardRepository.forceRefresh(silent: false);
    // También podemos aprovechar para refrescar los widgets de segundo plano.
    await _updateAllBackgroundWidgets();
  }

  // --- NAVEGACIÓN Y ACCIONES DEL USUARIO ---
  // ¡NUEVO MÉTODO!
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
    // El evento de actualización de la transacción ya se maneja por el stream, no se necesita lógica extra.
  }

  Future<bool> _handleTransactionDelete(Transaction transaction) async {
    final bool? confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
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
        if (mounted)
          NotificationHelper.show(
              message: 'Transacción eliminada.',
              type: NotificationType.success);
        return true;
      } catch (e) {
        if (mounted)
          NotificationHelper.show(
              message: 'Error al eliminar.', type: NotificationType.error);
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
            // Caso de error en el stream
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error al cargar los datos: ${snapshot.error}'));
            }

            // Determina si estamos en estado de carga.
            // Es `true` si no hay datos AÚN, o si los datos que hay tienen la bandera `isLoading`.
            final isLoading = !snapshot.hasData || snapshot.data!.isLoading;

            // Usa datos vacíos para el esqueleto o los datos reales si ya llegaron.
            final data = isLoading ? DashboardData.empty() : snapshot.data!;

            // --- ¡LÓGICA DE CELEBRACIÓN REACTIVADA Y SEGURA! ---
            // Si la carga principal del dashboard ha terminado Y aún no hemos mostrado la celebración...
            if (!isLoading && !_hasShownCelebration) {
              // 1. Marcamos la bandera para que esto no se vuelva a ejecutar en esta sesión.
              _hasShownCelebration = true;
              // 2. Usamos un post-frame callback para ejecutar nuestra función DESPUÉS de que la UI se haya pintado.
              //    Esto evita cualquier conflicto de renderizado.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkAndShowCelebrations();
              });
            }

            // Skeletonizer muestra una UI "fantasma" mientras isLoading es true.
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
        physics: data.isLoading
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor:
                Theme.of(context).scaffoldBackgroundColor.withAlpha(240),
            elevation: 0,
            titleSpacing: 16.0,
            title: DashboardHeader(userName: data.fullName),
            toolbarHeight: 80,
            // --- ¡AQUÍ ESTÁ LA MODIFICACIÓN! ---
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: FilledButton.tonalIcon(
                  onPressed: _navigateToCanIAffordIt,
                  icon: const Icon(Iconsax.calculator, size: 18),
                  label: const Text('Simular'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            // --- FIN DE LA MODIFICACIÓN ---
          ),

          SliverToBoxAdapter(
              child: BalanceCard(totalBalance: data.totalBalance)),
          SliverToBoxAdapter(
              child: BudgetsSection(budgets: data.featuredBudgets)),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: AiAnalysisSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(
            child: ActiveChallengesWidget(),
          ),

          // Reemplazamos la sección de transacciones por nuestro nuevo gráfico.
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: CategorySpendingChart(
              spendingData: data.categorySpendingSummary,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }
}
