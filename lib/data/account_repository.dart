// lib/data/account_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<Account>>.broadcast();
  RealtimeChannel? _channel;

  // Constructor privado para forzar el uso del Singleton `instance`.
  AccountRepository._internal();
  static final AccountRepository instance = AccountRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  /// Se ejecuta automáticamente la primera vez que se accede al cliente de Supabase.
  void _ensureInitialized() {
    // Esta lógica solo se ejecuta una vez en todo el ciclo de vida de la app.
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscriptions(); // La configuración de Realtime depende de la inicialización.
      _isInitialized = true;
      developer.log('✅ AccountRepository inicializado PEREZOSAMENTE.', name: 'AccountRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  /// Es el guardián que activa la inicialización perezosa cuando es necesario.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para AccountRepository.");
    }
    return _supabase!;
  }

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de las cuentas del usuario.
  /// Al suscribirse, activará la primera carga de datos.
  Stream<List<Account>> getAccountsStream() {
    // La inicialización se activará automáticamente por `_fetchAccountsWithBalance`
    // la primera vez que este stream tenga un listener.
    _fetchAccountsWithBalance();
    return _streamController.stream;
  }

  /// Vuelve a cargar los datos de las cuentas desde la base de datos.
  Future<void> refreshData() => _fetchAccountsWithBalance();

  /// Añade una nueva cuenta para el usuario actual.
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
      developer.log('🔥 Error al añadir cuenta: $e', name: 'AccountRepository');
      throw Exception('No se pudo añadir la cuenta.');
    }
  }

  /// Actualiza los detalles de una cuenta existente.
  Future<void> updateAccount(Account account) async {
    try {
      await client
          .from('accounts')
          .update({'name': account.name, 'type': account.type})
          .eq('id', account.id);
    } catch (e) {
      developer.log('🔥 Error al actualizar cuenta: $e', name: 'AccountRepository');
      throw Exception('No se pudo actualizar la cuenta.');
    }
  }

  /// Llama a un RPC para eliminar una cuenta de forma segura.
  Future<void> deleteAccountSafely(String accountId) async {
    try {
      await client.rpc('delete_account_safely', params: {'account_id_to_delete': accountId});
    } on PostgrestException catch (e) {
      // Capturamos la excepción de Supabase y la transformamos en un error legible.
      if (e.message.contains('account_has_transactions')) {
        throw Exception('No se puede eliminar: la cuenta tiene movimientos relacionados.');
      }
      if (e.message.contains('balance_not_zero')) {
        throw Exception('No se puede eliminar: el saldo de la cuenta no es cero.');
      }
      rethrow; // Si es otro error, lo relanzamos.
    } catch (e) {
      developer.log('🔥 Error en RPC delete_account_safely: $e', name: 'AccountRepository');
      throw Exception('Ocurrió un error inesperado al intentar eliminar la cuenta.');
    }
  }

  // --- NUEVOS MÉTODOS ---
  Future<void> archiveAccount(String accountId) async {
    try {
      await client.rpc('archive_account', params: {'p_account_id': accountId});
      
      // AÑADIDO: Forzamos el refresco de datos para actualizar la UI inmediatamente.
      await refreshData(); 

    } catch (e) {
      developer.log('🔥 Error archivando cuenta: $e', name: 'AccountRepository');
      throw Exception('No se pudo archivar la cuenta.');
    }
  }

  Future<void> unarchiveAccount(String accountId) async {
    try {
      await client.rpc('unarchive_account', params: {'p_account_id': accountId});
      
      // AÑADIDO: Forzamos el refresco de datos para actualizar la UI inmediatamente.
      await refreshData();

    } catch (e) {
      developer.log('🔥 Error desarchivando cuenta: $e', name: 'AccountRepository');
      throw Exception('No se pudo desarchivar la cuenta.');
    }
  }

  /// Obtiene una lista de cuentas ACTIVAS (sin balance calculado por RPC).
  /// Este es el método que usarán los selectores en otras partes de la app.
  Future<List<Account>> getAccounts() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await client.rpc(
        'get_accounts_with_balance',
        params: {'p_user_id': userId}
      );

      final allAccounts = (response as List).map((data) => Account.fromMap(data)).toList();
      // --- FILTRO IMPORTANTE ---
      // Solo devolvemos las cuentas activas para los selectores.
      return allAccounts.where((acc) => acc.status == AccountStatus.active).toList();

    } catch (e) {
      developer.log('🔥 Error obteniendo lista de cuentas: $e', name: 'AccountRepository');
      return [];
    }
  }

  /// Obtiene una cuenta específica por su ID, con el balance calculado.
  Future<Account?> getAccountById(String accountId) async {
    developer.log('ℹ️ [Repo] Obteniendo cuenta por ID: $accountId...', name: 'AccountRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await client.rpc(
        'get_accounts_with_balance',
        params: {'p_user_id': userId}
      );

      final accounts = (response as List).map((data) => Account.fromMap(data)).toList();
      return accounts.firstWhere((account) => account.id == accountId);
    } catch (e) {
      developer.log('🔥 Error obteniendo cuenta por id $accountId: $e', name: 'AccountRepository');
      return null;
    }
  }

  /// Obtiene todas las transacciones asociadas a una cuenta.
  Future<List<Transaction>> getTransactionsForAccount(String accountId) async {
    try {
      final response = await client
          .from('transactions')
          .select()
          .eq('account_id', accountId)
          .order('transaction_date', ascending: false);
      return (response as List).map((data) => Transaction.fromMap(data)).toList();
    } catch (e) {
      developer.log('🔥 Error obteniendo transacciones para la cuenta $accountId: $e', name: 'AccountRepository');
      throw Exception('No se pudieron cargar las transacciones.');
    }
  }

  /// Llama a un RPC para crear una transferencia entre dos cuentas.
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
      developer.log("🔥 [Repo] Error creando transferencia: $e", name: 'AccountRepository');
      throw Exception('No se pudo realizar la transferencia.');
    }
  }
  
  /// Obtiene la proyección de días restantes para una cuenta.
  Future<double> getAccountProjectionInDays(String accountId) async {
    try {
      final response = await client.rpc(
        'get_burn_rate_projection', 
        params: {'account_id_param': accountId}
      );

      if (response is List && response.isNotEmpty) {
        final firstRow = response.first as Map<String, dynamic>;
        return (firstRow['projection_days'] as num? ?? 0.0).toDouble();
      }
      return 0.0;
    } catch (e, stackTrace) {
      developer.log('🔥 Error obteniendo proyección para la cuenta $accountId: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      return 0.0;
    }
  }

  /// Libera los recursos del repositorio.
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de AccountRepository.', name: 'AccountRepository');
    if (_channel != null) {
      _supabase?.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }

  // --- MÉTODOS PRIVADOS ---

  /// Carga todas las cuentas con su balance calculado y las emite en el stream.
  Future<void> _fetchAccountsWithBalance() async {
    developer.log('🔄 [Repo] Obteniendo cuentas con balance...', name: 'AccountRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await client.rpc(
        'get_accounts_with_balance',
        params: {'p_user_id': userId}
      );

      final accounts = (response as List).map((data) => Account.fromMap(data)).toList();
      if (!_streamController.isClosed) {
        _streamController.add(accounts);
        developer.log('✅ [Repo] ${accounts.length} cuentas enviadas al stream.', name: 'AccountRepository');
      }
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error obteniendo cuentas: $e', name: 'AccountRepository', error: e, stackTrace: stackTrace);
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  /// Configura las suscripciones de Realtime para las cuentas y transacciones.
  /// Se llama una única vez durante la inicialización perezosa.
  void _setupRealtimeSubscriptions() {
    if (_channel != null) return;
    // Usamos _supabase directamente aquí porque sabemos que ya ha sido asignado por _ensureInitialized.
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo-Lazy] Configurando Realtime para Cuentas...', name: 'AccountRepository');
    _channel = _supabase!
        .channel('public:all_tables_for_accounts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accounts',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (_) => _fetchAccountsWithBalance(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (_) => _fetchAccountsWithBalance(),
        )
        .subscribe();
  }
}