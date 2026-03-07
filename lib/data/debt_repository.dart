// lib/data/debt_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:sasper/services/event_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/debt_model.dart';

class DebtRepository {
  SupabaseClient? _supabase;
  bool _isInitialized = false;

  DebtRepository._internal();
  static final DebtRepository instance = DebtRepository._internal();

  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      developer.log('✅ DebtRepository inicializado PEREZOSAMENTE.', name: 'DebtRepository');
    }
  }

  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para DebtRepository.");
    }
    return _supabase!;
  }

  Stream<List<Debt>> getDebtsStream() {
    developer.log('📡 [Repo] Suscribiéndose al stream de deudas...', name: 'DebtRepository');
    try {
      final stream = client
          .from('debts')
          .stream(primaryKey: ['id'])
          .order('due_date', ascending: true)
          .map((listOfMaps) {
            final debts = listOfMaps.map((data) => Debt.fromMap(data)).toList();
            developer.log('✅ [Repo] Stream de deudas actualizado con ${debts.length} elementos.', name: 'DebtRepository');
            return debts;
          });

      return stream.handleError((error, stackTrace) {
        developer.log('🔥 [Repo] Error en el stream de deudas: $error', name: 'DebtRepository', error: error, stackTrace: stackTrace);
        throw Exception('No se pudieron cargar las deudas en tiempo real.');
      });
    } catch (e) {
      developer.log('🔥 [Repo] No se pudo suscribir al stream de deudas: $e', name: 'DebtRepository');
      return Stream.value([]);
    }
  }

  Future<List<Debt>> getDebtsWithSpendingFunds() async {
    developer.log('🔍 [Repo] Buscando deudas con fondos disponibles...', name: 'DebtRepository');
    try {
      final response = await client
          .from('debts')
          .select()
          .gt('spending_fund', 0)
          .eq('status', 'active');

      final debts = (response as List).map((data) => Debt.fromMap(data)).toList();
      developer.log('✅ [Repo] Encontradas ${debts.length} deudas con fondos.', name: 'DebtRepository');
      return debts;
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error buscando deudas con fondos: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<List<Debt>> getActiveDebts() async {
    developer.log('⏳ [Repo] Obteniendo deudas activas...', name: 'DebtRepository');
    try {
      final response = await client
          .from('debts')
          .select()
          .eq('status', 'active');

      final debts = (response as List).map((data) => Debt.fromMap(data)).toList();
      developer.log('✅ [Repo] Obtenidas ${debts.length} deudas activas.', name: 'DebtRepository');
      return debts;
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error obteniendo deudas activas: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> addDebtAndInitialTransaction({
    required String name,
    required DebtType type,
    String? entityName,
    required double amount,
    required String accountId,
    DateTime? dueDate,
    DateTime? transactionDate,
    required DebtImpactType impactType,
  }) async {
    developer.log('➕ [Repo] Añadiendo nueva deuda: "$name" con impacto ${impactType.name}', name: 'DebtRepository');
    try {
      await client.rpc('create_debt_and_transaction', params: {
        'p_name': name,
        'p_type': type.name,
        'p_entity_name': entityName,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_due_date': dueDate?.toIso8601String(),
        'p_transaction_date': (transactionDate ?? DateTime.now()).toIso8601String(),
        'p_impact_type': impactType.name,
      });
      developer.log('✅[Repo] Deuda y transacción inicial creadas con éxito.', name: 'DebtRepository');
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error añadiendo deuda: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo añadir la deuda. Por favor, inténtalo de nuevo.');
    }
  }

  Future<double> getTotalDebtForEntity(String entityName) async {
    try {
      final data = await client
          .from('debts')
          .select('type, current_balance')
          .eq('entity_name', entityName)
          .eq('status', 'active');

      double totalBalance = 0.0;
      for (var item in data) {
        final debtType = item['type'] == 'debt' ? DebtType.debt : DebtType.loan;
        final remainingAmount = (item['current_balance'] as num).toDouble();
        if (debtType == DebtType.loan) {
          totalBalance += remainingAmount;
        } else {
          totalBalance -= remainingAmount;
        }
      }
      return totalBalance;
    } catch (e) {
      if (kDebugMode) {
        print('Error al calcular la deuda total por entidad: $e');
      }
      throw Exception('No se pudo calcular la deuda de la entidad.');
    }
  }

  /// Actualiza los detalles de una deuda existente.
  Future<void> updateDebt({
    required String debtId,
    required String name,
    String? entityName,
    DateTime? dueDate,
    DebtImpactType? impactType,
  }) async {
    developer.log('[Repo] Actualizando deuda: "$name" | impactType: ${impactType?.name}', name: 'DebtRepository');
    try {
      await client.from('debts').update({
        'name': name,
        'entity_name': entityName,
        'due_date': dueDate?.toIso8601String(),
        'impact_type': (impactType ?? DebtImpactType.liquid).name,
      }).eq('id', debtId);

      developer.log('✅ [Repo] Deuda actualizada con éxito.', name: 'DebtRepository');
      EventService.instance.fire(AppEvent.debtsChanged);
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error actualizando deuda: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo actualizar la deuda.');
    }
  }

  Future<void> deleteDebt(String debtId) async {
    developer.log('🗑️ [Repo] Eliminando deuda con id: $debtId', name: 'DebtRepository');
    try {
      await client.from('debts').delete().eq('id', debtId);

      developer.log('✅ [Repo] Deuda eliminada con éxito.', name: 'DebtRepository');
      EventService.instance.fire(AppEvent.debtsChanged);
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error eliminando deuda: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo eliminar la deuda.');
    }
  }

  Future<void> registerPayment({
    required String debtId,
    required DebtType debtType,
    required double paymentAmount,
    required String fromAccountId,
    String? description,
    DateTime? transactionDate,
  }) async {
    developer.log('💸 [Repo] Registrando pago de $paymentAmount para la deuda $debtId', name: 'DebtRepository');
    try {
      await client.rpc('register_debt_payment', params: {
        'p_debt_id': debtId,
        'p_payment_amount': paymentAmount,
        'p_account_id': fromAccountId,
        'p_debt_type': debtType.name,
        'p_description': description ?? (debtType == DebtType.debt ? 'Pago de deuda' : 'Cobro de préstamo'),
        'p_transaction_date': (transactionDate ?? DateTime.now()).toIso8601String(),
      });
      developer.log('✅ [Repo] Pago registrado con éxito.', name: 'DebtRepository');
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error registrando pago: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo registrar el pago. Por favor, inténtalo de nuevo.');
    }
  }

  void dispose() {
    developer.log('ℹ️ [Repo] DebtRepository no requiere dispose explícito de canales de stream.', name: 'DebtRepository');
  }

  Future<void> addTransactionFromDebtFund({
    required String accountId,
    required double amount,
    required String description,
    required String category,
    required String debtId,
    DateTime? transactionDate,
  }) async {
    developer.log('💸 [Repo] Registrando gasto desde fondo de préstamo ($debtId)...', name: 'DebtRepository');
    try {
      await client.rpc('register_expense_from_fund', params: {
        'p_account_id': accountId,
        'p_amount': amount,
        'p_description': description,
        'p_category': category,
        'p_debt_id': debtId,
        'p_transaction_date': (transactionDate ?? DateTime.now()).toIso8601String(),
      });
      developer.log('✅ [Repo] Gasto registrado y fondo descontado con éxito.', name: 'DebtRepository');
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error registrando gasto de fondo: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo registrar el gasto del préstamo.');
    }
  }
}