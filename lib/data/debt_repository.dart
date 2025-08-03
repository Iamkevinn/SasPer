// lib/data/debt_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:sasper/services/event_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/debt_model.dart';

class DebtRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---
  
  // 1. El cliente ahora es privado y nullable.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! DebtRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---
  
  DebtRepository._privateConstructor();
  static final DebtRepository instance = DebtRepository._privateConstructor();
  bool _isInitialized = false;

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] DebtRepository Singleton Initialized and Client Injected.', name: 'DebtRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

  Stream<List<Debt>> getDebtsStream() {
    developer.log('📡 [Repo] Subscribing to debts stream...', name: 'DebtRepository');
    try {
      final stream = client
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
      await client.rpc('create_debt_and_transaction', params: {
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

  Future<void> updateDebt({
    required String debtId,
    required String name,
    String? entityName,
    DateTime? dueDate,
  }) async {
    developer.log('🔄 [Repo] Updating debt: "$name"', name: 'DebtRepository');
    try {
      await client.from('debts').update({
        'name': name,
        'entity_name': entityName,
        'due_date': dueDate?.toIso8601String(),
      }).eq('id', debtId);
      
      developer.log('✅ [Repo] Debt updated successfully.', name: 'DebtRepository');
      EventService.instance.fire(AppEvent.debtsChanged);
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error updating debt: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo actualizar la deuda.');
    }
  }

  Future<void> deleteDebt(String debtId) async {
    developer.log('🗑️ [Repo] Deleting debt with id: $debtId', name: 'DebtRepository');
    try {
      await client.from('debts').delete().eq('id', debtId);
      
      developer.log('✅ [Repo] Debt deleted successfully.', name: 'DebtRepository');
      EventService.instance.fire(AppEvent.debtsChanged);
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error deleting debt: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
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
    developer.log('💸 [Repo] Registering payment of $paymentAmount for debt $debtId', name: 'DebtRepository');
    try {
      await client.rpc('register_debt_payment', params: {
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
  
  void dispose() {
    developer.log('❌ [Repo] Disposing DebtRepository resources.', name: 'DebtRepository');
    // La limpieza de los streams de Supabase con .stream() se maneja mejor
    // cancelando la suscripción al Stream en el widget que lo consume.
  }
}