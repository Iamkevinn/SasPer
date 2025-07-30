// lib/data/dashboard_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class DashboardRepository {
  // 1. La variable del cliente es 'late final'. 'late' significa que
  // prometemos inicializarla antes de usarla, y 'final' que solo
  // se le asignará un valor una vez.
  late final SupabaseClient _client;

  // 2. El StreamController y el canal de Realtime ahora son parte del Singleton.
  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;

  bool _isInitialized = false;

  // 3. Constructor privado para prevenir la creación de instancias desde fuera.
  DashboardRepository._privateConstructor();

  // 4. La instancia estática y final que guarda el único objeto de esta clase.
  static final DashboardRepository instance = DashboardRepository._privateConstructor();

  // 5. El método de inicialización público. Se llamará desde main.dart.
  void initialize(SupabaseClient client) {
      // Si ya ha sido inicializado, simplemente no hacemos nada.
      if (_isInitialized) {
        developer.log('DashboardRepository ya estaba inicializado, saltando.', name: 'DashboardRepository');
        return;
      }
      _client = client;
      _setupRealtimeSubscription();
      _isInitialized = true; // Levantamos la bandera
      developer.log('✅ DashboardRepository inicializado por primera vez.', name: 'DashboardRepository');
    }


  // Ahora, los métodos del repositorio usan la variable de instancia `_client`.
  
  Stream<DashboardData> getDashboardDataStream() {
    // La primera vez que alguien pida el stream, forzamos la carga inicial.
    forceRefresh();
    return _dashboardDataController.stream;
  }

  // Hemos movido la lógica de la suscripción a su propio método para más claridad.
  void _setupRealtimeSubscription() {
    _subscriptionChannel = _client
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
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado.');
      }

      // --- ETAPA 1: Carga lo esencial y más rápido ---
      final balanceDataMap = await _client.rpc(
        'get_dashboard_balance',
        params: {'p_user_id': userId},
      );
      DashboardData partialData = DashboardData.fromPartialMap(balanceDataMap);

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(partialData);
      }

      // --- ETAPA 2: Carga los detalles más pesados ---
      final detailsDataMap = await _client.rpc(
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

  /// Obtiene los datos del dashboard una sola vez, sin usar streams.
  /// Ideal para ser llamado desde un contexto de segundo plano como el widget.
  Future<DashboardData?> fetchDataForWidget() async {
    developer.log('🔄 [Repo-Widget] Fetching single snapshot for widget...', name: 'DashboardRepository');
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        developer.log('⚠️ [Repo-Widget] No user ID for widget data fetch.', name: 'DashboardRepository');
        return null;
      }

      final results = await Future.wait([
        _client.rpc('get_dashboard_balance', params: {'p_user_id': userId}),
        _client.rpc('get_dashboard_details', params: {'p_user_id': userId}),
      ]);

      final dashboardData = DashboardData.fromPartialMap(results[0])
                                       .copyWithDetails(results[1]);
      
      developer.log('✅ [Repo-Widget] Fetched single snapshot successfully.', name: 'DashboardRepository');
      return dashboardData;
    } catch (e) {
      developer.log('🔥 [Repo-Widget] Error fetching widget data: $e', name: 'DashboardRepository');
      return null;
    }
  }

  // Aunque el Singleton vive para siempre, es una buena práctica tener
  // un método para limpiar recursos si la app lo necesitara en un futuro.
  // Por ahora, no lo llamaremos desde ningún sitio.
  void dispose() {
    developer.log('❌ [Repo] Disposing DashboardRepository resources.', name: 'DashboardRepository');
    if (_subscriptionChannel != null) {
      _client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _dashboardDataController.close();
  }
}