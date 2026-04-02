// lib/data/simulation_repository.dart
//
// CAMBIOS vs original:
// · getExpenseSimulation() ahora enriquece el resultado de la RPC con
//   tres queries adicionales en Dart (metas, gastos fijos, deudas).
// · Todo en paralelo con Future.wait — sin latencia adicional perceptible.
// · Nada se inventa: cada campo proviene de una tabla real.

import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/simulation_models.dart';

class SimulationRepository {
  SimulationRepository._privateConstructor();
  static final SimulationRepository instance =
      SimulationRepository._privateConstructor();

  final _db = Supabase.instance.client;

  Future<SimulationResult> getExpenseSimulation({
    required double amount,
    required String categoryName,
  }) async {
    developer.log(
      '🧠 Simulando gasto de $amount en "$categoryName"',
      name: 'SimulationRepository',
    );

    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado.');

    try {
      // ── Todas las queries en paralelo ────────────────────────────────────
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        // 1. RPC principal
        _db.rpc('simulate_expense', params: {
          'p_user_id': userId,
          'p_amount': amount,
          'p_category': categoryName,
        }),

        // 2. Metas activas con savings_amount definido
        _db
            .from('goals')
            .select(
                'id, name, target_amount, current_amount, savings_amount, target_date')
            .eq('user_id', userId)
            .eq('status', 'active')
            .not('savings_amount', 'is', null)
            .gt('savings_amount', 0),

        // 3. Gastos fijos pendientes este mes
        _db
            .from('recurring_transactions')
            .select('description, amount, next_due_date')
            .eq('user_id', userId)
            .eq('type', 'Gasto')
            .eq('status', 'active')
            .gte('next_due_date', _firstOfMonth())
            .lte('next_due_date', _lastOfMonth())
            .order('next_due_date'),

        // 4. Deudas activas
        _db
            .from('debts')
            .select('current_balance')
            .eq('user_id', userId)
            .eq('status', 'active')
            .eq('type', 'debt'), 
      ]);

      // ── Parsear RPC ───────────────────────────────────────────────────────
      final base = SimulationResult.fromMap(
          results[0] as Map<String, dynamic>);

      // ── Parsear metas afectadas ───────────────────────────────────────────
      final goalsRaw = results[1] as List<dynamic>;
      final goals = goalsRaw
          .map((r) {
            final map = r as Map<String, dynamic>;
            return GoalImpact(
              goalId: map['id'] as String,
              goalName: map['name'] as String,
              targetAmount: (map['target_amount'] as num).toDouble(),
              currentAmount: (map['current_amount'] as num).toDouble(),
              savingsAmount: (map['savings_amount'] as num?)?.toDouble(),
              targetDate: map['target_date'] != null
                  ? DateTime.tryParse(map['target_date'] as String)
                  : null,
              expenseAmount: amount,
            );
          })
          .where((g) => g.isSignificant) // solo las que realmente importan
          .take(3)                        // máximo 3 para la UI
          .toList();

      // ── Parsear gastos fijos ──────────────────────────────────────────────
      final recurringRaw = results[2] as List<dynamic>;
      final recurringItems = recurringRaw.map((r) {
        final map = r as Map<String, dynamic>;
        return RecurringItem(
          description: map['description'] as String,
          amount: (map['amount'] as num).toDouble().abs(),
          nextDueDate: DateTime.parse(map['next_due_date'] as String),
        );
      }).toList();

      final pendingSum =
          recurringItems.fold<double>(0, (s, i) => s + i.amount);

      final recurring = RecurringContext(
        pendingThisMonth: pendingSum,
        count: recurringItems.length,
        items: recurringItems.take(3).toList(),
      );

      // ── Parsear deudas ────────────────────────────────────────────────────
      final debtsRaw = results[3] as List<dynamic>;
      final debtTotal = debtsRaw.fold<double>(
          0, (s, r) => s + ((r['current_balance'] as num).toDouble()));

      final debt = DebtContext(
        totalBalance: debtTotal,
        count: debtsRaw.length,
      );

      final enriched = base.withContext(
        goals: goals,
        recurring: recurring,
        debt: debt,
      );

      developer.log(
        '✅ Simulación completa — metas: ${goals.length}, '
        'fijos: ${recurring.count}, deudas: ${debt.count}',
        name: 'SimulationRepository',
      );

      return enriched;
    } on PostgrestException catch (e) {
      developer.log('🔥 Postgrest: ${e.message}', name: 'SimulationRepository');
      throw Exception(
          'No se pudo completar el análisis. ¿Tienes un presupuesto activo para esta categoría?');
    } catch (e) {
      developer.log('🔥 Error: $e', name: 'SimulationRepository');
      throw Exception('Ocurrió un error inesperado al realizar el análisis.');
    }
  }

  // ── Helpers de fecha ──────────────────────────────────────────────────────
  String _firstOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1).toIso8601String();
  }

  String _lastOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();
  }
}