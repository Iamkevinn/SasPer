// lib/screens/debts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

// Importamos la arquitectura limpia
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/screens/add_debt_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/debts/debt_card.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'register_payment_screen.dart';
import 'package:sasper/screens/edit_debt_screen.dart'; // NUEVO: Importamos la pantalla de edición
import 'package:sasper/widgets/shared/custom_dialog.dart';

// --- NUEVAS IMPORTACIONES ---
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';

class DebtsScreen extends StatefulWidget {
  // El constructor ahora es simple y constante. No recibe ningún parámetro.
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Stream<List<Debt>> _debtsStream;

  // Accedemos a la única instancia (Singleton) del repositorio.
  final DebtRepository _repository = DebtRepository.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Obtenemos el stream del Singleton.
    _debtsStream = _repository.getDebtsStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToAddDebt() {
    Navigator.of(context).push(MaterialPageRoute(
      // La pantalla de "Añadir" tampoco necesita repositorios en el constructor.
      // Ella misma obtendrá los Singletons que necesite.
      builder: (_) => const AddDebtScreen(),
    ));
  }

  @override
    Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Deudas y Préstamos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [
            Tab(text: 'Yo Debo (Deudas)'),
            Tab(text: 'Me Deben (Préstamos)'),
          ],
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
          // --- ESTADO DE CARGA ---
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildSkeletonizer();
          }

          // --- ESTADO DE ERROR ---
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final allDebts = snapshot.data ?? [];

          // --- ESTADO VACÍO GENERAL ---
          // Si la lista COMPLETA está vacía, mostramos la animación Lottie principal.
          if (allDebts.isEmpty) {
            return _buildLottieEmptyState(); // <-- CORRECCIÓN #1
          }
          
          // --- ESTADO CON DATOS ---
          // Si hay datos, separamos las listas y construimos la TabBarView.
          final myDebts = allDebts.where((d) => d.type == DebtType.debt).toList();
          final loansToOthers = allDebts.where((d) => d.type == DebtType.loan).toList();
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildDebtsList(myDebts, isMyDebt: true),
              _buildDebtsList(loansToOthers, isMyDebt: false),
            ],
          );
        },
      ),
    );
  }

  // --- MÉTODOS PARA MANEJAR LAS ACCIONES ---

  Widget _buildLottieEmptyState({bool isForTab = false, bool isMyDebt = true}) {
    // Personalizamos el texto según si es el estado vacío general o de una pestaña.
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
              Lottie.asset(
                'assets/animations/add_item_animation.json',
                width: 250,
                height: 250,
              ),
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
    }
  }


  void _navigateToRegisterPayment(Debt debt) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegisterPaymentScreen(debt: debt)),
    );
  }

  void _navigateToEdit(Debt debt) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditDebtScreen(debt: debt)),
    );
  }

  Widget _buildDebtsList(List<Debt> debts, {required bool isMyDebt}) {
    if (debts.isEmpty) {
      // Usamos el mismo Lottie para el estado vacío de cada pestaña.
      return _buildLottieEmptyState(isForTab: true, isMyDebt: isMyDebt);
    }
    
    // --- REEMPLAZO DE STAGGEREDANIMATIONS CON FLUTTER_ANIMATE ---
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        return DebtCard(
          debt: debt,
          onActionSelected: (action) => _handleDebtAction(action, debt),
        )
        // Animación de entrada en cascada para cada tarjeta.
        .animate()
        .fadeIn(duration: 500.ms, delay: (100 * index).ms)
        .slideY(begin: 0.3, curve: Curves.easeOutCubic);
      },
    );
  }

  // --- NUEVOS WIDGETS AUXILIARES ---

  Widget _buildSkeletonizer() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
        itemCount: 4,
        itemBuilder: (context, index) => DebtCard(
          debt: Debt.empty(), // Usa el modelo vacío como molde
          onActionSelected: (_) {},
        ),
      ),
    );
  }
  
  void _handleDelete(Debt debt) {
    // Es una buena práctica pedir confirmación antes de una acción destructiva.
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CustomDialog(
          title: '¿Confirmar Eliminación?',
          content: 'Estás a punto de eliminar "${debt.name}". Esta acción no se puede deshacer.',
          confirmText: 'Sí, Eliminar',
          onConfirm: () async {
            try {
              Navigator.of(dialogContext).pop(); // Cerrar el diálogo
              await _repository.deleteDebt(debt.id);
              if (!mounted) return;
              NotificationHelper.show(
                message: 'Deuda eliminada.',
                type: NotificationType.success,
              );
            } catch (e) {
              if (!mounted) return;
              NotificationHelper.show(
                message: e.toString().replaceFirst("Exception: ", ""),
                type: NotificationType.error,
              );
            }
          },
        );
      },
    );
  }
  

}