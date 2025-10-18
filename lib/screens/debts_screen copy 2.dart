// lib/screens/debts_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/screens/add_debt_screen.dart';
import 'package:sasper/screens/edit_debt_screen.dart';
import 'package:sasper/screens/register_payment_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/debts/debt_card.dart';
import 'package:sasper/widgets/debts/shareable_debt_summary.dart';
import 'package:sasper/widgets/shared/custom_dialog.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:skeletonizer/skeletonizer.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with TickerProviderStateMixin {
  late final TabController _mainTabController;
  late final Stream<List<Debt>> _debtsStream;
  final DebtRepository _repository = DebtRepository.instance;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _debtsStream = _repository.getDebtsStream();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    super.dispose();
  }

  void _navigateToAddDebt() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDebtScreen()),
    );
  }

  void _navigateToEdit(Debt debt) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditDebtScreen(debt: debt)),
    );
  }

  void _navigateToRegisterPayment(Debt debt) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterPaymentScreen(debt: debt)),
    );
  }

  Future<void> _handleDelete(Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CustomDialog(
        title: '¿Confirmar Eliminación?',
        content: 'Estás a punto de eliminar "${debt.name}". Esta acción no se puede deshacer.',
        confirmText: 'Sí, Eliminar',
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteDebt(debt.id);
        NotificationHelper.show(
          message: 'Deuda eliminada correctamente',
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

  Future<void> _handleShare(Debt debt) async {
    try {
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        ShareableDebtSummary(debt: debt),
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes == null) return;

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/debt_summary.png').create();
      await imagePath.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Resumen de deuda/préstamo: ${debt.name}',
      );
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          message: 'No se pudo compartir',
          type: NotificationType.error,
        );
      }
    }
  }

  void _handleDebtAction(DebtCardAction action, Debt debt) {
    switch (action) {
      case DebtCardAction.registerPayment:
        _navigateToRegisterPayment(debt);
        break;
      case DebtCardAction.edit:
        _navigateToEdit(debt);
        break;
      case DebtCardAction.delete:
        _handleDelete(debt);
        break;
      case DebtCardAction.share:
        _handleShare(debt);
        break;
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
            expandedHeight: 140,
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
                    'Deudas y',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Préstamos',
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
                      Colors.red.withOpacity(0.1),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton.tonalIcon(
                onPressed: _navigateToAddDebt,
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
                  controller: _mainTabController,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Yo Debo'),
                    Tab(text: 'Me Deben'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<Debt>>(
          stream: _debtsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return _buildSkeletonizer();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final allDebts = snapshot.data ?? [];
            if (allDebts.isEmpty) {
              return _buildGlobalEmptyState();
            }

            final myDebts = allDebts.where((d) => d.type == DebtType.debt).toList();
            final loansToOthers = allDebts.where((d) => d.type == DebtType.loan).toList();

            return TabBarView(
              controller: _mainTabController,
              children: [
                _DebtCategoryView(
                  debts: myDebts,
                  onActionSelected: _handleDebtAction,
                  type: DebtType.debt,
                ),
                _DebtCategoryView(
                  debts: loansToOthers,
                  onActionSelected: _handleDebtAction,
                  type: DebtType.loan,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonizer() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 3,
        itemBuilder: (context, index) => DebtCard(
          debt: Debt.empty(),
          onActionSelected: (_) {},
        ),
      ),
    );
  }

  Widget _buildGlobalEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/add_item_animation.json',
              width: 280,
              height: 280,
            ),
            const SizedBox(height: 24),
            Text(
              '¡Todo en orden!',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No tienes deudas ni préstamos registrados. Mantén el control de tus finanzas añadiendo uno nuevo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _navigateToAddDebt,
              icon: const Icon(Iconsax.add_circle),
              label: const Text('Añadir Deuda o Préstamo'),
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
            // --- CORRECCIÓN AQUÍ ---
            // Simplemente eliminamos el botón. Como usamos un stream,
            // si la conexión se restaura, los datos llegarán automáticamente.
            // Si el error es persistente (ej. de permiso), un botón de reintento
            // no lo solucionará. La UI se reconstruirá sola.
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET PARA CADA CATEGORÍA (YO DEBO / ME DEBEN)
// ============================================================================
class _DebtCategoryView extends StatefulWidget {
  final List<Debt> debts;
  final void Function(DebtCardAction, Debt) onActionSelected;
  final DebtType type;

  const _DebtCategoryView({
    required this.debts,
    required this.onActionSelected,
    required this.type,
  });

  @override
  State<_DebtCategoryView> createState() => _DebtCategoryViewState();
}

class _DebtCategoryViewState extends State<_DebtCategoryView>
    with TickerProviderStateMixin {
  late final TabController _historyTabController;

  @override
  void initState() {
    super.initState();
    _historyTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _historyTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeDebts = widget.debts.where((d) => d.status == DebtStatus.active).toList();
    final paidDebts = widget.debts.where((d) => d.status == DebtStatus.paid).toList();

    if (widget.debts.isEmpty) {
      return _buildCategoryEmptyState();
    }

    return Column(
      children: [
        // Estadísticas rápidas
        _buildQuickStats(activeDebts),

        // Tabs de Activas/Historial
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _historyTabController,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: 'Activas (${activeDebts.length})'),
              Tab(text: 'Historial (${paidDebts.length})'),
            ],
          ),
        ),

        // Contenido de tabs
        Expanded(
          child: TabBarView(
            controller: _historyTabController,
            children: [
              _buildDebtsList(activeDebts, isHistory: false),
              _buildDebtsList(paidDebts, isHistory: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(List<Debt> activeDebts) {
    if (activeDebts.isEmpty) return const SizedBox.shrink();

    final totalAmount = activeDebts.fold<double>(0, (sum, debt) => sum + debt.initialAmount);
    final totalPaid = activeDebts.fold<double>(0, (sum, debt) => sum + debt.paidAmount);
    final totalRemaining = totalAmount - totalPaid;

    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.type == DebtType.debt
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
          color: widget.type == DebtType.debt
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.type == DebtType.debt
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.type == DebtType.debt ? Iconsax.card_remove : Iconsax.card_tick,
                  color: widget.type == DebtType.debt ? Colors.red : Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.type == DebtType.debt ? 'Total que Debo' : 'Total que me Deben',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatColumn(
                label: 'Pendiente',
                value: currencyFormat.format(totalRemaining),
                color: widget.type == DebtType.debt ? Colors.red : Colors.green,
                isLarge: true,
              ),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
              _StatColumn(
                label: 'Pagado',
                value: currencyFormat.format(totalPaid),
                color: Theme.of(context).colorScheme.primary,
              ),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
              _StatColumn(
                label: 'Total',
                value: currencyFormat.format(totalAmount),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }

  Widget _buildDebtsList(List<Debt> debts, {required bool isHistory}) {
    if (debts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHistory ? Iconsax.document_text : Iconsax.tick_circle,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                isHistory ? 'Sin historial' : '¡Todo al día!',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isHistory
                    ? 'Aquí aparecerán las deudas que completes.'
                    : 'No tienes nada pendiente en este momento.',
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

    return RefreshIndicator(
      // Cambiamos la llamada a un Future vacío que se completa después de 1 segundo.
      // Esto permite que la animación de "refrescar" se muestre, dando al usuario
      // una sensación de control, aunque el stream se actualiza solo.
      onRefresh: () => Future<void>.delayed(const Duration(seconds: 1)),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        itemCount: debts.length,
        itemBuilder: (context, index) {
          final debt = debts[index];
          return Opacity(
            opacity: isHistory ? 0.7 : 1.0,
            child: DebtCard(
              debt: debt,
              onActionSelected: (action) => widget.onActionSelected(action, debt),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: (80 * index).ms)
              .slideX(begin: -0.1, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildCategoryEmptyState() {
    final isDebt = widget.type == DebtType.debt;
    
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDebt ? Iconsax.shield_tick : Iconsax.money_send,
              size: 100,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              isDebt ? '¡Sin deudas!' : '¡Nadie te debe!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isDebt
                  ? 'Aquí aparecerán los préstamos que recibas.'
                  : 'Cuando le prestes dinero a alguien, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

// ============================================================================
// WIDGET PARA COLUMNA DE ESTADÍSTICAS
// ============================================================================
class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isLarge;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isLarge ? 2 : 1,
      child: Column(
        crossAxisAlignment: isLarge ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isLarge ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}