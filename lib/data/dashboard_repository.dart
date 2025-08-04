// lib/data/dashboard_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class DashboardRepository {
  // --- PATRÓN DE INICIALIZACIÓN TEMPRANA (Eager Initialization) ---
  // Este repositorio es crítico y se inicializa intencionadamente al arrancar la app.

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // El getter protege el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! DashboardRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- GESTIÓN DE ESTADO Y CACHÉ ---
  
  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;
  DashboardData? _lastKnownData; // Caché en memoria para carga instantánea.
  bool _isFetching = false; // Flag para prevenir peticiones redundantes.
  Timer? _realtimeDebounceTimer; // Timer para agrupar eventos de Realtime.

  // --- SINGLETON ---
  DashboardRepository._privateConstructor();
  static final DashboardRepository instance = DashboardRepository._privateConstructor();

  // Este método `initialize` se mantiene público y se llama desde el SplashScreen.
  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _setupRealtimeSubscription();
    _isInitialized = true;
    developer.log('✅ DashboardRepository inicializado TEMPRANAMENTE.', name: 'DashboardRepository');
  }

  // --- MÉTODOS DEL REPOSITORIO ---

  /// Devuelve un stream de los datos del dashboard.
  /// Emite datos cacheados al instante y luego busca una actualización.
  Stream<DashboardData> getDashboardDataStream() {
    if (_lastKnownData != null) {
      _dashboardDataController.add(_lastKnownData!);
    } else {
      _dashboardDataController.add(DashboardData.empty());
    }
    forceRefresh();
    return _dashboardDataController.stream;
  }

  /// Configura las suscripciones de Realtime para las tablas relevantes.
  void _setupRealtimeSubscription() {
    // Verificación de seguridad adicional.
    if (_subscriptionChannel != null) {
        client.removeChannel(_subscriptionChannel!);
    }
    _subscriptionChannel = client
        .channel('public:all_tables_for_dashboard')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'accounts', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'goals', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'budgets', callback: (_) => _handleRealtimeUpdate())
        .subscribe();
  }

  /// Agrupa múltiples eventos de Realtime en una sola llamada de refresco.
  void _handleRealtimeUpdate() {
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 700), () {
      developer.log('⚡️ [Repo-Realtime] Cambio detectado. Refrescando datos del dashboard.', name: 'DashboardRepository');
      forceRefresh();
    });
  }

  /// Carga los datos frescos del dashboard desde la base de datos.
  Future<void> forceRefresh({bool silent = true}) async {
    if (_isFetching) {
      developer.log('🟡 [Repo] Petición de refresco del dashboard ignorada: ya hay una en curso.', name: 'DashboardRepository');
      return;
    }
    _isFetching = true;

    if (!silent && _lastKnownData == null) {
       _dashboardDataController.add(DashboardData.empty());
    }
    
    developer.log('🔄 [Repo] Iniciando carga de datos del dashboard por etapas...', name: 'DashboardRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado.');

      // Etapa 1: Balance (rápido)
      final balanceDataMap = await client.rpc('get_dashboard_balance', params: {'p_user_id': userId});
      DashboardData partialData = DashboardData.fromPartialMap(balanceDataMap);
      if (!_dashboardDataController.isClosed) _dashboardDataController.add(partialData);

      // Etapa 2: Detalles (más lento)
      final detailsDataMap = await client.rpc('get_dashboard_details', params: {'p_user_id': userId});
      if (kDebugMode) {
        developer.log('✅ [Repo] Datos DETALLADOS recibidos de Supabase: $detailsDataMap', name: 'DashboardRepository');
      }

      DashboardData fullData = partialData.copyWithDetails(detailsDataMap);
      _lastKnownData = fullData; // Actualizamos la caché

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(fullData);
        developer.log('✅ [Repo] Datos completos del dashboard enviados al stream.', name: 'DashboardRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error durante la carga del dashboard: $e', name: 'DashboardRepository');
      if (!_dashboardDataController.isClosed) _dashboardDataController.addError(e);
    } finally {
      _isFetching = false;
    }
  }

  /// Obtiene los datos del dashboard una sola vez. Ideal para tareas de fondo como widgets.
  Future<DashboardData?> fetchDataForWidget({required String userId}) async {
    developer.log('🔄 [Repo-Widget] Obteniendo datos para widget...', name: 'DashboardRepository');
    try {
      if (userId.isEmpty) {
        developer.log('⚠️ [Repo-Widget] No se proporcionó User ID.', name: 'DashboardRepository');
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
      
      developer.log('✅ [Repo-Widget] Datos para widget obtenidos con éxito. Usuario: ${fullData.fullName}', name: 'DashboardRepository');
      return fullData;
      
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo-Widget] Error obteniendo datos para widget: $e', name: 'DashboardRepository', stackTrace: stackTrace);
      return null;
    }
  }
  
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de DashboardRepository.', name: 'DashboardRepository');
    if (_subscriptionChannel != null) {
      client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _realtimeDebounceTimer?.cancel();
    _dashboardDataController.close();
  }
}