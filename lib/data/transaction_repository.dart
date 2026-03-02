// lib/data/transaction_repository.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'dart:developer' as developer;

class TransactionRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<Transaction>>.broadcast();
  RealtimeChannel? _channel;

  // Constructor privado para forzar el uso del Singleton `instance`.
  TransactionRepository._internal();
  static final TransactionRepository instance = TransactionRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ TransactionRepository inicializado PEREZOSAMENTE.', name: 'TransactionRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para TransactionRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient supabaseClient) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de todas las transacciones del usuario.
  Stream<List<Transaction>> getTransactionsStream() {
    _fetchAndPushTransactions();
    return _streamController.stream;
  }

  /// Vuelve a cargar los datos y los emite en el stream.
  Future<void> refreshData() => _fetchAndPushTransactions();
  
  /// Añade una nueva transacción.
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
    // --- NUEVOS CAMPOS PARA CRÉDITO ---
    String? creditCardId,      // ID de la cuenta tipo tarjeta
    int? installmentsTotal,    // Total de cuotas (ej: 12)
    int? installmentsCurrent,  // Cuota actual (ej: 1)
    bool isInstallment = false, // ¿Es a cuotas?
    bool isInterestFree = false,
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
        'mood': mood?.name,
        'location_name': locationName,
        'latitude': latitude,
        'longitude': longitude,
        // --- INSERCIÓN DE NUEVOS CAMPOS ---
        'credit_card_id': creditCardId,
        'installments_total': installmentsTotal,
        'installments_current': installmentsCurrent,
        'is_installment': isInstallment,
        'is_interest_free': isInterestFree,
      });
      
      developer.log('✅ Transacción guardada (Cuotas: $isInstallment)', name: 'TransactionRepository');
    } catch (e) {
      developer.log('🔥 Error al añadir transacción: $e', name: 'TransactionRepository');
      throw Exception('No se pudo añadir la transacción.');
    }
  }

  /// Registra el pago de una cuota y actualiza el contador de la deuda.
