// lib/data/recurring_repository.dart (VERSIÓN FINAL CON PATRÓN SINGLETON)

import 'dart:async';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class RecurringRepository {
  final SupabaseClient _client;
  final _streamController = StreamController<List<RecurringTransaction>>.broadcast();
  RealtimeChannel? _channel;

  // 1. CONSTRUCTOR PRIVADO: Asegura que nadie pueda crear una instancia con 'new'.
  RecurringRepository._internal() : _client = Supabase.instance.client {
    developer.log('✅ [Repo] RecurringRepository Singleton Initialized.', name: 'RecurringRepository');
  }

  // 2. INSTANCIA ESTÁTICA PRIVADA: La única instancia que existirá en toda la app.
  static final RecurringRepository _instance = RecurringRepository._internal();

  // 3. GETTER PÚBLICO ESTÁTICO: La forma estandarizada de acceder a la única instancia.
  static RecurringRepository get instance => _instance;

  Stream<List<RecurringTransaction>> getRecurringTransactionsStream() {
    _setupRealtimeSubscription();
    _fetchAndPushData();
    return _streamController.stream;
  }

  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Fetching recurring transactions...', name: 'RecurringRepository');
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("Usuario no autenticado, no se pueden cargar los gastos fijos.");
      }
      
      final data = await _client
          .from('recurring_transactions')
          .select()
          .eq('user_id', userId)
          .order('next_due_date', ascending: true);
          
      final transactions = (data as List).map((map) => RecurringTransaction.fromMap(map)).toList();
      
      if (!_streamController.isClosed) {
        _streamController.add(transactions);
        developer.log('✅ [Repo] Pushed ${transactions.length} recurring items to stream.', name: 'RecurringRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error fetching recurring transactions: $e', name: 'RecurringRepository');
      if (!_streamController.isClosed) {
        _streamController.addError('Error al cargar datos: $e');
      }
    }
  }
  
  Future<void> refreshData() async {
    developer.log('🔄 [Repo] Manual refresh requested.', name: 'RecurringRepository');
    await _fetchAndPushData();
  }
  void _setupRealtimeSubscription() {
    if (_channel != null) return;

    developer.log('📡 [Repo] Setting up realtime subscription for recurring_transactions...', name: 'RecurringRepository');
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return; // No suscribir si no hay usuario

    _channel = _client
        .channel('public:recurring_transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recurring_transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change detected for user in recurring_transactions. Refetching...', name: 'RecurringRepository');
            _fetchAndPushData();
          },
        )
        .subscribe();
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
        'next_due_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });
    } catch (e) {
      developer.log('🔥 Error añadiendo transacción recurrente: $e', name: 'RecurringRepository');
      throw Exception('No se pudo crear el gasto fijo.');
    }
  }

  Future<void> updateRecurringTransaction(RecurringTransaction transaction) async {
    try {
      await _client
        .from('recurring_transactions')
        .update(transaction.toJson())
        .eq('id', transaction.id);
    } catch (e) {
      developer.log('🔥 Error actualizando gasto fijo: $e', name: 'RecurringRepository');
      throw Exception('No se pudo actualizar el gasto fijo.');
    }
  }
  
  Future<void> deleteRecurringTransaction(String id) async {
    try {
      await _client.from('recurring_transactions').delete().eq('id', id);
    } catch (e) {
      developer.log('🔥 Error eliminando transacción recurrente: $e', name: 'RecurringRepository');
      throw Exception('No se pudo eliminar el gasto fijo.');
    }
  }

  // Este método ya no será llamado por las pantallas individuales.
  // Podrías llamarlo, por ejemplo, cuando el usuario cierra sesión.
  void dispose() {
    developer.log('❌ [Repo] Disposing RecurringRepository Singleton resources.', name: 'RecurringRepository');
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}