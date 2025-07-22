// lib/widgets/dashboard/budgets_section.dart (CORREGIDO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/budget_repository.dart'; // Importa el repositorio
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/widgets/shared/budget_card.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

class BudgetsSection extends StatelessWidget {
  final List<BudgetProgress> budgets;
  // 1. AÑADIDO: Recibe el repositorio necesario.
  final BudgetRepository budgetRepository;

  const BudgetsSection({
    super.key,
    required this.budgets,
    required this.budgetRepository,
  });

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: EmptyStateCard(
          title: 'Crea tu Primer Presupuesto',
          message: 'Los presupuestos te ayudan a controlar tus gastos en categorías clave.',
          icon: Iconsax.additem,
          actionButton: ElevatedButton.icon(
            icon: const Icon(Iconsax.add),
            label: const Text('Crear Presupuesto'),
            onPressed: () {
              // 2. CORREGIDO: Pasamos el repositorio a la pantalla.
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => BudgetsScreen(repository: budgetRepository)),
              );
            },
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        _buildBudgetsList(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tus Presupuestos',
            style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleLarge, fontWeight: FontWeight.bold),
          ),
          TextButton.icon(
            icon: const Icon(Iconsax.arrow_right_3, size: 16),
            label: const Text('Ver Todos'),
            onPressed: () {
              // 2. CORREGIDO: Pasamos el repositorio a la pantalla.
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => BudgetsScreen(repository: budgetRepository)),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetsList(BuildContext context) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(), 
        itemCount: budgets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final budget = budgets[index];
          return SizedBox(
            width: 220,
            child: BudgetCard(
              budget: budget,
              onTap: () {
                // Navegamos a la pantalla completa, que mostrará este presupuesto entre otros.
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => BudgetsScreen(repository: budgetRepository)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}