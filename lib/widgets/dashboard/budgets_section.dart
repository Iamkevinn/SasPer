// lib/widgets/dashboard/budgets_section.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/widgets/shared/budget_card.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart'; // Importamos el empty state

class BudgetsSection extends StatelessWidget {
  final List<BudgetProgress> budgets;

  const BudgetsSection({super.key, required this.budgets});

  @override
  Widget build(BuildContext context) {
    // 1. MANEJO DEL ESTADO VACÍO
    // Si no hay presupuestos, mostramos una tarjeta especial en lugar de la sección.
    if (budgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: EmptyStateCard(
          title: 'Crea tu Primer Presupuesto',
          message: 'Los presupuestos te ayudan a controlar tus gastos en categorías clave.',
          icon: Iconsax.additem,
          actionButton: ElevatedButton(
            onPressed: () {
              // Navegar a la pantalla para AÑADIR un presupuesto
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BudgetsScreen()), // O a AddBudgetScreen
              );
            },
            child: const Text('Crear Presupuesto'),
          ),
        ),
      );
    }
    
    // Si hay presupuestos, construimos la sección normal.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        _buildBudgetsList(context),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- WIDGETS HELPER PARA MEJORAR LA ESTRUCTURA ---

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12), // Ajustamos el padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tus Presupuestos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          // 2. MEJORA VISUAL OPCIONAL del botón
          TextButton.icon(
            icon: const Icon(Iconsax.arrow_right_3, size: 16),
            label: const Text('Ver Todos'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const BudgetsScreen()),
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
      height: 150, // Un poco más de altura para que la tarjeta "respire"
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        // Añadimos un efecto de "overscroll" más natural
        physics: const BouncingScrollPhysics(), 
        itemCount: budgets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final budget = budgets[index];
          // 3. ENVOLVEMOS LA TARJETA en un SizedBox para darle el tamaño
          return SizedBox(
            width: 220,
            child: BudgetCard(
              budget: budget,
              onTap: () {
                // Navegar a los detalles de este presupuesto específico
                // Navigator.of(context).push(...);
              },
            ),
          );
        },
      ),
    );
  }
}