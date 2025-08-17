// lib/widgets/dashboard/budgets_section.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/budget_models.dart'; // ¡Importa el nuevo modelo `Budget`!
import 'package:sasper/screens/budget_details_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/widgets/shared/budget_card.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

class BudgetsSection extends StatelessWidget {
  // --- ¡CORRECCIÓN! El widget ahora recibe una lista de `Budget` ---
  final List<Budget> budgets;

  const BudgetsSection({
    super.key,
    required this.budgets,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        if (budgets.isEmpty)
          _buildEmptyState(context)
        else
          _buildBudgetsList(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tus Presupuestos',
            style: GoogleFonts.poppins(
                textStyle: Theme.of(context).textTheme.titleLarge,
                fontWeight: FontWeight.bold),
          ),
          TextButton(
            child: const Text('Ver Todos'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const BudgetsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: EmptyStateCard(
        title: 'Crea tu Primer Presupuesto',
        message: 'Los presupuestos te ayudan a controlar tus gastos.',
        icon: Iconsax.additem,
        actionButton: ElevatedButton.icon(
          icon: const Icon(Iconsax.add),
          label: const Text('Crear Presupuesto'),
          onPressed: () {
            // Navegamos a la pantalla de presupuestos para que el usuario pueda crear uno.
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const BudgetsScreen()));
          },
        ),
      ),
    );
  }

  Widget _buildBudgetsList(BuildContext context) {
    return SizedBox(
      height: 160.0, // Puedes ajustar esta altura según el diseño de tu nueva `BudgetCard`
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          final budget = budgets[index];
          
          return Container(
            width: 220, // Puedes ajustar el ancho
            margin: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    // --- ¡CORRECCIÓN! Usamos `budget.id` del nuevo modelo ---
                    builder: (context) => BudgetDetailsScreen(
                      budgetId: budget.id,
                    ),
                  ),
                );
              },
              // El `BudgetCard` ya fue refactorizado y aceptará `budget` sin problemas.
              child: BudgetCard(budget: budget),
            ),
          );
        },
      ),
    );
  }
}