// lib/data/dashboard_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart'; // Necesario para kDebugMode
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

  // --- GESTIÓN DE ESTADO Y CACHÉ ---
  
  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;
  bool _isInitialized = false;

  // OPTIMIZACIÓN (IMPACTO ALTO): Añadimos una caché en memoria.
  // Guardará el último estado exitoso de DashboardData.
  DashboardData? _lastKnownData;

  // OPTIMIZACIÓN (PREVENCIÓN DE CONDICIONES DE CARRERA): Flag de control.
  // Evita que se lancen múltiples peticiones `forceRefresh` a la vez.
  bool _isFetching = false;

  // --- SINGLETON ---
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

  // OPTIMIZACIÓN (CARGA INSTANTÁNEA): Este método ahora es mucho más inteligente.
  Stream<DashboardData> getDashboardDataStream() {
    // 1. Si ya tenemos datos en caché, los emitimos INMEDIATAMENTE.
    //    Esto hace que la UI del Dashboard se pinte al instante al volver a la pantalla.
    if (_lastKnownData != null) {
      _dashboardDataController.add(_lastKnownData!);
    } else {
      // Si no hay nada en caché (primer arranque), emitimos un estado de carga.
      _dashboardDataController.add(DashboardData.empty());
    }

    // 2. Lanzamos un refresco en segundo plano para obtener datos frescos.
    //    La UI ya está mostrando datos (viejos o de carga), por lo que la app se siente rápida.
    forceRefresh();

    // 3. Devolvemos el stream para que la UI se actualice cuando lleguen los datos frescos.
    return _dashboardDataController.stream;
  }

  void _setupRealtimeSubscription() {
    _subscriptionChannel = client
        .channel('public:all_tables_for_dashboard')
        // OPTIMIZACIÓN (DEBOUNCING): Añadimos un pequeño retardo. Si 5 transacciones
        // se actualizan en 100ms, solo se hará una llamada a `forceRefresh` en lugar de 5.
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: (payload) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'accounts', callback: (payload) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'goals', callback: (payload) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'budgets', callback: (payload) => _handleRealtimeUpdate())
        .subscribe();
  }

  // OPTIMIZACIÓN: Función intermediaria para Realtime para evitar múltiples llamadas.
  Timer? _realtimeDebounceTimer;
  void _handleRealtimeUpdate() {
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      developer.log('⚡️ [Repo-Realtime] Cambio detectado. Refrescando datos.', name: 'DashboardRepository');
      forceRefresh();
    });
  }

  Future<void> forceRefresh({bool silent = true}) async {
    // OPTIMIZACIÓN (PREVENCIÓN DE PETICIONES REDUNDANTES):
    // Si ya hay una petición en curso, no hacemos nada.
    if (_isFetching) {
      developer.log('🟡 [Repo] Petición de refresco ignorada: ya hay una en curso.', name: 'DashboardRepository');
      return;
    }

    _isFetching = true; // Bloqueamos nuevas peticiones.

    if (!silent && _lastKnownData == null) {
       _dashboardDataController.add(DashboardData.empty());
    }
    
    developer.log('🔄 [Repo] Iniciando carga de datos por etapas...', name: 'DashboardRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado.');

      // --- Etapa 1: Cargar balance (rápido) ---
      final balanceDataMap = await client.rpc('get_dashboard_balance', params: {'p_user_id': userId});
      DashboardData partialData = DashboardData.fromPartialMap(balanceDataMap);

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(partialData);
      }

      // --- Etapa 2: Cargar detalles (lento) ---
      final detailsDataMap = await client.rpc('get_dashboard_details', params: {'p_user_id': userId});
      if (kDebugMode) {
        developer.log('✅ [Repo] Datos DETALLADOS recibidos de Supabase: $detailsDataMap', name: 'DashboardRepository');
      }

      DashboardData fullData = partialData.copyWithDetails(detailsDataMap);

      // ¡Guardamos el resultado exitoso en nuestra caché!
      _lastKnownData = fullData;

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(fullData);
        developer.log('✅ [Repo] Datos completos enviados al stream.', name: 'DashboardRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error durante la carga por etapas: $e', name: 'DashboardRepository');
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.addError(e);
      }
    } finally {
      _isFetching = false; // Desbloqueamos para futuras peticiones.
    }
  }

  /// (Sin cambios) Obtiene los datos del dashboard una sola vez. Ideal para tareas de fondo.
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
    developer.log('❌ [Repo] Liberando recursos de DashboardRepository.', name: 'DashboardRepository');
    client.removeChannel(_subscriptionChannel!);
    _subscriptionChannel = null;
    _realtimeDebounceTimer?.cancel();
    _dashboardDataController.close();
  }
}