// lib/screens/dashboard_screen.dart (CORREGIDO Y COMPLETO)

import 'dart:async';
import 'dart:ui'; // Necesario para ImageFilter.blur
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/screens/edit_transaction_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:shimmer/shimmer.dart';

import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:sasper/widgets/dashboard/ai_analysis_section.dart';
import 'package:sasper/widgets/dashboard/balance_card.dart';
import 'package:sasper/widgets/dashboard/budgets_section.dart';
import 'package:sasper/widgets/dashboard/dashboard_header.dart';
import 'package:sasper/widgets/dashboard/recent_transactions_section.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardRepository repository;

  // 1. AÑADIDO: Recibimos los repositorios necesarios para las acciones.
  final AccountRepository accountRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.accountRepository,
    required this.transactionRepository,
    required this.budgetRepository,
  });

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late final Stream<DashboardData> _dashboardDataStream;
  late final StreamSubscription<AppEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _dashboardDataStream = widget.repository.getDashboardDataStream();

    _eventSubscription = EventService.instance.eventStream.listen((event) {
      // Tu lógica de eventos está perfecta.
      if ({
        AppEvent.transactionsChanged,
        AppEvent.transactionDeleted,
        AppEvent.accountCreated,
        AppEvent.debtsChanged,
        AppEvent.goalsChanged,
        AppEvent.transactionCreated, // <-- AÑADIDO
        AppEvent.transactionUpdated,
      }.contains(event)) {
        if (kDebugMode) print("Dashboard: Evento '$event' recibido. Forzando refresh...");
        widget.repository.forceRefresh();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await widget.repository.forceRefresh(silent: false);
  }

  // +++ NUEVA FUNCIÓN: Maneja la navegación a la pantalla de transacciones +++
  void _navigateToTransactionsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TransactionsScreen(
          // Le pasamos los repositorios que necesita la pantalla de destino
          transactionRepository: widget.transactionRepository,
          accountRepository: widget.accountRepository,
        ),
      ),
    );
  }
  
  // 2. NUEVA FUNCIÓN: Maneja el toque en una transacción.
  void _handleTransactionTap(Transaction transaction) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(
          transaction: transaction,
          transactionRepository: widget.transactionRepository,
          accountRepository: widget.accountRepository,
        ),
      ),
    ).then((changed) {
      // Si la pantalla de edición devuelve 'true', refrescamos los datos.
      if (changed == true) {
        widget.repository.forceRefresh();
      }
    });
  }

  // 3. NUEVA FUNCIÓN: Maneja la eliminación de una transacción.
  Future<bool> _handleTransactionDelete(Transaction transaction) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.85),
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await widget.transactionRepository.deleteTransaction(transaction.id);
        if (mounted) {
          NotificationHelper.show(
            context: context,
            message: 'Transacción eliminada correctamente.',
            type: NotificationType.success,
          );
          // Forzamos la actualización del dashboard para que el cambio se refleje.
          widget.repository.forceRefresh();
        }
        return true; // Se borró con éxito
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            context: context,
            message: 'Error al eliminar la transacción.',
            type: NotificationType.error,
          );
        }
        return false; // Hubo un error
      }
    }
    return false; // No se confirmó el borrado
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Usamos SafeArea para evitar que la UI se solape con la barra de estado.
      body: SafeArea(
        top: true, // Aplicar solo en la parte superior
        bottom: false, // La barra de navegación ya maneja el área inferior
        child: StreamBuilder<DashboardData>(
          stream: _dashboardDataStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final data = snapshot.data!;
              WidgetService.updateWidgetData(totalBalance: data.totalBalance);
              return _buildDashboardContent(data);
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error al cargar los datos: ${snapshot.error}'));
            }
            return _buildLoadingShimmer();
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent(DashboardData data) {
    // 2. Usamos CustomScrollView para un layout más avanzado y profesional.
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView(
        slivers: [
          // 3. SliverAppBar permite un encabezado fijo o flotante.
          SliverAppBar(
            pinned: true, // Mantiene el encabezado visible al hacer scroll
            floating: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            titleSpacing: 16.0,
            title: DashboardHeader(userName: data.fullName),
            toolbarHeight: 80, // Aumenta la altura para dar más espacio
          ),
          
          // 4. Cada widget principal ahora es un "Sliver".
          SliverToBoxAdapter(child: BalanceCard(totalBalance: data.totalBalance)),

          SliverToBoxAdapter(
            child: BudgetsSection(
              budgets: data.featuredBudgets,
              budgetRepository: widget.budgetRepository,
              // --- PASAMOS LOS REPOSITORIOS ADICIONALES ---
              transactionRepository: widget.transactionRepository,
              accountRepository: widget.accountRepository,
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
              // Conectamos la propiedad del widget hijo con nuestra función de navegación.
              onViewAllPressed: _navigateToTransactionsScreen,
            ),
          ),
          
          // Espacio al final para que el scroll no se corte bruscamente
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