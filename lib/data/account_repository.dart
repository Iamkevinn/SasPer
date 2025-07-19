// lib/data/account_repository.dart (CORREGIDO Y AMPLIADO)

import 'dart:async';
import 'dart:developer'; // CORRECCIÓN: Importación correcta
import 'dart:developer' as developer;
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_model.dart'; // Importamos el modelo
import '../models/transaction_models.dart';

class AccountRepository {
  final SupabaseClient _client;
  // Controlador para el stream de cuentas, encapsulado aquí
  final _accountsStreamController = StreamController<List<Account>>.broadcast();
  // Guardamos las suscripciones para poder cancelarlas
  RealtimeChannel? _accountsChannel;
  RealtimeChannel? _transactionsChannel;

  AccountRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  /// Devuelve un Stream de cuentas con su balance actualizado.
  /// La lógica de suscripción y recarga está encapsulada aquí.
  Stream<List<Account>> getAccountsWithBalanceStream() {
    // Si los canales no están suscritos, los configuramos la primera vez
    if (_accountsChannel == null || _transactionsChannel == null) {
      _setupRealtimeSubscriptions();
    }
    // Cargamos los datos iniciales
    _fetchAccountsWithBalance();
    
    return _accountsStreamController.stream;
  }
  
  /// Devuelve una lista de transacciones para una cuenta específica.
  Future<List<Transaction>> getTransactionsForAccount(String accountId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('account_id', accountId)
          .order('transaction_date', ascending: false);
          
      return (response as List).map((data) => Transaction.fromMap(data)).toList();
    } catch (e) {
      log('🔥 Error fetching transactions for account $accountId: $e', name: 'AccountRepository');
      throw Exception('No se pudieron cargar las transacciones.');
    }
  }
  /// Realiza una transferencia entre dos cuentas llamando a una función RPC.
  /// Lanza una excepción si la operación falla.
  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? description,
  }) async {
    log('💸 [Repo] Creating transfer from $fromAccountId to $toAccountId', name: 'AccountRepository');
    try {
      await _client.rpc('create_transfer', params: {
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'transfer_amount': amount,
        'transfer_description': description?.trim(),
      });
      log('✅ [Repo] Transfer created successfully.', name: 'AccountRepository');
    } catch (e) {
      log("🔥 [Repo] Error creating transfer: $e", name: 'AccountRepository');
      throw Exception('No se pudo realizar la transferencia.');
    }
  }
  
  Future<void> addAccount({
    required String name,
    required String type,
    required double initialBalance,
  }) async {
    try {
      await _client.from('accounts').insert({
        'user_id': _client.auth.currentUser!.id,
        'name': name,
        'type': type,
        'initial_balance': initialBalance,
        'balance': initialBalance, // Asumimos que el balance inicial es el actual
      });
      // El stream en tiempo real notificará automáticamente a los oyentes,
      // por lo que no necesitamos disparar un EventService aquí.
    } catch (e) {
      log('🔥 Error adding account: $e', name: 'AccountRepository');
      // Re-lanzamos la excepción para que la UI pueda manejarla
      throw Exception('Failed to add account.');
    }
  }
  void _setupRealtimeSubscriptions() {
    log('📡 [Repo] Setting up realtime subscriptions for accounts and transactions...', name: 'AccountRepository');
    
    void onDbChange(payload) {
      log('🔄 [Repo] DB change detected, fetching fresh data...', name: 'AccountRepository');
      _fetchAccountsWithBalance();
    }
    
    _accountsChannel = _client
      .channel('public:accounts')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'accounts', callback: onDbChange)
      .subscribe();
      
    _transactionsChannel = _client
      .channel('public:transactions')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: onDbChange)
      .subscribe();
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
      developer.log('🔥 Error fetching transaction by id $transactionId: $e', name: 'TransactionRepository');
      return null; // Devuelve null si no se encuentra o hay un error
    }
  }

  Future<void> forceRefresh() async {
    log('🔄 [Repo] Manual refresh requested.', name: 'AccountRepository');
    await _fetchAccountsWithBalance();
  }
  Future<List<Account>> getAccounts() async {
    try {
      final response = await _client.from('accounts').select();
      return (response as List).map((data) => Account.fromMap(data)).toList();
    } catch (e) {
      log('🔥 Error fetching accounts: $e', name: 'AccountRepository');
      return [];
    }
  }
  /// Función privada que obtiene los datos y los añade al stream.
  Future<void> _fetchAccountsWithBalance() async {
    try {
      final response = await _client.rpc('get_accounts_with_balance');
      final accounts = (response as List)
          .map((data) => Account.fromMap(data))
          .toList();
      _accountsStreamController.add(accounts);
    } catch (e, stackTrace) {
      log('🔥 [Repo] Error fetching accounts with balance: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      _accountsStreamController.addError(e);
    }
  }

  // Este método ya lo teníamos, solo corregimos el log
  Future<double> getAccountProjectionInDays(String accountId) async {
    try {
      final response = await _client.rpc('get_burn_rate_projection', params: {'account_id_param': accountId}) as List;
      if (response.isEmpty || response.first == null) return 0.0;
      final resultData = response.first;
      return (resultData as num).toDouble();
    } catch (e, stackTrace) {
      // CORRECCIÓN: Quitamos 'as num' del mensaje de log.
      log('🔥 Error fetching projection for account $accountId: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      return 0.0;
    }
  }

  /// Limpia los recursos (streams y canales) cuando ya no se necesiten.
  void dispose() {
    log('❌ [Repo] Disposing AccountRepository resources.', name: 'AccountRepository');
    _accountsChannel?.unsubscribe();
    _transactionsChannel?.unsubscribe();
    _accountsStreamController.close();
  }
}