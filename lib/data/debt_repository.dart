// lib/data/debt_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';


import '../models/debt_model.dart';
// import '../services/event_service.dart'; // Ya no es necesario con streams reactivos

class DebtRepository {
  final SupabaseClient _client;
  
  // Guardamos la referencia al canal para poder desuscribirnos
  RealtimeChannel? _debtChannel;

  // Constructor con inyección de dependencias
  DebtRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Devuelve un Stream en tiempo real de la lista de deudas del usuario.
  /// La UI se actualizará automáticamente ante cualquier cambio (INSERT, UPDATE, DELETE).
  Stream<List<Debt>> getDebtsStream() {
    developer.log('📡 [Repo] Subscribing to debts stream...', name: 'DebtRepository');
    try {
      // El filtrado por user_id se hace con Row-Level Security (RLS) en Supabase.
      // Asegúrate de que RLS esté activado para la tabla 'debts'.
      final stream = _client
          .from('debts')
          .stream(primaryKey: ['id'])
          .order('due_date', ascending: true) // Las deudas con fecha aparecen primero
          .map((listOfMaps) {
            final debts = listOfMaps.map((data) => Debt.fromMap(data)).toList();
            developer.log('✅ [Repo] Debts stream updated with ${debts.length} items.', name: 'DebtRepository');
            return debts;
          });
          
      // No es posible guardar la referencia del canal directamente desde el stream.
      // Si necesitas gestionar el canal, deberás obtenerlo de otra manera.

      return stream.handleError((error, stackTrace) {
        developer.log('🔥 [Repo] Error in debts stream: $error', name: 'DebtRepository', error: error, stackTrace: stackTrace);
      });
    } catch (e) {
      developer.log('🔥 [Repo] Could not subscribe to debts stream: $e', name: 'DebtRepository');
      return Stream.value([]); // Devuelve un stream con una lista vacía si falla la suscripción
    }
  }
  
  /// Limpia los recursos (canales de Supabase) cuando ya no se necesiten.
  /// Es CRUCIAL llamar a este método en el `dispose` del widget que usa el stream.
  void dispose() {
    developer.log('❌ [Repo] Disposing DebtRepository resources.', name: 'DebtRepository');
    if (_debtChannel != null) {
      _client.removeChannel(_debtChannel!);
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
      });
      developer.log('✅ Debt and initial transaction created successfully.', name: 'DebtRepository');
      // No necesitamos disparar un evento, el stream de la tabla 'debts' lo detectará.
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
  }) async {
    developer.log('💸 [Repo] Registering payment of $paymentAmount for debt $debtId', name: 'DebtRepository');
    try {
      await _client.rpc('register_debt_payment', params: {
        'p_debt_id': debtId,
        'p_payment_amount': paymentAmount,
        'p_account_id': fromAccountId,
        'p_debt_type': debtType.name,
        'p_description': description ?? (debtType == DebtType.debt ? 'Pago de deuda' : 'Cobro de préstamo'),
      });
      developer.log('✅ Payment registered successfully.', name: 'DebtRepository');
      // El stream de 'debts' y 'transactions' lo detectará.
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error registering payment: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo registrar el pago. Por favor, inténtalo de nuevo.');
    }
  }
}