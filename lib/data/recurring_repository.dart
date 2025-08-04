// lib/data/recurring_repository.dart

import 'dart:async';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class RecurringRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<RecurringTransaction>>.broadcast();
  RealtimeChannel? _channel;

  // Constructor privado para forzar el uso del Singleton `instance`.
  RecurringRepository._internal();
  static final RecurringRepository instance = RecurringRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ RecurringRepository inicializado PEREZOSAMENTE.', name: 'RecurringRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para RecurringRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient supabaseClient) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de todas las transacciones recurrentes.
  Stream<List<RecurringTransaction>> getRecurringTransactionsStream() {
    _fetchAndPushData();
    return _streamController.stream;
  }
  
  /// Obtiene una lista de todas las transacciones recurrentes (llamada única).
  Future<List<RecurringTransaction>> getAll() async {
    developer.log('🔄 [Repo] Obteniendo todas las transacciones recurrentes...', name: 'RecurringRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado.');

      final data = await client
          .from('recurring_transactions')
          .select()
          .eq('user_id', userId)
          .order('next_due_date', ascending: true);

      final list = (data as List).map((e) => RecurringTransaction.fromMap(e)).toList();
      developer.log('✅ [Repo] Obtenidas ${list.length} transacciones recurrentes.', name: 'RecurringRepository');
      return list;
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo transacciones recurrentes: $e', name: 'RecurringRepository');
      return []; // Devolver lista vacía en caso de error.
    }
  }

  /// Vuelve a cargar los datos y los emite en el stream.
  Future<void> refreshData() {
    developer.log('🔄 [Repo] Refresco manual solicitado.', name: 'RecurringRepository');
    return _fetchAndPushData();
  }

  /// Añade una nueva transacción recurrente y la devuelve.
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

      final response = await client
          .from('recurring_transactions')
          .insert(newTransactionData)
          .select()
          .single();

      return RecurringTransaction.fromMap(response);
    } catch (e) {
      developer.log('🔥 Error añadiendo transacción recurrente: $e', name: 'RecurringRepository');
      throw Exception('No se pudo crear el gasto fijo.');
    }
  }

  /// Actualiza una transacción recurrente existente.
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
  
  /// Elimina una transacción recurrente por su ID.
  Future<void> deleteRecurringTransaction(String id) async {
    try {
      await client.from('recurring_transactions').delete().eq('id', id);
    } catch (e) {
      developer.log('🔥 Error eliminando transacción recurrente: $e', name: 'RecurringRepository');
      throw Exception('No se pudo eliminar el gasto fijo.');
    }
  }

  /// Libera los recursos del repositorio.
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de RecurringRepository.', name: 'RecurringRepository');
    if (_channel != null) {
      _supabase?.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }

  // --- MÉTODOS PRIVADOS ---

  /// Configura la suscripción de Realtime.
  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo-Lazy] Configurando Realtime para Transacciones Recurrentes...', name: 'RecurringRepository');
    _channel = _supabase!
        .channel('public:recurring_transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recurring_transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime (RECURRING). Refrescando...', name: 'RecurringRepository');
            _fetchAndPushData();
          },
        )
        .subscribe();
  }

  /// Carga todas las transacciones recurrentes y las emite en el stream.
  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Obteniendo transacciones recurrentes...', name: 'RecurringRepository');
    try {
      final transactions = await getAll(); // Reutilizamos el método `getAll`
      if (!_streamController.isClosed) {
        _streamController.add(transactions);
        developer.log('✅ [Repo] ${transactions.length} elementos recurrentes enviados al stream.', name: 'RecurringRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo transacciones recurrentes: $e', name: 'RecurringRepository');
      if (!_streamController.isClosed) {
        _streamController.addError('Error al cargar datos: $e');
      }
    }
  }
}