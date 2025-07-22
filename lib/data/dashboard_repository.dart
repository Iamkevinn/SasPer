// lib/data/dashboard_repository.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'dart:developer' as developer;

class DashboardRepository {
  final SupabaseClient _client;
  // Lo inicializamos aquí para poder usar los callbacks
  late final StreamController<DashboardData> _controller;

  DashboardRepository(this._client) {
    _controller = StreamController<DashboardData>.broadcast(
      onListen: () {
        // 2. Se llama a refresh la PRIMERA vez que alguien escucha el stream.
        developer.log('[DashboardRepository] First listener attached. Fetching initial data...', name: 'DashboardRepository');
        forceRefresh();
      },
      onCancel: () {
        developer.log('[DashboardRepository] All listeners detached.', name: 'DashboardRepository');
      }
    );
  }

  Stream<DashboardData> getDashboardDataStream() => _controller.stream;
  
  Future<void> forceRefresh({bool silent = false}) async {
    developer.log('[DashboardRepository] Forcing refresh (silent: $silent)...', name: 'DashboardRepository');
    
    // 1. Emitir un estado de carga si no es una recarga silenciosa
    if (!silent && !_controller.isClosed) {
      _controller.add(DashboardData.empty().copyWith(fullName: 'Actualizando...'));
    }
    
    try {
      final data = await fetchDashboardData();
      if (!_controller.isClosed) {
        _controller.add(data);
        developer.log('[DashboardRepository] Data stream updated.', name: 'DashboardRepository');
      }
    } catch (e, stackTrace) {
      developer.log('Error fetching dashboard data', error: e, stackTrace: stackTrace, name: 'DashboardRepository');
      if (!_controller.isClosed) {
        _controller.addError(e, stackTrace);
      }
    }
  }

  Future<DashboardData> fetchDashboardData() async {
    final response = await _client.rpc('get_dashboard_data');
    developer.log("✅ RAW JSON from get_dashboard_data: $response", name: 'DashboardRepository');
    return DashboardData.fromJson(response as Map<String, dynamic>);
  }
  
  void dispose() {
    developer.log('[DashboardRepository] Disposing controller.', name: 'DashboardRepository');
    _controller.close();
  }
}