Future<void> payInstallment({
  required Transaction originalTransaction,
  required String paymentSourceAccountId, // Desde dónde sale el dinero (Ej: Bancolombia)
}) async {
  // 1. Validar que no hayamos terminado ya
  if (originalTransaction.installmentsCurrent! > originalTransaction.installmentsTotal!) {
    throw Exception("Esta deuda ya está pagada.");
  }

  // 2. Calcular el valor de la cuota individual
  final installmentAmount = originalTransaction.amount.abs() / originalTransaction.installmentsTotal!;

  // 3. Crear la transacción del pago (Gasto real)
  await addTransaction(
    accountId: paymentSourceAccountId,
    amount: -installmentAmount, // Sale dinero
    type: 'Gasto',
    category: 'Pago Tarjeta', // O la categoría original
    description: 'Pago cuota ${originalTransaction.installmentsCurrent} de: ${originalTransaction.description}',
    transactionDate: DateTime.now(),
    isInstallment: false, // El pago en sí no es una cuota, es un gasto puntual
  );

  // 4. Actualizar la transacción original (Avanzar el contador)
  await client.from('transactions').update({
    'installments_current': originalTransaction.installmentsCurrent! + 1,
  }).eq('id', originalTransaction.id);

  developer.log('✅ Cuota pagada y avanzada', name: 'TransactionRepository');
}

  /// Actualiza una transacción existente.
  Future<void> updateTransaction({
    required int transactionId,
    required String accountId,
    //required double amount,
    required String type,
    required String category,
    required String description,
    required DateTime transactionDate,
    TransactionMood? mood,
    // Los campos de ubicación no se editan por ahora, se podrían añadir después
    // String? locationName,
    // double? latitude,
    // double? longitude,
  }) async {
    try {
      // Llamamos a nuestra nueva función RPC con todos los parámetros nuevos.
      await client.rpc('update_transaction_and_relational_data', params: {
        'p_transaction_id': transactionId,
        'p_new_account_id': accountId,
        //'p_new_amount': amount,
        'p_new_type': type,
        'p_new_category': category,
        'p_new_description': description,
        'p_new_mood': mood?.name, // Pasamos el nombre del enum o null
        'p_new_transaction_date': transactionDate.toIso8601String(),
      });
      developer.log('✅ [Repo] Transacción $transactionId actualizada con éxito vía RPC.', name: 'TransactionRepository');
    } catch (e) {
      developer.log('🔥 Error al actualizar transacción vía RPC: $e', name: 'TransactionRepository');
      throw Exception('No se pudo actualizar la transacción.');
    }
  }

  /// Elimina una transacción por su ID.
  Future<void> deleteTransaction(int transactionId) async {
    try {
      await client.from('transactions').delete().eq('id', transactionId);
    } catch (e) {
      developer.log('🔥 Error al eliminar transacción: $e', name: 'TransactionRepository');
      throw Exception('No se pudo eliminar la transacción.');
    }
  }

  /// Obtiene las transacciones asociadas a un presupuesto específico.
  Future<List<Transaction>> getTransactionsForBudget(String budgetId) async {
    developer.log('🔄 [Repo] Obteniendo transacciones para el presupuesto ID: $budgetId', name: 'TransactionRepository');
    try {
      final int budgetIdAsInt = int.parse(budgetId);
      final response = await client
          .from('transactions')
          .select()
          .eq('budget_id', budgetIdAsInt)
          .order('transaction_date', ascending: false);
      final transactions = response.map((data) => Transaction.fromMap(data)).toList();
      developer.log('✅ [Repo] Encontradas ${transactions.length} transacciones para el presupuesto $budgetIdAsInt.', name: 'TransactionRepository');
      return transactions;
    } on FormatException {
        developer.log('⚠️ [Repo] budgetId "$budgetId" no es un número válido. Devolviendo lista vacía.', name: 'TransactionRepository');
        return [];
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] ERROR obteniendo transacciones de presupuesto: $e', name: 'TransactionRepository', error: e, stackTrace: stackTrace);
      throw Exception('Error al conectar con la base de datos.');
    }
  }


   // --- NUEVO MÉTODO REACTIVO ---
  /// Devuelve un stream de transacciones para un presupuesto específico.
  /// Escucha cambios en tiempo real.
  Stream<List<Transaction>> getTransactionsStreamForBudget(int budgetId) {
    developer.log('📡 [Repo] Suscribiéndose al stream de transacciones para el presupuesto ID: $budgetId', name: 'TransactionRepository');
    try {
      // Usamos el método .stream() de Supabase, que es la base de la reactividad.
      return client
          .from('transactions')
          .stream(primaryKey: ['id']) // La clave primaria de tu tabla de transacciones
          .eq('budget_id', budgetId)
          .order('transaction_date', ascending: false)
          .map((listOfMaps) {
            // Cada vez que Supabase notifica un cambio, este 'map' se ejecuta.
            final transactions = listOfMaps.map((data) => Transaction.fromMap(data)).toList();
            developer.log('✅ [Repo] Stream del presupuesto $budgetId actualizado con ${transactions.length} elementos.', name: 'TransactionRepository');
            return transactions;
          });
    } catch (e) {
      developer.log('🔥 [Repo] Error al crear el stream para el presupuesto $budgetId: $e', name: 'TransactionRepository');
      // En caso de error, devolvemos un stream que emite una lista vacía.
      return Stream.value([]);
    }
  }

  /// Obtiene una lista filtrada de transacciones.
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
      final endOfDay = DateTime(dateRange.end.year, dateRange.end.month, dateRange.end.day, 23, 59, 59);
      query = query.lte('transaction_date', endOfDay.toIso8601String());
    }

    final response = await query.order('transaction_date', ascending: false);
    return response.map((data) => Transaction.fromMap(data)).toList();
  }

  /// Obtiene una única transacción por su ID.
  Future<Transaction?> getTransactionById(int transactionId) async {
    try {
      final response = await client
          .from('transactions')
          .select()
          .eq('id', transactionId)
          .single();
      return Transaction.fromMap(response);
    } catch (e) {
      developer.log('🔥 Error obteniendo transacción por id $transactionId: $e', name: 'TransactionRepository');
      return null;
    }
  }

  /// Libera los recursos del repositorio.
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de TransactionRepository.', name: 'TransactionRepository');
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

    developer.log('📡 [Repo-Lazy] Configurando Realtime para Transacciones...', name: 'TransactionRepository');
    _channel = _supabase!
        .channel('public:transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime (TRANSACTIONS). Refrescando...', name: 'TransactionRepository');
            _fetchAndPushTransactions();
          },
        )
        .subscribe();
  }

  /// Carga todas las transacciones y las emite en el stream.
  Future<void> _fetchAndPushTransactions() async {
    developer.log('🔄 [Repo] Obteniendo todas las transacciones...', name: 'TransactionRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Usuario no autenticado");
      
      final data = await client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('transaction_date', ascending: false);

      final transactions = (data as List).map((t) => Transaction.fromMap(t)).toList();
      
      if (!_streamController.isClosed) {
        _streamController.add(transactions);
        developer.log('✅ [Repo] ${transactions.length} transacciones enviadas al stream.', name: 'TransactionRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo transacciones: $e', name: 'TransactionRepository');
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }
}