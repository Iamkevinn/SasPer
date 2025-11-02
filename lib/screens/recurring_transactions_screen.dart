// lib/screens/recurring_transactions_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/screens/add_recurring_transaction_screen.dart';
import 'package:sasper/screens/edit_recurring_transaction_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/main.dart';
import 'dart:developer' as developer;

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> with TickerProviderStateMixin {
  final RecurringRepository _repository = RecurringRepository.instance;
  late final Stream<List<RecurringTransaction>> _stream;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _stream = _repository.getRecurringTransactionsStream();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToEdit(RecurringTransaction transaction) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditRecurringTransactionScreen(transaction: transaction),
      ),
    );
    if (result == true) {
      _repository.refreshData();
    }
  }

  Future<void> _handleDelete(RecurringTransaction item) async {
    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Iconsax.trash,
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Eliminar gasto fijo'),
            ],
          ),
          content: Text('¿Seguro que quieres eliminar "${item.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteRecurringTransaction(item.id);
        await NotificationService.instance.cancelRecurringReminders(item.id);
        developer.log('✅ Notificaciones canceladas para: ${item.description}',
            name: 'RecurringScreen');
        _repository.refreshData();
        NotificationHelper.show(
          message: 'Gasto fijo eliminado',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          message: 'Error al eliminar',
          type: NotificationType.error,
        );
      }
    }
  }

  void _navigateToAdd() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddRecurringTransactionScreen()),
    );
    if (result == true) {
      _repository.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gastos',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Fijos',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.withOpacity(0.1),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton.tonalIcon(
                onPressed: _navigateToAdd,
                icon: const Icon(Iconsax.add, size: 20),
                label: const Text('Nuevo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 16),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Gastos'),
                    Tab(text: 'Ingresos'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<RecurringTransaction>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoader();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return _buildEmptyState();
            }

            final expenses = items.where((i) => i.type == 'Gasto').toList();
            final incomes = items.where((i) => i.type == 'Ingreso').toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildRecurringList(expenses, isExpense: true),
                _buildRecurringList(incomes, isExpense: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecurringList(List<RecurringTransaction> items, {required bool isExpense}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isExpense ? Iconsax.receipt_minus : Iconsax.receipt_add,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                isExpense ? 'Sin gastos fijos' : 'Sin ingresos fijos',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isExpense
                    ? 'Añade gastos recurrentes como suscripciones o alquiler'
                    : 'Añade ingresos recurrentes como tu salario',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdue = items.where((i) => i.nextDueDate.isBefore(today)).toList();
    final dueToday = items.where((i) {
      final dueDate = i.nextDueDate;
      return dueDate.year == today.year &&
          dueDate.month == today.month &&
          dueDate.day == today.day;
    }).toList();
    final upcoming = items.where((i) => i.nextDueDate.isAfter(today)).toList();

    return RefreshIndicator(
      onRefresh: () => _repository.refreshData(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // Resumen mensual
          SliverToBoxAdapter(
            child: _buildMonthlySummary(items, isExpense)
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.2),
          ),

          // Vencidos
          if (overdue.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Vencidos',
                overdue.length,
                Colors.red,
                Iconsax.danger,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PaymentCard(
                  item: overdue[index],
                  onEdit: () => _navigateToEdit(overdue[index]),
                  onDelete: () => _handleDelete(overdue[index]),
                  repository: _repository,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: (80 * index).ms)
                    .slideX(begin: -0.1),
                childCount: overdue.length,
              ),
            ),
          ],

          // Para hoy
          if (dueToday.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Para Hoy',
                dueToday.length,
                Colors.orange,
                Iconsax.clock,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PaymentCard(
                  item: dueToday[index],
                  onEdit: () => _navigateToEdit(dueToday[index]),
                  onDelete: () => _handleDelete(dueToday[index]),
                  repository: _repository,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: (80 * index).ms)
                    .slideX(begin: -0.1),
                childCount: dueToday.length,
              ),
            ),
          ],

          // Próximos
          if (upcoming.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Próximos',
                upcoming.length,
                Colors.green,
                Iconsax.calendar_tick,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _PaymentCard(
                    item: upcoming[index],
                    onEdit: () => _navigateToEdit(upcoming[index]),
                    onDelete: () => _handleDelete(upcoming[index]),
                    repository: _repository,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (80 * index).ms)
                      .slideX(begin: -0.1),
                  childCount: upcoming.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(List<RecurringTransaction> items, bool isExpense) {
    final totalMonthly = items.fold<double>(0, (sum, item) {
      // Calcular equivalente mensual según frecuencia
      switch (item.frequency) {
        case 'daily':
          return sum + (item.amount * 30);
        case 'weekly':
          return sum + (item.amount * 4);
        case 'biweekly':
          return sum + (item.amount * 2);
        case 'monthly':
          return sum + item.amount;
        case 'quarterly':
          return sum + (item.amount / 3);
        case 'yearly':
          return sum + (item.amount / 12);
        default:
          return sum + item.amount;
      }
    });

    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpense
              ? [
                  Colors.red.withOpacity(0.15),
                  Colors.orange.withOpacity(0.1),
                ]
              : [
                  Colors.green.withOpacity(0.15),
                  Colors.teal.withOpacity(0.1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpense
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isExpense
                  ? Colors.red.withOpacity(0.2)
                  : Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isExpense ? Iconsax.wallet_minus : Iconsax.wallet_add,
              color: isExpense ? Colors.red : Colors.green,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Mensual',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currencyFormat.format(totalMonthly),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isExpense ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${items.length} ${isExpense ? 'gasto' : 'ingreso'}${items.length != 1 ? 's' : ''} activo${items.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/automation_animation.json',
              width: 280,
              height: 280,
            ),
            const SizedBox(height: 24),
            Text(
              'Automatiza tus Finanzas',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Añade tus gastos e ingresos recurrentes y la app los registrará automáticamente',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _navigateToAdd,
              icon: const Icon(Iconsax.add_circle),
              label: const Text('Añadir gasto fijo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.danger,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Algo salió mal',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _repository.refreshData(),
              icon: const Icon(Iconsax.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TARJETA DE PAGO
// ============================================================================
class _PaymentCard extends StatelessWidget {
  final RecurringTransaction item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final RecurringRepository repository;

  const _PaymentCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.repository,
  });

  Future<void> _handlePay(BuildContext context) async {
    try {
      await repository.processPayment(item.id);
      NotificationHelper.show(
        message: 'Pago registrado exitosamente',
        type: NotificationType.success,
      );
    } catch (e) {
      NotificationHelper.show(
        message: 'Error al registrar pago',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _handleSkip(BuildContext context) async {
    try {
      await repository.skipPayment(item.id);
      NotificationHelper.show(
        message: 'Pago omitido',
        type: NotificationType.success,
      );
    } catch (e) {
      NotificationHelper.show(
        message: 'Error al omitir pago',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _handleSnooze(BuildContext context) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: item.nextDueDate.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );
    if (newDate != null) {
      try {
        await repository.snoozePayment(item.id, newDate);
        NotificationHelper.show(
          message: 'Pago pospuesto',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          message: 'Error al posponer',
          type: NotificationType.error,
        );
      }
    }
  }

  String _getFrequencyText() {
    switch (item.frequency) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'biweekly':
        return 'Quincenal';
      case 'monthly':
        return 'Mensual';
      case 'quarterly':
        return 'Trimestral';
      case 'yearly':
        return 'Anual';
      default:
        return item.frequency;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final isExpense = item.type == 'Gasto';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      item.nextDueDate.year,
      item.nextDueDate.month,
      item.nextDueDate.day,
    );
    final daysUntil = dueDate.difference(today).inDays;

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: daysUntil < 0
              ? Colors.red.withOpacity(0.5)
              : colorScheme.outlineVariant,
          width: daysUntil < 0 ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con monto
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isExpense
                            ? Colors.red.withOpacity(0.15)
                            : Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isExpense ? Iconsax.arrow_down_2 : Iconsax.arrow_up_1,
                        color: isExpense ? Colors.red : Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getFrequencyText(),
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isExpense ? '-' : '+'}${currencyFormat.format(item.amount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isExpense ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Fecha de vencimiento
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: daysUntil < 0
                        ? Colors.red.withOpacity(0.1)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.calendar_1,
                        size: 18,
                        color: daysUntil < 0 ? Colors.red : colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Vence: ${DateFormat.yMMMd('es_CO').format(item.nextDueDate)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: daysUntil < 0 ? Colors.red : colorScheme.onSurface,
                        ),
                      ),
                      if (daysUntil < 0) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'VENCIDO',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ] else if (daysUntil == 0) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HOY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Acciones
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Botón de opciones
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOptionsMenu(context),
                    icon: const Icon(Iconsax.more, size: 18),
                    label: const Text('Opciones'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón de pagar
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _handlePay(context),
                    icon: const Icon(Iconsax.tick_circle, size: 18),
                    label: Text(isExpense ? 'Pagar ahora' : 'Registrar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Iconsax.setting_2, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Opciones',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Opciones
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.clock, size: 20),
              ),
              title: const Text('Posponer'),
              subtitle: const Text('Elegir nueva fecha'),
              trailing: const Icon(Iconsax.arrow_right_3),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _handleSnooze(context);
              },
            ),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.next, size: 20, color: Colors.orange),
              ),
              title: const Text('Omitir este mes'),
              subtitle: const Text('Saltar al siguiente período'),
              trailing: const Icon(Iconsax.arrow_right_3),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _handleSkip(context);
              },
            ),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.edit, size: 20),
              ),
              title: const Text('Editar'),
              subtitle: const Text('Modificar detalles'),
              trailing: const Icon(Iconsax.arrow_right_3),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                onEdit();
              },
            ),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.trash,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              title: Text(
                'Eliminar',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              subtitle: const Text('Eliminar permanentemente'),
              trailing: const Icon(Iconsax.arrow_right_3),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                onDelete();
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}