// lib/data/recurring_repository.dart

import 'dart:async';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class RecurringRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---
  
  // 1. El cliente ahora es privado y nullable.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! RecurringRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---
  
  final _streamController = StreamController<List<RecurringTransaction>>.broadcast();
  RealtimeChannel? _channel;
  bool _isInitialized = false;

  RecurringRepository._privateConstructor();
  static final RecurringRepository instance = RecurringRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] RecurringRepository Singleton Initialized and Client Injected.', name: 'RecurringRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

  Stream<List<RecurringTransaction>> getRecurringTransactionsStream() {
    _setupRealtimeSubscription();
    _fetchAndPushData();
    return _streamController.stream;
  }

  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo] Setting up realtime subscription for recurring_transactions...', name: 'RecurringRepository');
    _channel = client
        .channel('public:recurring_transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recurring_transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change detected in recurring_transactions. Refetching...', name: 'RecurringRepository');
            _fetchAndPushData();
          },
        )
        .subscribe();
  }

  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Fetching recurring transactions...', name: 'RecurringRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("Usuario no autenticado.");
      }
      
      final data = await client
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
  
  /// Nuevo método: devuelve la lista completa de transacciones recurrentes
  Future<List<RecurringTransaction>> getAll() async {
    developer.log('🔄 [Repo] getAll(): fetching all recurring transactions...', name: 'RecurringRepository');
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado.');

    final data = await client
        .from('recurring_transactions')
        .select()
        .eq('user_id', userId)
        .order('next_due_date', ascending: true);

    final list = (data as List)
        .map((e) => RecurringTransaction.fromMap(e))
        .toList();

    developer.log(
      '✅ [Repo] getAll(): fetched ${list.length} transactions.',
      name: 'RecurringRepository',
    );
    return list;
  }

  Future<void> refreshData() async {
    developer.log('🔄 [Repo] Manual refresh requested.', name: 'RecurringRepository');
    await _fetchAndPushData();
  }

  // Ahora devuelve Future<RecurringTransaction> en lugar de Future<void>
  Future<RecurringTransaction> addRecurringTransaction({
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
      final newTransactionData = {
        'user_id': client.auth.currentUser!.id,
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
      };

      // Usamos .insert() y .select() para que Supabase nos devuelva el registro que acaba de crear
      final response = await client
          .from('recurring_transactions')
          .insert(newTransactionData)
          .select()
          .single(); // .single() convierte la lista de un solo elemento en un solo objeto

      // Parseamos el mapa devuelto por Supabase y lo retornamos
      return RecurringTransaction.fromMap(response);

    } catch (e) {
      developer.log('🔥 Error añadiendo transacción recurrente: $e', name: 'RecurringRepository');
      throw Exception('No se pudo crear el gasto fijo.');
    }
  }


  Future<void> updateRecurringTransaction(RecurringTransaction transaction) async {
    try {
      await client
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
      await client.from('recurring_transactions').delete().eq('id', id);
    } catch (e) {
      developer.log('🔥 Error eliminando transacción recurrente: $e', name: 'RecurringRepository');
      throw Exception('No se pudo eliminar el gasto fijo.');
    }
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing RecurringRepository Singleton resources.', name: 'RecurringRepository');
    if (_channel != null) {
      client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}