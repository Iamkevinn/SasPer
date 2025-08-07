// lib/screens/dashboard_screen.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/main.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Pantallas
import 'edit_transaction_screen.dart';
import 'transactions_screen.dart';

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
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  final WidgetService _widgetService = WidgetService();

  // --- GESTIÓN DE STREAMS Y ESTADO ---
  late final Stream<DashboardData> _dashboardDataStream;
  StreamSubscription<DashboardData>? _widgetUpdateSubscription;
  Timer? _widgetUpdateDebounce;

  // --- ARQUITECTURA DE DATOS ---
  // La lógica de esta pantalla se divide en dos partes:
  // 1. EL STREAM DE LA UI: `_dashboardDataStream` alimenta el `StreamBuilder` para construir la pantalla
  //    de forma reactiva, mostrando un esqueleto de carga (`Skeletonizer`) mientras los datos llegan.
  // 2. LA CARGA ASÍNCRONA DE WIDGETS: Las funciones en `_updateAllBackgroundWidgets` se ejecutan en
  //    segundo plano (`fire-and-forget`) sin bloquear la UI, asegurando que la app inicie instantáneamente.

  @override
  void initState() {
    super.initState();
    developer.log("✅ [Dashboard] initState: Configurando streams y carga inicial...", name: "Dashboard");

    // 1. Inicializa el stream que alimenta la UI principal.
    _dashboardDataStream = _dashboardRepository.getDashboardDataStream();

    // 2. Escucha los cambios en los datos para actualizar los widgets grandes (con debounce).
    _listenForWidgetUpdates();

    // 3. Pide la primera carga de datos para la UI. silent:true evita mostrar un spinner innecesario.
    _dashboardRepository.forceRefresh(silent: true);
    
    // 4. Lanza la actualización de TODOS los widgets en segundo plano. NO se usa 'await'.
    _updateAllBackgroundWidgets();
  }

  @override
  void dispose() {
    _widgetUpdateSubscription?.cancel();
    _widgetUpdateDebounce?.cancel();
    super.dispose();
  }

  // --- LÓGICA DE CARGA Y ACTUALIZACIÓN ---

  /// Lanza la actualización de todos los widgets de la pantalla de inicio en paralelo.
  /// Se ejecuta en segundo plano sin bloquear la UI.
  Future<void> _updateAllBackgroundWidgets() async {
    try {
      developer.log("🚀 [Background] Iniciando actualización de TODOS los widgets...", name: "Dashboard");
      // Future.wait ejecuta todas las llamadas en paralelo para máxima eficiencia.
      await Future.wait([
        WidgetService.updateFinancialHealthWidget(),
        WidgetService.updateMonthlyComparisonWidget(),
        WidgetService.updateGoalsWidget(), // Si el método es estático, se llama así
        WidgetService.updateUpcomingPaymentsWidget(),
        WidgetService.updateNextPaymentWidget(),
      ]);
      developer.log("✅ [Background] Actualización de widgets completada.", name: "Dashboard");
    } catch (e, stackTrace) {
      developer.log("🔥🔥🔥 [Background] Error fatal al actualizar widgets: $e", name: "Dashboard", error: e, stackTrace: stackTrace);
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
          developer.log("🔄 [Debounce] Actualizando widgets dependientes de datos (Medio/Grande)...", name: "Dashboard");
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          backgroundColor: Theme.of(dialogContext).colorScheme.surface.withOpacity(0.9),
          title: const Text('Confirmar Acción'),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onErrorContainer),
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
        if (mounted) NotificationHelper.show(message: 'Transacción eliminada.', type: NotificationType.success);
        return true;
      } catch (e) {
        if (mounted) NotificationHelper.show(message: 'Error al eliminar.', type: NotificationType.error);
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
              return Center(child: Text('Error al cargar los datos: ${snapshot.error}'));
            }
            
            // Determina si estamos en estado de carga.
            // Es `true` si no hay datos AÚN, o si los datos que hay tienen la bandera `isLoading`.
            final isLoading = !snapshot.hasData || snapshot.data!.isLoading;
            
            // Usa datos vacíos para el esqueleto o los datos reales si ya llegaron.
            final data = isLoading ? DashboardData.empty() : snapshot.data!;

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
        // Deshabilita el scroll mientras la UI es un esqueleto.
        physics: data.isLoading ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            titleSpacing: 16.0,
            title: DashboardHeader(userName: data.fullName),
            toolbarHeight: 80,
          ),
          SliverToBoxAdapter(child: BalanceCard(totalBalance: data.totalBalance)),
          SliverToBoxAdapter(child: BudgetsSection(budgets: data.featuredBudgets)),
          
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: AiAnalysisSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          SliverToBoxAdapter(
            child: RecentTransactionsSection(
              transactions: data.recentTransactions,
              onTransactionTapped: _handleTransactionTap,
              onTransactionDeleted: _handleTransactionDelete,
              onViewAllPressed: _navigateToTransactionsScreen,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }
}