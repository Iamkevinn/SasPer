import 'package:flutter/material.dart';
import '../../models/budget_models.dart';
import '../../screens/budgets_screen.dart'; // Asegúrate que la ruta a tu BudgetsScreen sea correcta.
import '../shared/budget_card.dart'; // Crearemos este widget para reutilizar la tarjeta.

class BudgetsSection extends StatelessWidget {
  final List<BudgetProgress> budgets;

  const BudgetsSection({super.key, required this.budgets});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tus Presupuestos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const BudgetsScreen()),
                  );
                },
                child: const Text('Ver Todos'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return BudgetCard(budget: budgets[index]);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}