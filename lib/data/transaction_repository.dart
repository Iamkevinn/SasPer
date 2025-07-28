// lib/data/transaction_repository.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

// No necesitamos importar el modelo aquí, ya que los datos vienen de la UI.
// Tampoco necesitamos notificar con EventService, ya que la lógica de streams
// está en el DashboardRepository, que escucha directamente la tabla.

class TransactionRepository {
  final SupabaseClient _client;

  // 1. AÑADIDO: Controlador para manejar el stream.
  final _transactionsController =
      StreamController<List<Transaction>>.broadcast();

  // 2. AÑADIDO: Variable para guardar la suscripción de Supabase.
  RealtimeChannel? _transactionsChannel;

  TransactionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // --- ¡NUEVO MÉTODO REACTIVO! ---
  Stream<List<Transaction>> getTransactionsStream() {
    // Si no estamos suscritos, nos suscribimos la primera vez.
    _transactionsChannel ??= _client
        .channel('public:transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          // Cualquier cambio en la tabla llamará a nuestra función para recargar datos.
          callback: (payload) => _fetchAndPushTransactions(),
        )
        .subscribe();

    _fetchAndPushTransactions(); // Hacemos una carga inicial de los datos.
    return _transactionsController.stream;
  }

  // --- NUEVO MÉTODO ---
  // --- FUNCIÓN REESCRITA PARA SER 100% ROBUSTA ---
  Future<List<Transaction>> getTransactionsForBudget(String budgetId) async {
    developer.log('🔄 [Repo] Fetching transactions for budget ID: $budgetId', name: 'TransactionRepository');
    
    try {
      // Convertimos el String que llega de la UI a un entero para la consulta.
      // Esto es NECESARIO porque el ID es un número.
      final int budgetIdAsInt = int.parse(budgetId);

      final response = await _client
          .from('transactions')
          .select()
          // La consulta ahora compara un número con un número, lo cual es correcto.
          .eq('budget_id', budgetIdAsInt)
          .order('transaction_date', ascending: false);

      final transactions = response.map((data) => Transaction.fromMap(data)).toList();
      developer.log('✅ [Repo] Found ${transactions.length} transactions for budget $budgetIdAsInt.', name: 'TransactionRepository');
      return transactions;
    
    } on FormatException {
        // Este bloque se activa si budgetId no es un número válido (ej. un UUID).
        developer.log('⚠️ [Repo] budgetId "$budgetId" no es un número válido. Devolviendo lista vacía.', name: 'TransactionRepository');
        return []; // Devolvemos una lista vacía para no romper la app.
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] FATAL ERROR fetching budget transactions: $e', name: 'TransactionRepository', error: e, stackTrace: stackTrace);
      throw Exception('Error al conectar con la base de datos.');
    }
  }

  // --- NUEVO MÉTODO PARA BÚSQUEDA Y FILTROS ---
  Future<List<Transaction>> getFilteredTransactions({
    String? searchQuery,
    List<String>? categoryFilter, // <-- AÑADIDO: Recibe la lista de categorías
    DateTimeRange? dateRange,
  }) async {
    // Empezamos con la consulta base
    var query = _client.from('transactions').select();
    
    // 1. Aplicamos el filtro de búsqueda de texto si existe
    if (searchQuery != null && searchQuery.isNotEmpty) {
      // El formato `ilike` no distingue mayúsculas/minúsculas.
      // El formato con `%` busca el texto en cualquier parte de la cadena.
      final queryFilter = '%$searchQuery%';
      // Usamos .or() para buscar en múltiples columnas.
      query = query.or(
        'description.ilike.$queryFilter,category.ilike.$queryFilter'
      );
    }
    
    // --- NUEVO: APLICAMOS EL FILTRO DE CATEGORÍAS ---
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      // Usamos el filtro 'in' de Supabase para buscar en una lista de valores.
      query = query.inFilter('category', categoryFilter);
    }

    // --- NUEVO: APLICAMOS EL FILTRO DE FECHAS ---
    if (dateRange != null) {
      // .gte() => greater than or equal to (mayor o igual que)
      query = query.gte('transaction_date', dateRange.start.toIso8601String());
      // .lte() => less than or equal to (menor o igual que)
      // Añadimos un día a la fecha final para incluir todas las transacciones de ese día
      final endOfDay = dateRange.end.add(const Duration(days: 1));
      query = query.lt('transaction_date', endOfDay.toIso8601String()); // usamos .lt (less than)
    }

    // 2. Ordenamos y ejecutamos la consulta final
    final response = await query.order('transaction_date', ascending: false);
    
    // 3. Mapeamos el resultado
    return response.map((data) => Transaction.fromMap(data)).toList();
  }

  // --- NUEVO MÉTODO ---
  Future<void> forceRefresh() async {
    developer.log('🔄 [Repo] Manual refresh requested for all transactions.');
    await _fetchAndPushTransactions();
  }

  /// Función privada que obtiene los datos de Supabase y los añade al stream.
  Future<void> _fetchAndPushTransactions() async {
    developer.log('🔄 [Repo] Fetching all transactions...');
    try {
      final data = await _client
          .from('transactions')
          .select()
          .eq('user_id', _client.auth.currentUser!.id)
          .order('transaction_date', ascending: false);

      final transactions =
          (data as List).map((t) => Transaction.fromMap(t)).toList();

      if (!_transactionsController.isClosed) {
        _transactionsController.add(transactions);
        developer.log(
            '✅ [Repo] Pushed ${transactions.length} transactions to the stream.');
      }
    } catch (e) {
      if (!_transactionsController.isClosed) {
        _transactionsController.addError(e);
        developer.log('🔥 [Repo] Error fetching transactions: $e');
      }
    }
  }

  /// Añade una nueva transacción a la base de datos.
  /// Lanza una excepción si la operación falla.
  Future<void> addTransaction({
    required String accountId,
    required double amount,
    required String type, // 'Ingreso' o 'Gasto'
    required String category,
    required String description,
    required DateTime transactionDate,
    int? budgetId,
  }) async {
    developer.log('➕ [Repo] Adding new transaction...',
        name: 'TransactionRepository');
    try {
      await _client.from('transactions').insert({
        'user_id': _client.auth.currentUser!.id,
        'account_id': accountId,
        'amount': amount.abs(),
        'type': type,
        'category': category,
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
        'budget_id': budgetId,
      });
      developer.log('✅ [Repo] Transaction added successfully.',
          name: 'TransactionRepository');
      // No necesitamos EventService aquí. El DashboardRepository ya escucha los cambios en la tabla 'transactions'.
    } catch (e) {
      developer.log('🔥 [Repo] Error adding transaction: $e',
          name: 'TransactionRepository');
      throw Exception('No se pudo añadir la transacción.');
    }
  }

  /// Devuelve una transacción específica por su ID.
  Future<Transaction?> getTransactionById(int transactionId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('id', transactionId)
          .single(); // .single() espera una sola fila o lanza un error

      return Transaction.fromMap(response);
    } catch (e) {
      developer.log('🔥 Error fetching transaction by id $transactionId: $e',
          name: 'TransactionRepository');
      return null; // Devuelve null si no se encuentra o hay un error
    }
  }

  /// Actualiza una transacción existente.
  Future<void> updateTransaction({
    required int transactionId, // El ID de la transacción es un 'bigint' -> int
    required String accountId,
    required double amount,
    required String type,
    required String category,
    required String description,
    required DateTime transactionDate,
  }) async {
    developer.log('🔄 [Repo] Updating transaction $transactionId...',
        name: 'TransactionRepository');
    try {
      await _client.from('transactions').update({
        'account_id': accountId,
        'amount': amount,
        'type': type,
        'category': category,
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
      }).eq('id', transactionId);
      developer.log('✅ [Repo] Transaction updated successfully.',
          name: 'TransactionRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error updating transaction: $e',
          name: 'TransactionRepository');
      throw Exception('No se pudo actualizar la transacción.');
    }
  }

  /// Elimina una transacción.
  Future<void> deleteTransaction(int transactionId) async {
    developer.log('🗑️ [Repo] Deleting transaction $transactionId...',
        name: 'TransactionRepository');
    try {
      await _client.from('transactions').delete().eq('id', transactionId);
      developer.log('✅ [Repo] Transaction deleted successfully.',
          name: 'TransactionRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error deleting transaction: $e',
          name: 'TransactionRepository');
      throw Exception('No se pudo eliminar la transacción.');
    }
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing TransactionRepository resources.');
    _transactionsChannel?.unsubscribe();
    _transactionsController.close();
  }
}
