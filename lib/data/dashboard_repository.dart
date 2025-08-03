// lib/data/dashboard_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class DashboardRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---

  // 1. El cliente ahora es privado y nullable. No más 'late final'.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      // Si algo intenta usar el repositorio antes de tiempo, obtendremos un error claro
      // en lugar de un 'LateInitializationError' ambiguo.
      throw Exception("¡ERROR! DashboardRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }
  
  // --- FIN DE LOS CAMBIOS CRUCIALES ---

  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;
  bool _isInitialized = false;

  DashboardRepository._privateConstructor();
  static final DashboardRepository instance = DashboardRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
      if (_isInitialized) {
        developer.log('DashboardRepository ya estaba inicializado, saltando.', name: 'DashboardRepository');
        return;
      }
      // Ahora inicializamos nuestra variable nullable _supabase
      _supabase = supabaseClient; 
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ DashboardRepository inicializado por primera vez.', name: 'DashboardRepository');
  }

  // Ahora, TODOS los métodos que usaban `_client` ahora usarán el getter `client`
  
  Stream<DashboardData> getDashboardDataStream() {
    forceRefresh();
    return _dashboardDataController.stream;
  }

  void _setupRealtimeSubscription() {
    // Usamos el getter `client`
    _subscriptionChannel = client 
        .channel('public:all_tables_for_dashboard')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            callback: (payload) => forceRefresh())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'accounts',
            callback: (payload) => forceRefresh())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'goals',
            callback: (payload) => forceRefresh())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'budgets',
            callback: (payload) => forceRefresh())
        .subscribe();
  }

  Future<void> forceRefresh({bool silent = true}) async {
    developer.log('🔄 [Repo] Starting staged dashboard fetch...', name: 'DashboardRepository');
    
    try {
      // Usamos el getter `client`
      final userId = client.auth.currentUser?.id; 
      if (userId == null) {
        throw Exception('Usuario no autenticado.');
      }

      // --- ETAPA 1: Carga lo esencial y más rápido ---
      final balanceDataMap = await client.rpc(
        'get_dashboard_balance',
        params: {'p_user_id': userId},
      );
      DashboardData partialData = DashboardData.fromPartialMap(balanceDataMap);

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(partialData);
      }

      // --- ETAPA 2: Carga los detalles más pesados ---
      final detailsDataMap = await client.rpc(
        'get_dashboard_details',
        params: {'p_user_id': userId},
      );
      DashboardData fullData = partialData.copyWithDetails(detailsDataMap);

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(fullData);
        developer.log('✅ [Repo] Pushed full dashboard data.', name: 'DashboardRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error during staged fetch: $e', name: 'DashboardRepository');
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.addError(e);
      }
    }
  }

  Future<DashboardData?> fetchDataForWidget() async {
    developer.log('🔄 [Repo-Widget] Fetching single snapshot for widget...', name: 'DashboardRepository');
    try {
      // Usamos el getter `client`
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        developer.log('⚠️ [Repo-Widget] No user ID for widget data fetch.', name: 'DashboardRepository');
        return null;
      }

      // 1. Ejecutamos las 3 llamadas en paralelo.
      final results = await Future.wait([
        client.rpc('get_dashboard_balance', params: {'p_user_id': userId}),
        client.rpc('get_dashboard_details', params: {'p_user_id': userId}),
        client.rpc('get_budgets_progress_for_user', params: {'p_user_id': userId}),
      ]);

      // 2. Extraemos los resultados de forma segura.
      final balanceMap = results[0] as Map<String, dynamic>? ?? {};
      final detailsMap = results[1] as Map<String, dynamic>? ?? {};
      final budgetsData = results[2] as List<dynamic>? ?? [];
      
      // 3. Parseamos cada lista de datos que necesitamos.
      final List<Transaction> recentTransactions = (detailsMap['recent_transactions'] as List<dynamic>? ?? [])
          .map((data) => Transaction.fromMap(data as Map<String, dynamic>))
          .toList();
      
      final List<BudgetProgress> budgetsList = budgetsData
          .map((data) => BudgetProgress.fromMap(data as Map<String, dynamic>))
          .toList();

      final List<Goal> goalsList = []; 
      final List<ExpenseByCategory> expenseSummary = [];

      // 4. Creamos la instancia de DashboardData directamente con el constructor.
      final dashboardData = DashboardData(
        totalBalance: (balanceMap['total_balance'] as num? ?? 0).toDouble(),
        fullName: detailsMap['full_name'] as String? ?? 'Usuario', 
        recentTransactions: recentTransactions,
        budgetsProgress: budgetsList,
        featuredBudgets: budgetsList,
        goals: goalsList,
        expenseSummaryForWidget: expenseSummary,
        isLoading: false,
      );
      
      developer.log('✅ [Repo-Widget] Fetched single snapshot successfully. Budgets found: ${dashboardData.featuredBudgets.length}', name: 'DashboardRepository');
      return dashboardData;
      
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo-Widget] Error fetching widget data: $e', name: 'DashboardRepository', stackTrace: stackTrace);
      return null;
    }
  }
  
  void dispose() {
    developer.log('❌ [Repo] Disposing DashboardRepository resources.', name: 'DashboardRepository');
    if (_subscriptionChannel != null) {
      // Usamos el getter `client`
      client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _dashboardDataController.close();
  }
}