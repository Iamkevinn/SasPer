// lib/services/debt_service.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/services/event_service.dart'; // Para notificar cambios

class DebtService {
  final SupabaseClient _client;

  // 1. Inyección de dependencias para facilitar los tests
  DebtService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  /// Devuelve un Stream en tiempo real de la lista de deudas del usuario.
  /// Es la forma recomendada para que la UI se mantenga sincronizada.
  Stream<List<Debt>> getDebtsStream() {
    developer.log('📡 [Service] Subscribing to debts stream...', name: 'DebtService');
    try {
      // El filtrado por user_id se hace con Row-Level Security (RLS) en Supabase.
      return _client
          .from('debts')
          .stream(primaryKey: ['id'])
          .order('due_date', ascending: true)
          .map((listOfMaps) {
            // Convertimos la lista de mapas en una lista de objetos Debt
            final debts = listOfMaps.map((data) => Debt.fromMap(data)).toList();
            developer.log('✅ [Service] Debts stream updated with ${debts.length} items.', name: 'DebtService');
            return debts;
          })
          .handleError((error, stackTrace) { // 2. Manejo de errores dentro del stream
            developer.log('🔥 [Service] Error in debts stream: $error', name: 'DebtService', error: error, stackTrace: stackTrace);
            // Podrías emitir una lista vacía o un evento de error específico
          });
    } catch (e) {
      developer.log('🔥 [Service] Could not subscribe to debts stream: $e', name: 'DebtService');
      return Stream.value([]); // Devuelve un stream con una lista vacía si falla la suscripción
    }
  }

  /// Añade una nueva deuda y su transacción inicial asociada.
  /// Lanza una excepción si la operación falla.
  Future<void> addDebtAndInitialTransaction({
    required String name,
    required DebtType type,
    String? entityName,
    required double amount,
    required String accountId,
    DateTime? dueDate,
  }) async {
    developer.log('➕ [Service] Adding new debt: "$name"', name: 'DebtService');
    try {
      // 3. Usamos la RPC que ya tienes para la lógica transaccional
      await _client.rpc('create_debt_and_transaction', params: {
        'p_name': name,
        'p_type': type.name, // 'debt' o 'loan'
        'p_entity_name': entityName,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_due_date': dueDate?.toIso8601String(),
      });
      developer.log('✅ Debt and initial transaction created successfully.', name: 'DebtService');
      // Notificamos a otras partes de la app que los datos han cambiado
      EventService.instance.fire(AppEvent.debtsChanged);
      EventService.instance.fire(AppEvent.transactionsChanged);

    } catch (e, stackTrace) {
      developer.log('🔥 [Service] Error adding debt: $e', name: 'DebtService', error: e, stackTrace: stackTrace);
      // 4. Re-lanzamos la excepción para que la UI pueda mostrar un error al usuario.
      throw Exception('No se pudo añadir la deuda. Por favor, inténtalo de nuevo.');
    }
  }

  /// Registra un pago (para una deuda) o un cobro (para un préstamo).
  /// Lanza una excepción si la operación falla.
  Future<void> registerPayment({
    required String debtId,
    required DebtType debtType,
    required double paymentAmount,
    required String fromAccountId,
    String? description, // La descripción puede ser opcional
  }) async {
    developer.log('💸 [Service] Registering payment of $paymentAmount for debt $debtId', name: 'DebtService');
    try {
      await _client.rpc('register_debt_payment', params: {
        'p_debt_id': debtId,
        'p_payment_amount': paymentAmount,
        'p_account_id': fromAccountId,
        'p_debt_type': debtType.name,
        'p_description': description ?? 'Pago de deuda',
      });
      developer.log('✅ Payment registered successfully.', name: 'DebtService');
      EventService.instance.fire(AppEvent.debtsChanged);
      EventService.instance.fire(AppEvent.transactionsChanged);

    } catch (e, stackTrace) {
      developer.log('🔥 [Service] Error registering payment: $e', name: 'DebtService', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo registrar el pago. Por favor, inténtalo de nuevo.');
    }
  }
}