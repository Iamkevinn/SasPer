// lib/screens/dashboard_screen.dart

import 'dart:async';

import 'package:sasper/widgets/shared/custom_notification_widget.dart';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sasper/main.dart';

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
  // --- Dependencias (Singletons) ---
  final DashboardRepository _dashboardRepository = DashboardRepository.instance;
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  final WidgetService _widgetService = WidgetService();

  // --- Gestión de Streams y Estado ---
  late final Stream<DashboardData> _dashboardDataStream;
  StreamSubscription<DashboardData>? _widgetUpdateSubscription;
  Timer? _widgetUpdateDebounce;

  @override
  void initState() {
    super.initState();
    _dashboardDataStream = _dashboardRepository.getDashboardDataStream();

    // OPTIMIZACIÓN (IMPACTO ALTO): Desacoplar la lógica de actualización del widget del método `build`.
    // Escuchamos el stream de datos aquí, una sola vez cuando el widget se crea.
    _widgetUpdateSubscription = _dashboardDataStream.listen((data) {
      // Solo actualizamos los widgets si el widget todavía está en pantalla (`mounted`)
      // y si los datos ya están completamente cargados (`!data.isLoading`).
      if (mounted && !data.isLoading) {
        
        // OPTIMIZACIÓN (DEBOUNCING): Evitamos una tormenta de actualizaciones.
        // Si llegan múltiples actualizaciones de datos en un corto período (ej. por Realtime),
        // cancelamos el timer anterior y creamos uno nuevo. Solo la última actualización
        // en una ventana de 700ms activará la lógica de actualización del widget.
        _widgetUpdateDebounce?.cancel();
        _widgetUpdateDebounce = Timer(const Duration(milliseconds: 700), () {
          // Esta lógica ahora se ejecuta de forma segura, eficiente y solo cuando es necesario.
          _widgetService.updateAllWidgets(data, context);
          _widgetService.updateUpcomingPaymentsWidget();
        });
      }
    });
  }

  @override
  void dispose() {
    // OPTIMIZACIÓN (PREVENCIÓN DE FUGAS DE MEMORIA): Es CRÍTICO cancelar las suscripciones y timers.
    // Si no lo hacemos, seguirán ejecutándose en segundo plano incluso después de que
    // el usuario haya salido de la pantalla, causando errores y consumiendo recursos.
    _widgetUpdateSubscription?.cancel();
    _widgetUpdateDebounce?.cancel();
    super.dispose();
  }

  // --- Métodos de Lógica de la Pantalla ---

  Future<void> _handleRefresh() async {
    await _dashboardRepository.forceRefresh(silent: false);
  }

  void _navigateToTransactionsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const TransactionsScreen()),
    );
  }

  void _handleTransactionTap(Transaction transaction) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );
    if (changed == true) {
      EventService.instance.fire(AppEvent.transactionUpdated);
    }
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
                foregroundColor: Theme.of(dialogContext).colorScheme.onErrorContainer
              ),
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
            if (!snapshot.hasData || snapshot.data!.isLoading) {
              return _buildLoadingShimmer();
            }
            final data = snapshot.data!;
            
            // OPTIMIZACIÓN: El método `build` ahora es "puro". Solo se encarga de construir
            // la interfaz de usuario. Toda la lógica pesada o asíncrona ha sido movida
            // al `initState`, lo que hace que la reconstrucción del widget sea mucho más rápida.
            
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
          SliverToBoxAdapter(child: BudgetsSection(budgets: data.featuredBudgets)),
          
          // OPTIMIZACIÓN (BUENA PRÁCTICA): Usar `const` para widgets que nunca cambian.
          // Esto le dice a Flutter que puede saltarse la reconstrucción de estos widgets,
          // ahorrando preciosos milisegundos en cada frame.
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

  // OPTIMIZACIÓN: Se ha añadido `const` a todos los widgets estáticos dentro del Shimmer.
  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        child: const SingleChildScrollView( // <-- `const` aquí porque el hijo es `const`
          physics: NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 150.0, height: 24.0),
                    SizedBox(height: 8),
                    _ShimmerBox(width: 200.0, height: 32.0),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _ShimmerBox(height: 120, borderRadius: 24),
              ),
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: _ShimmerBox(width: 250.0, height: 28.0),
              ),
              SizedBox(height: 12),
              _BudgetShimmerList(), // <-- Extraído a un widget `const`
              SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 220.0, height: 28.0),
                    SizedBox(height: 12),
                    _ShimmerBox(height: 150, borderRadius: 20),
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

// OPTIMIZACIÓN: Extraer partes repetitivas del Shimmer a widgets privados y `const`.
class _ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class _BudgetShimmerList extends StatelessWidget {
  const _BudgetShimmerList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(right: 12),
          child: _ShimmerBox(width: 220, height: 140, borderRadius: 20),
        ),
      ),
    );
  }
}