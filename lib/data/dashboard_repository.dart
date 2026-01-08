// lib/data/dashboard_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class DashboardRepository {
  // --- PATRÓN DE INICIALIZACIÓN TEMPRANA (Eager Initialization) ---
  SupabaseClient? _supabase;
  bool _isInitialized = false;

  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! DashboardRepository no ha sido inicializado.");
    }
    return _supabase!;
  }

  // --- GESTIÓN DE ESTADO Y CACHÉ ---
  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;
  DashboardData? _lastKnownData;
  bool _isFetching = false;
  Timer? _realtimeDebounceTimer;

  // --- SINGLETON ---
  DashboardRepository._privateConstructor();
  static final DashboardRepository instance =
      DashboardRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _setupRealtimeSubscription();
    _isInitialized = true;
    developer.log('✅ DashboardRepository inicializado TEMPRANAMENTE.',
        name: 'DashboardRepository');
  }

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  Stream<DashboardData> getDashboardDataStream() {
    if (_lastKnownData != null) {
      _dashboardDataController.add(_lastKnownData!);
    } else {
      _dashboardDataController.add(DashboardData.empty());
    }
    forceRefresh();
    return _dashboardDataController.stream;
  }

  void _setupRealtimeSubscription() {
    if (_subscriptionChannel != null) {
      client.removeChannel(_subscriptionChannel!);
    }
    _subscriptionChannel = client
        .channel('public:all_tables_for_dashboard')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'accounts',
            callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'goals',
            callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'budgets',
            callback: (_) => _handleRealtimeUpdate())
        .subscribe();
  }

  void _handleRealtimeUpdate() {
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 700), () {
      developer.log(
          '⚡️ [Repo-Realtime] Cambio detectado. Refrescando datos del dashboard.',
          name: 'DashboardRepository');
      forceRefresh();
    });
  }

  
  /// Carga los datos frescos del dashboard desde la base de datos.
  Future<void> forceRefresh({bool silent = true}) async {
    if (_isFetching) {
      developer.log(
          '🟡 [Repo] Petición de refresco del dashboard ignorada: ya hay una en curso.',
          name: 'DashboardRepository');
      return;
    }
    _isFetching = true;

    if (!silent && _lastKnownData == null) {
      _dashboardDataController.add(DashboardData.empty());
    }

    developer.log(
        '🔄 [Repo] Iniciando carga de datos del dashboard por etapas...',
        name: 'DashboardRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado.');

      // Etapa 1: Balance y Health Score (rápido)
      final balanceDataMap = await client
          .rpc('get_dashboard_balance', params: {'p_user_id': userId});
      DashboardData partialData = DashboardData.fromPartialMap(balanceDataMap);
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(partialData);
      }

      final startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endDate =
          DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

      // Etapa 2: Llamadas a RPCs para los detalles
      final detailsResults = await Future.wait([
        client.rpc('get_recent_transactions',
            params: {'user_id_param': userId}).catchError((_) => []),
        client.rpc('get_user_goals',
            params: {'user_id_param': userId}).catchError((_) => []),
        client.rpc('get_active_budgets_with_progress',
            params: {'p_user_id': userId}).catchError((_) => []),
        client.rpc('get_expense_summary_by_category', params: {
          'p_user_id': userId,
          'client_date': DateFormat('yyyy-MM-dd').format(DateTime.now())
        }).catchError((_) => []),
        client.rpc('get_category_spending_summary', params: {
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        }).catchError((_) => []),
        // --- 👇 CAMBIO CLAVE: AÑADIR LA LLAMADA A LA RPC DE ALERTAS ---
        client.rpc('get_dashboard_alerts',
            params: {'p_user_id': userId}).catchError((_) => []),
      ]);

      final categorySummaryData = (detailsResults[4] as List)
          .map((item) => CategorySpending(
                categoryName:
                    item['category_name'] as String? ?? 'Sin Categoría',
                totalAmount: (item['total_amount'] as num? ?? 0).toDouble(),
                color: item['color'] as String? ?? '#CCCCCC',
              ))
          .toList();

      // Reconstruimos el mapa que `copyWithDetails` espera, incluyendo las alertas.
      final detailsDataMap = {
        'recent_transactions': detailsResults[0],
        'goals': detailsResults[1],
        'budgets_progress': detailsResults[2],
        'expense_summary_for_widget': detailsResults[3],
        // --- 👇 CAMBIO CLAVE: AÑADIR LAS ALERTAS AL MAPA ---
        'alerts': detailsResults[5],
      };

      if (kDebugMode) {
        developer.log(
            '✅ [Repo] Datos DETALLADOS recibidos de Supabase: $detailsDataMap',
            name: 'DashboardRepository');
      }

      DashboardData fullData = partialData.copyWithDetails(detailsDataMap);

      fullData = fullData.copyWith(
        categorySpendingSummary: categorySummaryData,
        isLoading: false,
      );

      _lastKnownData = fullData;

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(fullData);
        developer.log(
            '✅ [Repo] Datos completos del dashboard enviados al stream.',
            name: 'DashboardRepository');
      }
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error durante la carga del dashboard: $e',
          name: 'DashboardRepository', error: e, stackTrace: stackTrace);
      if (kDebugMode) {
        print("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥");
        print("🔥 ERROR FATAL EN DASHBOARD REPOSITORY 🔥");
        print("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥");
        print("ERROR: $e");
        print("STACK TRACE: $stackTrace");
        print("🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥");
      }
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.addError(e);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<List<Manifestation>> getManifestations({required String userId}) async {
    final dashboardData = await fetchDataForWidget(userId: userId);
    if (dashboardData == null) return [];

    // Convertimos los items a Manifestation
    final manifestations = (dashboardData.expenseSummaryForWidget as List)
        .map((item) => Manifestation.fromMap(item as Map<String, dynamic>))
        .toList();

    return manifestations;
    }



  /// Obtiene los datos del dashboard una sola vez. Ideal para tareas de fondo como widgets.
  Future<DashboardData?> fetchDataForWidget({required String userId}) async {
    developer.log('🔄 [Repo-Widget] Obteniendo datos para widget...',
        name: 'DashboardRepository');
    try {
      if (userId.isEmpty) {
        developer.log('⚠️ [Repo-Widget] No se proporcionó User ID.',
            name: 'DashboardRepository');
        return null;
      }

      // --- ¡CAMBIO CLAVE! También usamos las RPCs individuales aquí ---
      final results = await Future.wait([
        client.rpc('get_dashboard_balance', params: {'p_user_id': userId}),
        // Replicamos la misma lógica de `forceRefresh`
        client.rpc('get_recent_transactions',
            params: {'user_id_param': userId}).catchError((_) => []),
        client.rpc('get_user_goals',
            params: {'user_id_param': userId}).catchError((_) => []),
        client.rpc('get_active_budgets_with_progress',
            params: {'p_user_id': userId}).catchError((_) => []),
        client.rpc('get_expense_summary_by_category', params: {
          'p_user_id': userId,
          'client_date': DateFormat('yyyy-MM-dd').format(DateTime.now())
        }).catchError((_) => []),
      ]);

      final balanceMap = results[0] as Map<String, dynamic>;
      final detailsMap = {
        'recent_transactions': results[1],
        'goals': results[2],
        'budgets_progress': results[3],
        'expense_summary_for_widget': results[4],
      };

      DashboardData partialData =
          DashboardData.fromPartialMap(balanceMap, loadingDetails: false);
      DashboardData fullData = partialData.copyWithDetails(detailsMap);

      developer.log(
          '✅ [Repo-Widget] Datos para widget obtenidos con éxito. Usuario: ${fullData.fullName}',
          name: 'DashboardRepository');
      return fullData;
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo-Widget] Error obteniendo datos para widget: $e',
          name: 'DashboardRepository', stackTrace: stackTrace);
      return null;
    }
  }

  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de DashboardRepository.',
        name: 'DashboardRepository');
    if (_subscriptionChannel != null) {
      client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _realtimeDebounceTimer?.cancel();
    _dashboardDataController.close();
  }
}
