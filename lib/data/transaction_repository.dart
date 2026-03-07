// lib/data/transaction_repository.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'dart:developer' as developer;

class TransactionRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<Transaction>>.broadcast();
  RealtimeChannel? _channel;

  TransactionRepository._internal();
  static final TransactionRepository instance = TransactionRepository._internal();

  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ TransactionRepository inicializado PEREZOSAMENTE.',
          name: 'TransactionRepository');
    }
  }

  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception(
          '¡ERROR FATAL! Supabase no está disponible para TransactionRepository.');
    }
    return _supabase!;
  }

  // --- MÉTODOS PÚBLICOS ---

  Stream<List<Transaction>> getTransactionsStream() {
    _fetchAndPushTransactions();
    return _streamController.stream;
  }

  Future<void> refreshData() => _fetchAndPushTransactions();

  Future<void> addTransaction({
    required String accountId,
    required double amount,
    required String type,
    required String category,
    required String description,
    required DateTime transactionDate,
    int? budgetId,
    TransactionMood? mood,
    String? locationName,
    double? latitude,
    double? longitude,
    String? creditCardId,
    int? installmentsTotal,
    int? installmentsCurrent,
    bool isInstallment = false,
    bool isInterestFree = false,
  }) async {
    try {
      await client.from('transactions').insert({
        'user_id':             client.auth.currentUser!.id,
        'account_id':          accountId,
        'amount':              amount,
        'type':                type,
        'category':            category,
        'description':         description,
        'transaction_date':    transactionDate.toIso8601String(),
        'budget_id':           budgetId,
        'mood':                mood?.name,
        'location_name':       locationName,
        'latitude':            latitude,
        'longitude':           longitude,
        'credit_card_id':      creditCardId,
        'installments_total':  installmentsTotal,
        'installments_current': installmentsCurrent,
        'is_installment':      isInstallment,
        'is_interest_free':    isInterestFree,
      });
      developer.log('✅ Transacción guardada (Cuotas: $isInstallment)',
          name: 'TransactionRepository');
    } catch (e) {
      developer.log('🔥 Error al añadir transacción: $e',
          name: 'TransactionRepository');
      throw Exception('No se pudo añadir la transacción.');
    }
  }

  Future<void> payInstallment({
    required Transaction originalTransaction,
    required String paymentSourceAccountId,
  }) async {
    if (originalTransaction.installmentsCurrent! >
        originalTransaction.installmentsTotal!) {
      throw Exception('Esta deuda ya está pagada.');
    }

    final installmentAmount =
        originalTransaction.amount.abs() / originalTransaction.installmentsTotal!;

    await addTransaction(
      accountId:       paymentSourceAccountId,
      amount:          -installmentAmount,
      type:            'Gasto',
      category:        'Pago Tarjeta',
      description:
          'Pago cuota ${originalTransaction.installmentsCurrent} de: ${originalTransaction.description}',
      transactionDate: DateTime.now(),
      isInstallment:   false,
    );

    await client.from('transactions').update({
      'installments_current': originalTransaction.installmentsCurrent! + 1,
    }).eq('id', originalTransaction.id);

    developer.log('✅ Cuota pagada y avanzada', name: 'TransactionRepository');

    try {
      await widget_service.WidgetService.updateNextPaymentWidget();
      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
    } catch (e) {
      developer.log('⚠️ Error actualizando widgets tras pago de cuota: $e',
          name: 'TransactionRepository');
    }
  }

  Future<void> updateInstallmentProgress({
    required int transactionId,
    required int currentInstallment,
    required int totalInstallments,
  }) async {
    try {
      await client.from('transactions').update({
        'installments_current': currentInstallment,
        'installments_total':   totalInstallments,
      }).eq('id', transactionId);

      developer.log(
          '✅ Progreso de cuotas actualizado para ID: $transactionId',
          name: 'TransactionRepository');

      await widget_service.WidgetService.updateNextPaymentWidget();
      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
    } catch (e) {
      developer.log('🔥 Error al actualizar progreso de cuotas: $e',
          name: 'TransactionRepository');
      throw Exception('No se pudo actualizar el progreso de la cuota.');
    }
  }

  // ── updateTransaction ────────────────────────────────────────────────────
  // Cambios respecto al original:
  //
  // 1. Parámetros de ubicación des-comentados y añadidos a la firma:
  //    locationName, latitude, longitude — opcionales (nullable).
  //
  // 2. Se pasan a la RPC update_transaction_and_relational_data como
  //    p_new_location_name, p_new_latitude, p_new_longitude.
  //    Si la RPC aún no tiene esos parámetros → añadirlos en Supabase SQL
  //    (ver comentario al final del archivo).
  //
  // 3. Nada más cambia — amount sigue comentado porque la RPC no lo soporta.

  Future<void> updateTransaction({
    required int      transactionId,
    required String   accountId,
    required String   type,
    required String   category,
    required String   description,
    required DateTime transactionDate,
    TransactionMood?  mood,
    // Ubicación — ahora activos
    String?  locationName,
    double?  latitude,
    double?  longitude,
  }) async {
    try {
      await client.rpc('update_transaction_and_relational_data', params: {
        'p_transaction_id':       transactionId,
        'p_new_account_id':       accountId,
        'p_new_type':             type,
        'p_new_category':         category,
        'p_new_description':      description,
        'p_new_mood':             mood?.name,
        'p_new_transaction_date': transactionDate.toIso8601String(),
        // Ubicación — pasan null si el usuario no seleccionó ninguna,
        // lo que limpia el valor previo en la BD (comportamiento correcto).
        'p_new_location_name':    locationName,
        'p_new_latitude':         latitude,
        'p_new_longitude':        longitude,
      });

      developer.log(
          '✅ [Repo] Transacción $transactionId actualizada con éxito vía RPC.',
          name: 'TransactionRepository');

      await widget_service.WidgetService.updateNextPaymentWidget();
      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
    } catch (e) {
      developer.log('🔥 Error al actualizar transacción vía RPC: $e',
          name: 'TransactionRepository');
      throw Exception('No se pudo actualizar la transacción.');
    }
  }

  Future<void> deleteTransaction(int transactionId) async {
    try {
      await client.from('transactions').delete().eq('id', transactionId);
      developer.log('✅ Transacción eliminada: $transactionId',
          name: 'TransactionRepository');

      await widget_service.WidgetService.updateNextPaymentWidget();
      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
    } catch (e) {
      developer.log('🔥 Error al eliminar transacción: $e',
          name: 'TransactionRepository');
      throw Exception('No se pudo eliminar la transacción.');
    }
  }

  Future<List<Transaction>> getTransactionsForBudget(String budgetId) async {
    developer.log(
        '🔄 [Repo] Obteniendo transacciones para el presupuesto ID: $budgetId',
        name: 'TransactionRepository');
    try {
      final int budgetIdAsInt = int.parse(budgetId);
      final response = await client
          .from('transactions')
          .select()
          .eq('budget_id', budgetIdAsInt)
          .order('transaction_date', ascending: false);
      final transactions =
          response.map((data) => Transaction.fromMap(data)).toList();
      developer.log(
          '✅ [Repo] Encontradas ${transactions.length} transacciones para el presupuesto $budgetIdAsInt.',
          name: 'TransactionRepository');
      return transactions;
    } on FormatException {
      developer.log(
          '⚠️ [Repo] budgetId "$budgetId" no es un número válido. Devolviendo lista vacía.',
          name: 'TransactionRepository');
      return [];
    } catch (e, stackTrace) {
      developer.log(
          '🔥 [Repo] ERROR obteniendo transacciones de presupuesto: $e',
          name: 'TransactionRepository',
          error: e,
          stackTrace: stackTrace);
      throw Exception('Error al conectar con la base de datos.');
    }
  }

  Stream<List<Transaction>> getTransactionsStreamForBudget(int budgetId) {
    developer.log(
        '📡 [Repo] Suscribiéndose al stream de transacciones para el presupuesto ID: $budgetId',
        name: 'TransactionRepository');
    try {
      return client
          .from('transactions')
          .stream(primaryKey: ['id'])
          .eq('budget_id', budgetId)
          .order('transaction_date', ascending: false)
          .map((listOfMaps) {
            final transactions =
                listOfMaps.map((data) => Transaction.fromMap(data)).toList();
            developer.log(
                '✅ [Repo] Stream del presupuesto $budgetId actualizado con ${transactions.length} elementos.',
                name: 'TransactionRepository');
            return transactions;
          });
    } catch (e) {
      developer.log(
          '🔥 [Repo] Error al crear el stream para el presupuesto $budgetId: $e',
          name: 'TransactionRepository');
      return Stream.value([]);
    }
  }

  Future<List<Transaction>> getFilteredTransactions({
    String?        searchQuery,
    List<String>?  categoryFilter,
    DateTimeRange? dateRange,
  }) async {
    var query = client
        .from('transactions')
        .select()
        .eq('user_id', client.auth.currentUser!.id);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final queryFilter = '%$searchQuery%';
      query = query
          .or('description.ilike.$queryFilter,category.ilike.$queryFilter');
    }

    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      query = query.inFilter('category', categoryFilter);
    }

    if (dateRange != null) {
      query = query.gte(
          'transaction_date', dateRange.start.toIso8601String());
      final endOfDay = DateTime(dateRange.end.year, dateRange.end.month,
          dateRange.end.day, 23, 59, 59);
      query = query.lte(
          'transaction_date', endOfDay.toIso8601String());
    }

    final response =
        await query.order('transaction_date', ascending: false);
    return response.map((data) => Transaction.fromMap(data)).toList();
  }

  Future<Transaction?> getTransactionById(int transactionId) async {
    try {
      final response = await client
          .from('transactions')
          .select()
          .eq('id', transactionId)
          .single();
      return Transaction.fromMap(response);
    } catch (e) {
      developer.log(
          '🔥 Error obteniendo transacción por id $transactionId: $e',
          name: 'TransactionRepository');
      return null;
    }
  }

  void dispose() {
    developer.log(
        '❌ [Repo] Liberando recursos de TransactionRepository.',
        name: 'TransactionRepository');
    if (_channel != null) {
      _supabase?.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }

  // --- MÉTODOS PRIVADOS ---

  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    developer.log(
        '📡 [Repo-Lazy] Configurando Realtime para Transacciones...',
        name: 'TransactionRepository');
    _channel = _supabase!
        .channel('public:transactions')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'transactions',
          filter: PostgresChangeFilter(
              type:   PostgresChangeFilterType.eq,
              column: 'user_id',
              value:  userId),
          callback: (payload) {
            developer.log(
                '🔔 [Repo] Realtime (TRANSACTIONS). Refrescando...',
                name: 'TransactionRepository');
            _fetchAndPushTransactions();
          },
        )
        .subscribe();
  }

  Future<void> _fetchAndPushTransactions() async {
    developer.log('🔄 [Repo] Obteniendo todas las transacciones...',
        name: 'TransactionRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final data = await client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('transaction_date', ascending: false);

      final transactions =
          (data as List).map((t) => Transaction.fromMap(t)).toList();

      if (!_streamController.isClosed) {
        _streamController.add(transactions);
        developer.log(
            '✅ [Repo] ${transactions.length} transacciones enviadas al stream.',
            name: 'TransactionRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo transacciones: $e',
          name: 'TransactionRepository');
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MIGRACIÓN REQUERIDA EN SUPABASE
// ─────────────────────────────────────────────────────────────────────────────
// La RPC update_transaction_and_relational_data necesita 3 parámetros nuevos.
// Ejecutar en el SQL Editor de Supabase:
//
// CREATE OR REPLACE FUNCTION update_transaction_and_relational_data(
//   p_transaction_id       INT,
//   p_new_account_id       UUID,
//   p_new_type             TEXT,
//   p_new_category         TEXT,
//   p_new_description      TEXT,
//   p_new_mood             TEXT    DEFAULT NULL,
//   p_new_transaction_date TIMESTAMPTZ,
//   p_new_location_name    TEXT    DEFAULT NULL,   -- NUEVO
//   p_new_latitude         FLOAT8  DEFAULT NULL,   -- NUEVO
//   p_new_longitude        FLOAT8  DEFAULT NULL    -- NUEVO
// )
// RETURNS VOID AS $$
// BEGIN
//   UPDATE transactions
//   SET
//     account_id       = p_new_account_id,
//     type             = p_new_type,
//     category         = p_new_category,
//     description      = p_new_description,
//     mood             = p_new_mood,
//     transaction_date = p_new_transaction_date,
//     location_name    = p_new_location_name,
//     latitude         = p_new_latitude,
//     longitude        = p_new_longitude
//   WHERE id = p_transaction_id
//     AND user_id = auth.uid();   -- seguridad RLS
// END;
// $$ LANGUAGE plpgsql SECURITY DEFINER;
// ─────────────────────────────────────────────────────────────────────────────