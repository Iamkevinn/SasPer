// lib/widgets/dashboard/budgets_section.dart (REESTRUCTURADO Y FINAL)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/budget_details_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/widgets/shared/budget_card.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

class BudgetsSection extends StatelessWidget {
  final List<BudgetProgress> budgets;
  final BudgetRepository budgetRepository;
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;

  const BudgetsSection({
    super.key,
    required this.budgets,
    required this.budgetRepository,
    required this.transactionRepository,
    required this.accountRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // El header se mantiene igual.
        _buildHeader(context),
        
        // El contenido cambia.
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
                  builder: (context) =>
                      BudgetsScreen(repository: budgetRepository)));
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
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) =>
                    BudgetsScreen(repository: budgetRepository)));
          },
        ),
      ),
    );
  }

  // --- MÉTODO RECONSTRUIDO PARA SER A PRUEBA DE ERRORES DE LAYOUT ---
  Widget _buildBudgetsList(BuildContext context) {
    return SizedBox(
      // Definimos una altura explícita para el contenedor de la lista.
      // Esto es crucial para que el ListView.builder horizontal funcione dentro de un Column/Sliver.
      height: 140.0, 
      child: ListView.builder(
        // Añadimos padding aquí, no en el header.
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        // Usamos itemCount para construir solo los widgets visibles.
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          final budget = budgets[index];
          
          // Envolvemos cada tarjeta en un contenedor con un ancho fijo.
          // Esto ayuda a Flutter a calcular el layout de la lista horizontal.
          return Container(
            width: 220, // Ancho fijo para cada tarjeta de presupuesto
            margin: const EdgeInsets.only(right: 12.0), // Espacio entre tarjetas
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BudgetDetailsScreen(
                      budgetProgress: budget,
                      transactionRepository: transactionRepository,
                    ),
                  ),
                );
              },
              child: BudgetCard(budget: budget),
            ),
          );
        },
      ),
    );
  }
}