// lib/data/transaction_repository.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class TransactionRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---
  
  // 1. El cliente ahora es privado y nullable.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! TransactionRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---
  
  final _streamController = StreamController<List<Transaction>>.broadcast();
  RealtimeChannel? _channel;
  bool _isInitialized = false;

  TransactionRepository._privateConstructor();
  static final TransactionRepository instance = TransactionRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] TransactionRepository Singleton Initialized and Client Injected.', name: 'TransactionRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

  Stream<List<Transaction>> getTransactionsStream() {
    _setupRealtimeSubscription();
    _fetchAndPushTransactions();
    return _streamController.stream;
  }

  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo] Setting up realtime subscription for transactions...', name: 'TransactionRepository');
    _channel = client
        .channel('public:transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change detected in transactions. Refetching...', name: 'TransactionRepository');
            _fetchAndPushTransactions();
          },
        )
        .subscribe();
  }

  Future<void> _fetchAndPushTransactions() async {
    developer.log('🔄 [Repo] Fetching all transactions...', name: 'TransactionRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not authenticated");
      
      final data = await client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('transaction_date', ascending: false);

      final transactions = (data as List).map((t) => Transaction.fromMap(t)).toList();
      
      if (!_streamController.isClosed) {
        _streamController.add(transactions);
        developer.log('✅ [Repo] Pushed ${transactions.length} transactions to the stream.', name: 'TransactionRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error fetching transactions: $e', name: 'TransactionRepository');
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  Future<void> refreshData() async {
    await _fetchAndPushTransactions();
  }
  
  Future<void> addTransaction({
    required String accountId,
    required double amount,
    required String type,
    required String category,
    required String description,
    required DateTime transactionDate,
    int? budgetId,
  }) async {
    try {
      await client.from('transactions').insert({
        'user_id': client.auth.currentUser!.id,
        'account_id': accountId,
        'amount': amount, 
        'type': type,
        'category': category,
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
        'budget_id': budgetId,
      });
    } catch (e) {
      developer.log('🔥 Error adding transaction: $e', name: 'TransactionRepository');
      throw Exception('No se pudo añadir la transacción.');
    }
  }

  Future<void> updateTransaction({
    required int transactionId,
    required String accountId,
    required double amount,
    required String type,
    required String category,
    required String description,
    required DateTime transactionDate,
  }) async {
    try {
      await client.from('transactions').update({
        'account_id': accountId,
        'amount': amount,
        'type': type,
        'category': category,
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
      }).eq('id', transactionId);
    } catch (e) {
      developer.log('🔥 Error updating transaction: $e', name: 'TransactionRepository');
      throw Exception('No se pudo actualizar la transacción.');
    }
  }

  Future<void> deleteTransaction(int transactionId) async {
    try {
      await client.from('transactions').delete().eq('id', transactionId);
    } catch (e) {
      developer.log('🔥 Error deleting transaction: $e', name: 'TransactionRepository');
      throw Exception('No se pudo eliminar la transacción.');
    }
  }

  Future<List<Transaction>> getTransactionsForBudget(String budgetId) async {
    developer.log('🔄 [Repo] Fetching transactions for budget ID: $budgetId', name: 'TransactionRepository');
    try {
      final int budgetIdAsInt = int.parse(budgetId);
      final response = await client
          .from('transactions')
          .select()
          .eq('budget_id', budgetIdAsInt)
          .order('transaction_date', ascending: false);
      final transactions = response.map((data) => Transaction.fromMap(data)).toList();
      developer.log('✅ [Repo] Found ${transactions.length} transactions for budget $budgetIdAsInt.', name: 'TransactionRepository');
      return transactions;
    } on FormatException {
        developer.log('⚠️ [Repo] budgetId "$budgetId" no es un número válido. Devolviendo lista vacía.', name: 'TransactionRepository');
        return [];
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] FATAL ERROR fetching budget transactions: $e', name: 'TransactionRepository', error: e, stackTrace: stackTrace);
      throw Exception('Error al conectar con la base de datos.');
    }
  }

  Future<List<Transaction>> getFilteredTransactions({
    String? searchQuery,
    List<String>? categoryFilter,
    DateTimeRange? dateRange,
  }) async {
    var query = client.from('transactions').select().eq('user_id', client.auth.currentUser!.id);
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final queryFilter = '%$searchQuery%';
      query = query.or('description.ilike.$queryFilter,category.ilike.$queryFilter');
    }
    
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      query = query.inFilter('category', categoryFilter);
    }

    if (dateRange != null) {
      query = query.gte('transaction_date', dateRange.start.toIso8601String());
      final endOfDay = dateRange.end.add(const Duration(days: 1));
      query = query.lt('transaction_date', endOfDay.toIso8601String());
    }

    final response = await query.order('transaction_date', ascending: false);
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
      developer.log('🔥 Error fetching transaction by id $transactionId: $e', name: 'TransactionRepository');
      return null;
    }
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing TransactionRepository Singleton resources.', name: 'TransactionRepository');
    if (_channel != null) {
      client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}