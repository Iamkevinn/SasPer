// lib/screens/budgets_screen.dart (VERSIÓN FINAL CON PRESUPUESTOS FLEXIBLES)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart'; // ¡Importa el nuevo modelo `Budget`!
import 'package:sasper/services/event_service.dart';
import 'package:sasper/screens/add_budget_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
//import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/budget_card.dart'; // ¡Necesitaremos actualizar este widget!
import 'package:sasper/main.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';
// ¡Importamos la pantalla de detalles que ya refactorizamos!
import 'package:sasper/screens/budget_details_screen.dart'; 


class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final BudgetRepository _repository = BudgetRepository.instance;
  // --- ¡CORRECCIÓN! El Stream ahora es de `Budget` ---
  late final Stream<List<Budget>> _budgetsStream;

  @override
  void initState() {
    super.initState();
    _budgetsStream = _repository.getBudgetsStream();
  }
  
  void _navigateToAddBudget() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
    );
    if (result == true && mounted) {
      // La suscripción realtime ya debería refrescar, pero esto asegura la inmediatez.
      _repository.refreshData();
    }
  }

  // --- ¡NUEVO! Navegamos a la pantalla de detalles ---
  void _navigateToBudgetDetails(Budget budget) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BudgetDetailsScreen(budgetId: budget.id),
      ),
    );
  }

  Future<void> _handleDeleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Confirmar eliminación'),
          // Usamos la propiedad `category` del nuevo modelo.
          content: Text('¿Seguro que quieres eliminar el presupuesto para "${budget.category}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Usamos la propiedad `id` del nuevo modelo.
        await _repository.deleteBudgetSafely(budget.id);
        EventService.instance.fire(AppEvent.budgetsChanged);
        NotificationHelper.show(message: 'Presupuesto eliminado.', type: NotificationType.success);
      } catch (e) {
        NotificationHelper.show(message: e.toString().replaceFirst("Exception: ", ""), type: NotificationType.error);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // El título ahora es genérico.
        title: Text('Mis Presupuestos', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square),
            tooltip: 'Añadir Presupuesto',
            onPressed: _navigateToAddBudget,
          ),
        ],
      ),
      // --- ¡CORRECCIÓN! El StreamBuilder ahora espera una lista de `Budget` ---
      body: StreamBuilder<List<Budget>>(
        stream: _budgetsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Skeletonizer(
              child: ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: 5,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => BudgetCard(
                  // Usamos el modelo `Budget.empty()`
                  budget: Budget.empty(),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar presupuestos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildLottieEmptyState();
          }

          final allBudgets = snapshot.data!;
          // --- NUEVA LÓGICA DE AGRUPACIÓN ---
          final activeBudgets = allBudgets.where((b) => b.isActive).toList();
          final inactiveBudgets = allBudgets.where((b) => !b.isActive).toList();

          // Usamos un `ListView` para poder tener secciones.
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (activeBudgets.isNotEmpty) ...[
                _buildSectionHeader('Activos'),
                ...activeBudgets.map((budget) => _buildBudgetListItem(budget)),
              ],
              if (inactiveBudgets.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Próximos y Pasados'),
                ...inactiveBudgets.map((budget) => _buildBudgetListItem(budget, isActive: false)),
              ],
            ],
          );
        },
      ),
    );
  }

  // --- NUEVO WIDGET para construir un elemento de la lista ---
  Widget _buildBudgetListItem(Budget budget, {bool isActive = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: BudgetCard(
        budget: budget,
        // Al tocar, navegamos a los detalles.
        onTap: () => _navigateToBudgetDetails(budget),
        // Opcional: mantenemos los gestos de editar/borrar
        // onEdit: () => _navigateToEditBudget(budget),
        onDelete: () => _handleDeleteBudget(budget),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: isActive ? -0.1 : 0.1),
    );
  }

  // --- NUEVO WIDGET para los encabezados de sección ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  // Widget de estado vacío (lógica de texto actualizada)
  Widget _buildLottieEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/piggy_bank_animation.json', width: 250, height: 250),
              const SizedBox(height: 16),
              Text('Sin Presupuestos', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              // --- Texto actualizado ---
              Text(
                'Aún no has creado ningún presupuesto. ¡Empieza a planificar tus gastos semanales, mensuales o personalizados!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToAddBudget,
                icon: const Icon(Iconsax.add),
                label: const Text('Crear mi primer presupuesto'),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}