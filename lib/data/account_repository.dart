// lib/data/account_repository.dart (VERSIÓN FINAL CORREGIDA)

import 'dart:async';
import 'dart:developer' as developer; // Usamos un alias para evitar conflictos
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository {
  final SupabaseClient _client;
  final _accountsStreamController = StreamController<List<Account>>.broadcast();
  RealtimeChannel? _accountsChannel;
  RealtimeChannel? _transactionsChannel;

  AccountRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Stream<List<Account>> getAccountsWithBalanceStream() {
    if (_accountsChannel == null) {
      _setupRealtimeSubscriptions();
    }
    _fetchAccountsWithBalance();
    return _accountsStreamController.stream;
  }

  Future<void> _fetchAccountsWithBalance() async {
    try {
      final response = await _client.rpc('get_accounts_with_balance');
      final accounts = (response as List).map((data) => Account.fromMap(data)).toList();
      if (!_accountsStreamController.isClosed) {
        _accountsStreamController.add(accounts);
      }
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error fetching accounts with balance: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      if (!_accountsStreamController.isClosed) {
        _accountsStreamController.addError(e);
      }
    }
  }
  
  // 1. CORRECCIÓN CRÍTICA: La lógica de filtrado ahora se hace en Dart.
  Future<Account?> getAccountById(String accountId) async {
    try {
      // Primero, obtenemos la lista completa de cuentas con sus balances.
      final response = await _client.rpc('get_accounts_with_balance');
      final accounts = (response as List).map((data) => Account.fromMap(data)).toList();
      
      // Luego, buscamos la cuenta específica en la lista.
      // Usamos 'firstWhere' dentro de un try-catch para manejar el caso en que no se encuentre.
      return accounts.firstWhere((account) => account.id == accountId);
    } catch (e) {
      // Esto se activará si 'firstWhere' no encuentra ningún elemento, o por otros errores.
      developer.log('🔥 Error fetching or finding account by id $accountId: $e', name: 'AccountRepository');
      return null;
    }
  }
  
  Future<List<Account>> getAccounts() async {
    try {
      final response = await _client.from('accounts').select().order('name', ascending: true);
      return (response as List).map((data) => Account.fromMap(data)).toList();
    } catch (e) {
      developer.log('🔥 Error fetching accounts: $e', name: 'AccountRepository');
      return [];
    }
  }

  Future<List<Transaction>> getTransactionsForAccount(String accountId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('account_id', accountId)
          .order('transaction_date', ascending: false);
      return (response as List).map((data) => Transaction.fromMap(data)).toList();
    } catch (e) {
      developer.log('🔥 Error fetching transactions for account $accountId: $e', name: 'AccountRepository');
      throw Exception('No se pudieron cargar las transacciones.');
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
        'balance': initialBalance, // El balance actual se recalculará con la función RPC
      });
    } catch (e) {
      developer.log('🔥 Error adding account: $e', name: 'AccountRepository');
      throw Exception('No se pudo añadir la cuenta.');
    }
  }
  
  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? description,
  }) async {
    try {
      await _client.rpc('create_transfer', params: {
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'transfer_amount': amount,
        'transfer_description': description?.trim(),
      });
    } catch (e) {
      developer.log("🔥 [Repo] Error creating transfer: $e", name: 'AccountRepository');
      throw Exception('No se pudo realizar la transferencia.');
    }
  }

  Future<double> getAccountProjectionInDays(String accountId) async {
    try {
      final response = await _client.rpc('get_burn_rate_projection', params: {'account_id_param': accountId}) as List;
      if (response.isEmpty || response.first == null) return 0.0;
      return (response.first as num).toDouble();
    } catch (e, stackTrace) {
      developer.log('🔥 Error fetching projection for account $accountId: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      return 0.0;
    }
  }

  void _setupRealtimeSubscriptions() {
    developer.log('📡 [Repo] Setting up realtime subscriptions...', name: 'AccountRepository');
    void onDbChange(payload) {
      developer.log('🔄 [Repo] DB change detected, fetching fresh data...', name: 'AccountRepository');
      _fetchAccountsWithBalance();
    }
    _accountsChannel = _client.channel('public:accounts').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'accounts', callback: onDbChange).subscribe();
    _transactionsChannel = _client.channel('public:transactions').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: onDbChange).subscribe();
  }

  Future<void> forceRefresh() async {
    developer.log('🔄 [Repo] Manual refresh requested.', name: 'AccountRepository');
    await _fetchAccountsWithBalance();
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing AccountRepository resources.', name: 'AccountRepository');
    _accountsChannel?.unsubscribe();
    _transactionsChannel?.unsubscribe();
    _accountsStreamController.close();
  }
}