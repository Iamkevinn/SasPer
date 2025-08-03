// lib/screens/dashboard_screen.dart (VERSIÓN FINAL REFACtoRIZADA CON SINGLETONS)

import 'dart:async';
//import 'dart:developer' as developer;
//import 'dart:io';
import 'dart:ui';
//import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:home_widget/home_widget.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/screens/edit_transaction_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/widgets/dashboard/ai_analysis_section.dart';
import 'package:sasper/widgets/dashboard/balance_card.dart';
import 'package:sasper/widgets/dashboard/budgets_section.dart';
import 'package:sasper/widgets/dashboard/dashboard_header.dart';
import 'package:sasper/widgets/dashboard/recent_transactions_section.dart';
import 'package:sasper/main.dart';

class DashboardScreen extends StatefulWidget {
  // Solo necesita recibir los repositorios que AÚN NO son Singletons.
  // Una vez que todos lo sean, es posible que no necesite recibir ninguno.
  //final DashboardRepository repository;

  const DashboardScreen({
    super.key,
    //required this.repository,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  // Obtenemos las instancias Singleton de los repositorios que necesitamos.
  final DashboardRepository _dashboardRepository = DashboardRepository.instance;
  final TransactionRepository _transactionRepository = TransactionRepository.instance;

  late final Stream<DashboardData> _dashboardDataStream;
  StreamSubscription<AppEvent>? _eventSubscription; // Hacemos que la suscripción sea opcional
  Timer? _widgetUpdateTimer;
  
  //get widgetService => null;

  @override
  void initState() {
    super.initState();
    // Obtenemos el stream directamente del Singleton.
    _dashboardDataStream = _dashboardRepository.getDashboardDataStream();

    // La suscripción a EventService ya no es necesaria aquí, porque
    // MainScreen ya se encarga de llamar a forceRefresh en el Singleton,
    // y este widget escuchará los cambios a través del Stream del repositorio.
    // Esto evita duplicar la lógica de refresh.
    // Si aún quisieras mantenerla, no haría daño, pero es redundante.
    // _eventSubscription = EventService.instance.eventStream.listen(...);
  }

  // --- REVERSIÓN A LA SOLUCIÓN ESTABLE ---
  // Revertimos la lógica de actualización del widget para que no use 'compute'
  // y se ejecute en el hilo principal, ya que era la causa del bloqueo.
  void _updateWidgets(DashboardData data) {
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = Timer(const Duration(milliseconds: 500), () async {
      if (mounted && data.expenseSummaryForWidget.isNotEmpty) {
        
        // Actualiza los widgets principales existentes
        WidgetService.updateAllWidgetData(data: data);

        // ========== INICIO DE LA CORRECCIÓN ==========

        // AHORA (Correcto): Creamos una instancia de WidgetService antes de usarla.
        // También lo hacemos sin 'await' para no bloquear el hilo de la UI.
        if (kDebugMode) {
          print("🔄 Dashboard: Los datos cambiaron, actualizando widget de próximos pagos.");
        }
        WidgetService().updateUpcomingPaymentsWidget();

        // ========== FIN DE LA CORRECCIÓN ==========
      }
    });
  }


  @override
  void dispose() {
    _eventSubscription?.cancel();
    _widgetUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // Llama al Singleton para refrescar.
    await _dashboardRepository.forceRefresh(silent: false);
  }

  void _navigateToTransactionsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TransactionsScreen()),
    );
  }

  void _handleTransactionTap(Transaction transaction) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );
    if (changed == true) {
      // Disparamos el evento para que MainScreen lo capture.
      EventService.instance.fire(AppEvent.transactionUpdated);
    }
  }

  Future<bool> _handleTransactionDelete(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
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
              child: const Text('Cancelar')
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
        if (mounted) {
          NotificationHelper.show(message: 'Transacción eliminada.', type: NotificationType.success);
          // Disparamos el evento para que MainScreen lo capture.
          EventService.instance.fire(AppEvent.transactionDeleted);
        }
        return true;
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(message: 'Error al eliminar.', type: NotificationType.error);
        }
        return false;
      }
    }
    return false;
  }
  
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
              return Center(child: Text('Error al cargar los datos: ${snapshot.error}'));
            }
            // Muestra el shimmer si no hay datos o si el modelo indica que está cargando detalles.
            if (!snapshot.hasData || snapshot.data!.isLoading) {
              return _buildLoadingShimmer();
            }
            final data = snapshot.data!;
            _updateWidgets(data); 
            return _buildDashboardContent(data);
          },
        ),
      ),
    );
  }


  Widget _buildDashboardContent(DashboardData data) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
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
          SliverToBoxAdapter(
            child: BudgetsSection(
              budgets: data.featuredBudgets,
              // Ya no es necesario pasar transactionRepository ni accountRepository
            ),
          ),
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

  // El Shimmer sigue siendo el mismo, está muy bien.
  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Container(
      width: double.infinity, // Asegura que ocupe todo el ancho
      color: Theme.of(context).scaffoldBackgroundColor, // Le da un fondo sólido
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        direction: ShimmerDirection.ltr,
        child: SingleChildScrollView(
          // <-- Usando SingleChildScrollView
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            // <-- Usando Column
            crossAxisAlignment:
                CrossAxisAlignment.start, // Alinea los elementos a la izquierda
            children: [
              // Padding general para que no esté pegado a los bordes
              const SizedBox(height: 16),
              // Shimmer para el Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150.0,
                      height: 24.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200.0,
                      height: 32.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Shimmer para la Tarjeta de Saldo
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              // --- NUEVO: SHIMMER PARA LA SECCIÓN DE PRESUPUESTOS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: 250.0,
                  height: 28.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140, // Misma altura que tu lista de presupuestos real
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3, // Muestra 3 placeholders de tarjetas
                  itemBuilder: (context, index) => Container(
                    width:
                        220, // Mismo ancho que tus tarjetas de presupuesto reales
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              // --- FIN DEL SHIMMER DE PRESUPUESTOS ---
              const SizedBox(height: 24),
              // Shimmer para la sección de IA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 220.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}