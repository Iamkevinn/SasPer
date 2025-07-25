// lib/data/recurring_repository.dart (NUEVO ARCHIVO)

import 'dart:async';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class RecurringRepository {
  final SupabaseClient _client;
  // Usamos un StreamController para tener control explícito sobre el stream
  final _streamController = StreamController<List<RecurringTransaction>>.broadcast();
  RealtimeChannel? _subscriptionChannel;
  RecurringRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  /// Devuelve el stream que la UI escuchará.
  Stream<List<RecurringTransaction>> getRecurringTransactionsStream() {
    // Si la suscripción en tiempo real no se ha iniciado, la iniciamos.
    if (_subscriptionChannel == null) {
      _setupRealtimeSubscription();
    }
    // Hacemos una carga inicial de datos para que la UI no espere.
    _fetchAndPushData();
    return _streamController.stream;
  }

  /// Obtiene los datos de Supabase y los añade al StreamController.
  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Fetching recurring transactions...');
    try {
      final data = await _client
          .from('recurring_transactions')
          .select()
          .order('next_due_date', ascending: true);
          
      final transactions = (data as List).map((map) => RecurringTransaction.fromMap(map)).toList();
      
      if (!_streamController.isClosed) {
        _streamController.add(transactions);
      }
      developer.log('✅ [Repo] Pushed ${transactions.length} recurring items to stream.');
    } catch (e) {
      developer.log('🔥 [Repo] Error fetching recurring transactions: $e');
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }
  
  /// Configura la escucha de cambios en tiempo real en la tabla.
  void _setupRealtimeSubscription() {
    _subscriptionChannel = _client
        .channel('public:recurring_transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recurring_transactions',
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change detected in recurring_transactions. Refetching...');
            _fetchAndPushData();
          },
        )
        .subscribe();
  }

  /// Método público para forzar la recarga de datos desde la UI.
  Future<void> forceRefresh() async {
    developer.log('🔄 [Repo] Manual refresh requested for recurring transactions.');
    await _fetchAndPushData();
  }

  // ---- NUEVO MÉTODO PARA ACTUALIZAR ----
  Future<void> updateRecurringTransaction(RecurringTransaction transaction) async {
    developer.log('🔄 Actualizando gasto fijo ${transaction.id}');
    try {
      await _client
        .from('recurring_transactions')
        .update(transaction.toJson())
        .eq('id', transaction.id);
    } catch (e) {
      developer.log('🔥 Error actualizando gasto fijo: $e');
      throw Exception('No se pudo actualizar el gasto fijo.');
    }
  }

  Future<void> addRecurringTransaction({
    required String description,
    required double amount,
    required String type,
    required String category,
    required String accountId,
    required String frequency,
    required int interval,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      await _client.from('recurring_transactions').insert({
        'user_id': _client.auth.currentUser!.id,
        'description': description,
        'amount': amount,
        'type': type,
        'category': category,
        'account_id': accountId,
        'frequency': frequency,
        'interval': interval,
        'start_date': startDate.toIso8601String(),
        // La primera fecha de vencimiento es la fecha de inicio.
        'next_due_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });
    } catch (e) {
      developer.log('🔥 Error añadiendo transacción recurrente: $e');
      throw Exception('No se pudo crear el gasto fijo.');
    }
  }

  Future<void> deleteRecurringTransaction(String id) async {
    try {
      await _client.from('recurring_transactions').delete().eq('id', id);
    } catch (e) {
      developer.log('🔥 Error eliminando transacción recurrente: $e');
      throw Exception('No se pudo eliminar el gasto fijo.');
    }
  }

  /// Limpia el StreamController y la suscripción para evitar fugas de memoria.
  void dispose() {
    developer.log('❌ [Repo] Disposing RecurringRepository resources.');
    if (_subscriptionChannel != null) {
      _client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _streamController.close();
  }

}