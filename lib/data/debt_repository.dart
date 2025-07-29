// lib/data/debt_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/debt_model.dart';

class DebtRepository {
  // 1. El cliente se declara como 'late final'.
  late final SupabaseClient _client;
  
  // 2. Constructor privado.
  DebtRepository._privateConstructor();

  // 3. La instancia estática.
  static final DebtRepository instance = DebtRepository._privateConstructor();

  // 4. El método de inicialización.
  void initialize(SupabaseClient client) {
    _client = client;
    developer.log('✅ [Repo] DebtRepository Singleton Initialized and Client Injected.', name: 'DebtRepository');
  }

  /// Devuelve un Stream en tiempo real de la lista de deudas del usuario.
  Stream<List<Debt>> getDebtsStream() {
    developer.log('📡 [Repo] Subscribing to debts stream...', name: 'DebtRepository');
    try {
      // La seguridad se maneja con RLS en Supabase.
      final stream = _client
          .from('debts')
          .stream(primaryKey: ['id'])
          .order('due_date', ascending: true)
          .map((listOfMaps) {
        final debts = listOfMaps.map((data) => Debt.fromMap(data)).toList();
        developer.log('✅ [Repo] Debts stream updated with ${debts.length} items.', name: 'DebtRepository');
        return debts;
      });

      return stream.handleError((error, stackTrace) {
        developer.log('🔥 [Repo] Error in debts stream: $error', name: 'DebtRepository', error: error, stackTrace: stackTrace);
      });
    } catch (e) {
      developer.log('🔥 [Repo] Could not subscribe to debts stream: $e', name: 'DebtRepository');
      return Stream.value([]);
    }
  }

  /// Añade una nueva deuda y su transacción inicial asociada usando una RPC.
  Future<void> addDebtAndInitialTransaction({
    required String name,
    required DebtType type,
    String? entityName,
    required double amount,
    required String accountId,
    DateTime? dueDate,
    DateTime? transactionDate,
  }) async {
    developer.log('➕ [Repo] Adding new debt: "$name"', name: 'DebtRepository');
    try {
      await _client.rpc('create_debt_and_transaction', params: {
        'p_name': name,
        'p_type': type.name,
        'p_entity_name': entityName,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_due_date': dueDate?.toIso8601String(),
        'p_transaction_date': (transactionDate ?? DateTime.now()).toIso8601String(),
      });
      developer.log('✅ Debt and initial transaction created successfully.', name: 'DebtRepository');
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error adding debt: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo añadir la deuda. Por favor, inténtalo de nuevo.');
    }
  }

  /// Registra un pago o un cobro usando una RPC.
  Future<void> registerPayment({
    required String debtId,
    required DebtType debtType,
    required double paymentAmount,
    required String fromAccountId,
    String? description,
    DateTime? transactionDate,
  }) async {
    developer.log('💸 [Repo] Registering payment of $paymentAmount for debt $debtId', name: 'DebtRepository');
    try {
      await _client.rpc('register_debt_payment', params: {
        'p_debt_id': debtId,
        'p_payment_amount': paymentAmount,
        'p_account_id': fromAccountId,
        'p_debt_type': debtType.name,
        'p_description': description ?? (debtType == DebtType.debt ? 'Pago de deuda' : 'Cobro de préstamo'),
        'p_transaction_date': (transactionDate ?? DateTime.now()).toIso8601String(),
      });
      developer.log('✅ Payment registered successfully.', name: 'DebtRepository');
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error registering payment: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo registrar el pago. Por favor, inténtalo de nuevo.');
    }
  }
  
  // El método 'dispose' se puede mantener para la limpieza de recursos si es
  // necesario en un futuro, pero no se llamará desde los widgets.
  // Podría ser útil si tienes una lógica de "cierre de sesión" que
  // necesite desuscribirse de todos los streams.
  void dispose() {
    developer.log('❌ [Repo] Disposing DebtRepository resources. (Realtime channels might not be cleaned up with this pattern).', name: 'DebtRepository');
    // La limpieza de los streams de Supabase (`.from().stream()`) es un poco más compleja
    // y generalmente se maneja cancelando la suscripción al Stream en el widget que lo consume.
    // Para este patrón, la lógica de 'dispose' es menos crítica.
  }
}