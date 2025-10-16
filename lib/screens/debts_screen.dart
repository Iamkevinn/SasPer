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

  // --- MANEJADORES DE ACCIONES Y NAVEGACIÓN ---

  void _navigateToAddDebt() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddDebtScreen()));
  }

  void _navigateToEdit(Debt debt) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditDebtScreen(debt: debt)));
  }

  void _navigateToRegisterPayment(Debt debt) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegisterPaymentScreen(debt: debt)));
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
        NotificationHelper.show(message: 'Deuda eliminada.', type: NotificationType.success);
      } catch (e) {
        NotificationHelper.show(message: e.toString(), type: NotificationType.error);
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
        NotificationHelper.show(message: 'No se pudo compartir la imagen.', type: NotificationType.error);
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
  
  // --- WIDGETS DE CONSTRUCCIÓN ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Deudas y Préstamos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _mainTabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [Tab(text: 'Yo Debo'), Tab(text: 'Me Deben')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square, size: 28),
            tooltip: 'Añadir Deuda/Préstamo',
            onPressed: _navigateToAddDebt,
          ),
        ],
      ),
      body: StreamBuilder<List<Debt>>(
        stream: _debtsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildSkeletonizer();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final allDebts = snapshot.data ?? [];
          if (allDebts.isEmpty) {
            return _buildLottieEmptyState(isForTab: false);
          }

          final myDebts = allDebts.where((d) => d.type == DebtType.debt).toList();
          final loansToOthers = allDebts.where((d) => d.type == DebtType.loan).toList();

          return TabBarView(
            controller: _mainTabController,
            children: [
              _DebtCategoryView(debts: myDebts, onActionSelected: _handleDebtAction),
              _DebtCategoryView(debts: loansToOthers, onActionSelected: _handleDebtAction),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletonizer() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (context, index) => DebtCard(debt: Debt.empty(), onActionSelected: (_) {}),
      ),
    );
  }

  Widget _buildLottieEmptyState({required bool isForTab, bool isMyDebt = true}) {
    final title = isForTab
        ? (isMyDebt ? '¡Sin deudas pendientes!' : '¡Nadie te debe!')
        : 'Todo en Orden';
    final message = isForTab
        ? (isMyDebt ? 'Aquí aparecerán los préstamos que has recibido.' : 'Cuando le prestes dinero a alguien, aparecerá aquí.')
        : 'No tienes deudas ni préstamos registrados. ¡Usa el botón (+) para añadir uno nuevo!';

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/add_item_animation.json', width: 250, height: 250),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// --- WIDGET INTERNO PARA GESTIONAR LAS PESTAÑAS DE HISTORIAL ---
class _DebtCategoryView extends StatefulWidget {
  final List<Debt> debts;
  final void Function(DebtCardAction, Debt) onActionSelected;

  const _DebtCategoryView({required this.debts, required this.onActionSelected});

  @override
  State<_DebtCategoryView> createState() => _DebtCategoryViewState();
}

class _DebtCategoryViewState extends State<_DebtCategoryView> with TickerProviderStateMixin {
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
    
    // Si no hay deudas de ningún tipo en esta categoría, mostramos un estado vacío.
    if (widget.debts.isEmpty) {
        final isMyDebtTab = widget.debts.any((d) => d.type == DebtType.debt);
        return (context.findAncestorStateOfType<_DebtsScreenState>())!
            ._buildLottieEmptyState(isForTab: true, isMyDebt: isMyDebtTab);
    }
    
    return Column(
      children: [
        TabBar(
          controller: _historyTabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: [
            Tab(text: 'Activas (${activeDebts.length})'),
            Tab(text: 'Historial (${paidDebts.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _historyTabController,
            children: [
              _buildList(activeDebts, isHistory: false),
              _buildList(paidDebts, isHistory: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<Debt> debts, {required bool isHistory}) {
    if (debts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            isHistory ? 'Aquí aparecerán las deudas y préstamos que completes.' : '¡Todo al día! No tienes nada pendiente aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        return Opacity(
          opacity: isHistory ? 0.75 : 1.0,
          child: DebtCard(
            debt: debt,
            onActionSelected: (action) => widget.onActionSelected(action, debt),
          ),
        ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1);
      },
    );
  }
}