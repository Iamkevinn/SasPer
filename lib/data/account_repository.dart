// lib/data/account_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---
  
  // 1. El cliente ahora es privado y nullable. No más 'late final'.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! AccountRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---

  final _streamController = StreamController<List<Account>>.broadcast();
  RealtimeChannel? _channel;
  bool _isInitialized = false;

  AccountRepository._privateConstructor();
  static final AccountRepository instance = AccountRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] AccountRepository Singleton Initialized and Client Injected.', name: 'AccountRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

  Stream<List<Account>> getAccountsStream() {
    _setupRealtimeSubscriptions();
    _fetchAccountsWithBalance();
    return _streamController.stream;
  }

  void _setupRealtimeSubscriptions() {
    if (_channel != null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo] Setting up realtime subscriptions for accounts & transactions...', name: 'AccountRepository');
    _channel = client
        .channel('public:all_tables_for_accounts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accounts',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change detected in ACCOUNTS. Refetching balances...', name: 'AccountRepository');
            _fetchAccountsWithBalance();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change detected in TRANSACTIONS. Refetching account balances...', name: 'AccountRepository');
            _fetchAccountsWithBalance();
          },
        )
        .subscribe();
  }

  Future<void> _fetchAccountsWithBalance() async {
    developer.log('🔄 [Repo] Fetching accounts with balance...', name: 'AccountRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await client.rpc(
        'get_accounts_with_balance', 
        params: {'p_user_id': userId}
      );

      final accounts = (response as List).map((data) => Account.fromMap(data)).toList();
      if (!_streamController.isClosed) {
        _streamController.add(accounts);
        developer.log('✅ [Repo] Pushed ${accounts.length} accounts to stream.', name: 'AccountRepository');
      }
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error fetching accounts with balance: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }
  
  Future<void> refreshData() async {
    await _fetchAccountsWithBalance();
  }

  Future<void> addAccount({
    required String name,
    required String type,
    required double initialBalance,
  }) async {
    try {
      await client.from('accounts').insert({
        'user_id': client.auth.currentUser!.id,
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

  Future<void> updateAccount(Account account) async {
    try {
      await client
          .from('accounts')
          .update({ 'name': account.name, 'type': account.type })
          .eq('id', account.id);
    } catch (e) {
      developer.log('🔥 Error updating account: $e', name: 'AccountRepository');
      throw Exception('No se pudo actualizar la cuenta.');
    }
  }
  
  Future<void> deleteAccountSafely(String accountId) async {
    try {
      await client.rpc(
        'delete_account_safely',
        params: {'account_id_to_delete': accountId},
      );
    } catch (e) {
      developer.log('🔥 Error in RPC delete_account_safely: $e', name: 'AccountRepository');
      throw Exception('No se pudo eliminar la cuenta. Asegúrate de que no tenga transacciones.');
    }
  }

  Future<List<Account>> getAccounts() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await client.from('accounts')
        .select()
        .eq('user_id', userId)
        .order('name', ascending: true);
      
      return (response as List).map((data) => Account.fromMap(data)).toList();
    } catch (e) {
      developer.log('🔥 Error fetching simple accounts: $e', name: 'AccountRepository');
      return [];
    }
  }

  Future<Account?> getAccountById(String accountId) async {
    developer.log('ℹ️ [Repo] Fetching account by ID: $accountId...', name: 'AccountRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await client.rpc(
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
  
  Future<List<Transaction>> getTransactionsForAccount(String accountId) async {
    try {
      final response = await client
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
  
  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String? description,
  }) async {
    try {
      await client.rpc('create_transfer', params: {
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
      final response = await client.rpc(
        'get_burn_rate_projection', 
        params: {'account_id_param': accountId}
      );

      if (response is List && response.isNotEmpty) {
        final firstRow = response.first as Map<String, dynamic>;
        final projectionValue = (firstRow['projection_days'] as num? ?? 0.0).toDouble();
        return projectionValue;
      }
      return 0.0;
    } catch (e, stackTrace) {
      developer.log('🔥 Error fetching projection for account $accountId: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      return 0.0;
    }
  }
  
  void dispose() {
    developer.log('❌ [Repo] Disposing AccountRepository Singleton resources.', name: 'AccountRepository');
    if (_channel != null) {
      client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}