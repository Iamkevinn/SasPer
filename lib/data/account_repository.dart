// lib/data/account_repository.dart (COMPLETO Y FINAL)

import 'dart:async';
import 'dart:developer' as developer;
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository {
  final SupabaseClient _client;
  final _accountsStreamController = StreamController<List<Account>>.broadcast();
  RealtimeChannel? _subscriptionChannel;

  AccountRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Stream<List<Account>> getAccountsWithBalanceStream() {
    if (_subscriptionChannel == null) {
      _setupRealtimeSubscriptions();
    }
    // La carga inicial se dispara desde la suscripción,
    // pero la llamamos aquí también para asegurar datos inmediatos.
    _fetchAccountsWithBalance();
    return _accountsStreamController.stream;
  }

  Future<void> _fetchAccountsWithBalance() async {
    developer.log('🔄 [Repo] Fetching accounts with balance...');
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _client.rpc(
        'get_accounts_with_balance', 
        params: {'p_user_id': userId}
      );

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
  
  Future<Account?> getAccountById(String accountId) async {
    developer.log('ℹ️ [Repo] Fetching account by ID: $accountId...');
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _client.rpc(
        'get_accounts_with_balance', 
        params: {'p_user_id': userId}
      );

      final accounts = (response as List).map((data) => Account.fromMap(data)).toList();
      return accounts.firstWhere((account) => account.id == accountId);
    } catch (e) {
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
        'balance': initialBalance,
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
    developer.log('📡 [Repo] Setting up realtime subscriptions for accounts & transactions...', name: 'AccountRepository');
    _subscriptionChannel ??= _client
        .channel('public:all_tables_for_accounts_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accounts',
          callback: (payload) => _fetchAccountsWithBalance(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) => _fetchAccountsWithBalance(),
        )
        .subscribe();
  }

  Future<void> forceRefresh() async {
    developer.log('🔄 [Repo] Manual refresh requested for accounts.');
    await _fetchAccountsWithBalance();
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing AccountRepository resources.', name: 'AccountRepository');
    if (_subscriptionChannel != null) {
      _client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _accountsStreamController.close();
  }
}