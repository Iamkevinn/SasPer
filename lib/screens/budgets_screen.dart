import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'add_budget_screen.dart';

// Pantalla para mostrar y gestionar los presupuestos del mes actual
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final supabase = Supabase.instance.client;
  
  // Future para cargar los presupuestos y gastos del mes actual
  late Future<Map<String, dynamic>> _budgetsDataFuture;
  final int _currentMonth = DateTime.now().month;
  final int _currentYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _budgetsDataFuture = _fetchBudgetsAndExpenses();
  }

  // Función para obtener los presupuestos y los gastos totales por categoría
  Future<Map<String, dynamic>> _fetchBudgetsAndExpenses() async {
    final budgets = await supabase
        .from('budgets')
        .select()
        .eq('user_id', supabase.auth.currentUser!.id)
        .eq('month', _currentMonth)
        .eq('year', _currentYear);

    final expenses = await supabase
        .from('transactions')
        .select('category, amount')
        .eq('user_id', supabase.auth.currentUser!.id)
        .eq('type', 'Gasto')
        .gte('transaction_date', '$_currentYear-$_currentMonth-01')
        .lt('transaction_date', '$_currentYear-${_currentMonth + 1}-01');

    final Map<String, double> expensesByCategory = {};
    for (var expense in expenses) {
      final category = expense['category'] as String;
      final amount = (expense['amount'] as num).toDouble();
      expensesByCategory.update(category, (value) => value + amount, ifAbsent: () => amount);
    }
    
    return {'budgets': budgets, 'expenses': expensesByCategory};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Presupuestos de ${DateFormat.MMMM('es_ES').format(DateTime.now())}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _budgetsDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final budgets = snapshot.data!['budgets'] as List;
          final expenses = snapshot.data!['expenses'] as Map<String, double>;

          if (budgets.isEmpty) {
            return const Center(child: Text('No tienes presupuestos para este mes.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final category = budget['category'] as String;
              final budgetAmount = (budget['amount'] as num).toDouble();
              final spentAmount = expenses[category] ?? 0.0;
              final progress = (spentAmount / budgetAmount).clamp(0.0, 1.0);

              return _buildBudgetTile(category, budgetAmount, spentAmount, progress);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navegamos a la pantalla de añadir presupuesto
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
          );
          // Cuando volvemos, refrescamos los datos para mostrar el nuevo presupuesto
          setState(() {
            _budgetsDataFuture = _fetchBudgetsAndExpenses();
          });
        },
        child: const Icon(Iconsax.add),
      ),
    );
  }

  Widget _buildBudgetTile(String category, double budgetAmount, double spentAmount, double progress) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(NumberFormat.currency(symbol: '\$').format(spentAmount), style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(NumberFormat.currency(symbol: '\$').format(budgetAmount), style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.9 ? Colors.red : (progress > 0.7 ? Colors.orange : Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}