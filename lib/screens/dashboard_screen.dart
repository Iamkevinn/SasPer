// lib/screens/dashboard_screen.dart

import 'dart:async';
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

    _widgetUpdateSubscription = _dashboardDataStream.listen((data) {
      if (mounted && !data.isLoading) {
        _widgetUpdateDebounce?.cancel();
        _widgetUpdateDebounce = Timer(const Duration(milliseconds: 700), () {
          _widgetService.updateAllWidgets(data, context);
          _widgetService.updateUpcomingPaymentsWidget();
        });
      }
    });
  }

  @override
  void dispose() {
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
            
            final isLoading = !snapshot.hasData || snapshot.data!.isLoading;
            final data = isLoading ? DashboardData.empty() : snapshot.data!;

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