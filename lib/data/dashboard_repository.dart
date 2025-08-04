// lib/screens/dashboard_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class DashboardRepository {
  // --- PATRÓN DE INICIALIZACIÓN SEGURA ---

  SupabaseClient? _supabase;

  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! DashboardRepository no ha sido inicializado. Llama a .initialize() al arrancar la app.");
    }
    return _supabase!;
  }
  
  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;
  bool _isInitialized = false;

  DashboardRepository._privateConstructor();
  static final DashboardRepository instance = DashboardRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
      if (_isInitialized) return;
      _supabase = supabaseClient; 
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ DashboardRepository inicializado por primera vez.', name: 'DashboardRepository');
  }

  // --- MÉTODOS DEL REPOSITORIO ---
  
  Stream<DashboardData> getDashboardDataStream() {
    forceRefresh();
    return _dashboardDataController.stream;
  }

  void _setupRealtimeSubscription() {
    _subscriptionChannel = client // Usamos el getter
        .channel('public:all_tables_for_dashboard')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: (payload) => forceRefresh())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'accounts', callback: (payload) => forceRefresh())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'goals', callback: (payload) => forceRefresh())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'budgets', callback: (payload) => forceRefresh())
        .subscribe();
  }

  Future<void> forceRefresh({bool silent = true}) async {
    developer.log('🔄 [Repo] Starting staged dashboard fetch...', name: 'DashboardRepository');
    try {
      final userId = client.auth.currentUser?.id; // Usamos el getter
      if (userId == null) throw Exception('Usuario no autenticado.');

      final balanceDataMap = await client.rpc( // Usamos el getter
        'get_dashboard_balance',
        params: {'p_user_id': userId},
      );
      DashboardData partialData = DashboardData.fromPartialMap(balanceDataMap);

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(partialData);
      }

      final detailsDataMap = await client.rpc( // Usamos el getter
        'get_dashboard_details',
        params: {'p_user_id': userId},
      );
      developer.log('✅ [Repo] Datos DETALLADOS recibidos de Supabase: $detailsDataMap', name: 'DashboardRepository');

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

  /// Obtiene los datos del dashboard una sola vez. Ideal para tareas de fondo.
  Future<DashboardData?> fetchDataForWidget({required String userId}) async {
    developer.log('🔄 [Repo-Widget] Fetching single snapshot for widget...', name: 'DashboardRepository');
    try {
      // --- ¡CORRECCIÓN AQUÍ! ---
      // Reemplazamos todas las llamadas a `_client` por el getter `client`.
      //final userId = client.auth.currentUser?.id;
      if (userId.isEmpty) {
        developer.log('⚠️ [Repo-Widget] No user ID provided for widget data fetch.', name: 'DashboardRepository');
        return null;
      }

       final results = await Future.wait([
        client.rpc('get_dashboard_balance', params: {'p_user_id': userId}),
        client.rpc('get_dashboard_details', params: {'p_user_id': userId}),
      ]);
      

      final balanceMap = results[0] as Map<String, dynamic>;
      final detailsMap = results[1] as Map<String, dynamic>;
      
      DashboardData partialData = DashboardData.fromPartialMap(balanceMap, loadingDetails: false);
      DashboardData fullData = partialData.copyWithDetails(detailsMap);
      
      developer.log('✅ [Repo-Widget] Fetched single snapshot successfully. User: ${fullData.fullName}', name: 'DashboardRepository');
      return fullData;
      
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo-Widget] Error fetching widget data: $e', name: 'DashboardRepository', stackTrace: stackTrace);
      return null;
    }
  }
  
  void dispose() {
    developer.log('❌ [Repo] Disposing DashboardRepository resources.', name: 'DashboardRepository');
    if (_subscriptionChannel != null) {
      client.removeChannel(_subscriptionChannel!); // Usamos el getter
      _subscriptionChannel = null;
    }
    _dashboardDataController.close();
  }
}