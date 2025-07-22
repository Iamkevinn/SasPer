// lib/data/dashboard_repository.dart (COMPLETO Y CORREGIDO)

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class DashboardRepository {
  final SupabaseClient _client;
  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;

  DashboardRepository(this._client);

  Stream<DashboardData> getDashboardDataStream() {
    // Suscripción a cambios en tiempo real (si aún no está activa)
    _subscriptionChannel ??= _client
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

    // Carga inicial de datos
    forceRefresh();
    
    return _dashboardDataController.stream;
  }

  Future<void> forceRefresh({bool silent = true}) async {
    // `silent` puede usarse en el futuro para no mostrar un shimmer en recargas de fondo.
    developer.log('🔄 [Repo] Fetching fresh dashboard data...', name: 'DashboardRepository');
    
    // --- ¡CORRECCIÓN CLAVE AQUÍ! ---
    try {
      // 1. Obtenemos el ID del usuario actual.
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado. No se pueden cargar los datos del dashboard.');
      }

      // 2. Llamamos a la función RPC pasándole el user_id como parámetro.
      final data = await _client.rpc(
        'get_dashboard_data',
        params: {'p_user_id': userId},
      );

      final dashboardData = DashboardData.fromJson(data);
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(dashboardData);
        developer.log('✅ [Repo] Pushed new dashboard data to the stream.', name: 'DashboardRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error fetching dashboard data: $e', name: 'DashboardRepository');
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.addError(e);
      }
    }
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing DashboardRepository resources.', name: 'DashboardRepository');
    if (_subscriptionChannel != null) {
      _client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _dashboardDataController.close();
  }
}