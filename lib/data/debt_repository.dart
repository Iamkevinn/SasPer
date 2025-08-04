// lib/data/debt_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:sasper/services/event_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/debt_model.dart';

class DebtRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // Constructor privado para forzar el uso del Singleton `instance`.
  DebtRepository._internal();
  static final DebtRepository instance = DebtRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      developer.log('✅ DebtRepository inicializado PEREZOSAMENTE.', name: 'DebtRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para DebtRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient supabaseClient) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de todas las deudas del usuario.
  Stream<List<Debt>> getDebtsStream() {
    developer.log('📡 [Repo] Suscribiéndose al stream de deudas...', name: 'DebtRepository');
    try {
      // Usa el getter `client` que asegura la inicialización.
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
        // Devolvemos el error en el stream para que la UI pueda reaccionar.
        throw Exception('No se pudieron cargar las deudas en tiempo real.');
      });
    } catch (e) {
      developer.log('🔥 [Repo] No se pudo suscribir al stream de deudas: $e', name: 'DebtRepository');
      return Stream.value([]);
    }
  }

  /// Obtiene una lista de deudas activas (llamada única).
  /// Ideal para operaciones de fondo como la actualización de widgets.
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
      return []; // Devolver lista vacía en caso de error para no romper la lógica que lo llama.
    }
  }

  /// Llama a un RPC para crear una deuda y su transacción inicial.
  Future<void> addDebtAndInitialTransaction({
    required String name,
    required DebtType type,
    String? entityName,
    required double amount,
    required String accountId,
    DateTime? dueDate,
    DateTime? transactionDate,
  }) async {
    developer.log('➕ [Repo] Añadiendo nueva deuda: "$name"', name: 'DebtRepository');
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
      developer.log('✅ [Repo] Deuda y transacción inicial creadas con éxito.', name: 'DebtRepository');
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error añadiendo deuda: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo añadir la deuda. Por favor, inténtalo de nuevo.');
    }
  }

  /// Actualiza los detalles de una deuda existente.
  Future<void> updateDebt({
    required String debtId,
    required String name,
    String? entityName,
    DateTime? dueDate,
  }) async {
    developer.log('🔄 [Repo] Actualizando deuda: "$name"', name: 'DebtRepository');
    try {
      await client.from('debts').update({
        'name': name,
        'entity_name': entityName,
        'due_date': dueDate?.toIso8601String(),
      }).eq('id', debtId);
      
      developer.log('✅ [Repo] Deuda actualizada con éxito.', name: 'DebtRepository');
      EventService.instance.fire(AppEvent.debtsChanged);
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error actualizando deuda: $e', name: 'DebtRepository', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo actualizar la deuda.');
    }
  }

  /// Elimina una deuda.
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
  
  /// Llama a un RPC para registrar un pago a una deuda.
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
  
  /// El método `dispose` no es necesario en este patrón, ya que el cliente de Supabase
  /// gestiona sus propios canales. La suscripción al stream debe ser cancelada en el
  /// `dispose` del `StatefulWidget` que la consume.
  void dispose() {
    developer.log('ℹ️ [Repo] DebtRepository no requiere dispose explícito de canales de stream.', name: 'DebtRepository');
  }
}