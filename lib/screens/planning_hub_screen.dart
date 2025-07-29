// lib/screens/planning_hub_screen.dart (VERSIÓN FINAL REFACtoRIZADA CON SINGLETONS)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
//import 'package:sasper/data/account_repository.dart';
//import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/screens/accounts_screen.dart';
import 'package:sasper/screens/analysis_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/screens/debts_screen.dart';
import 'package:sasper/screens/goals_screen.dart';
import 'package:sasper/screens/recurring_transactions_screen.dart';

class PlanningHubScreen extends StatelessWidget {
  // El constructor ahora es simple y constante. No recibe ningún parámetro.
  const PlanningHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Planificación y Gestión', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHubCard(
            context,
            icon: Iconsax.wallet_3,
            title: 'Cuentas',
            subtitle: 'Administra tu efectivo, bancos y tarjetas.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              // Las pantallas de destino ahora son 'const', ya que no necesitan
              // recibir ningún repositorio. Ellas mismas obtendrán los Singletons.
              builder: (_) => const AccountsScreen(),
            )),
          ),
          _buildHubCard(
            context,
            icon: Iconsax.money_tick,
            title: 'Presupuestos',
            subtitle: 'Controla tus gastos mensuales por categoría.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const BudgetsScreen(),
            )),
          ),
          _buildHubCard(
            context,
            icon: Iconsax.flag,
            title: 'Metas de Ahorro',
            subtitle: 'Alcanza tus objetivos financieros a corto y largo plazo.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const GoalsScreen(),
            )),
          ),
          _buildHubCard(
            context,
            icon: Iconsax.receipt_2_1,
            title: 'Deudas y Préstamos',
            subtitle: 'Administra y liquida tus deudas de forma eficiente.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const DebtsScreen(),
            )),
          ),
          _buildHubCard(
            context,
            icon: Iconsax.chart_1,
            title: 'Análisis e Informes',
            subtitle: 'Entiende a fondo a dónde se va tu dinero.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AnalysisScreen(),
            )),
          ),
          _buildHubCard(
            context,
            icon: Iconsax.repeat,
            title: 'Gastos Fijos',
            subtitle: 'Automatiza tus ingresos y gastos recurrentes.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RecurringTransactionsScreen(),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Iconsax.arrow_right_3, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}