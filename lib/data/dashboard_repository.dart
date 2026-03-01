// lib/data/dashboard_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class DashboardRepository {
  SupabaseClient? _supabase;
  bool _isInitialized = false;

  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! DashboardRepository no ha sido inicializado.");
    }
    return _supabase!;
  }

  final _dashboardDataController = StreamController<DashboardData>.broadcast();
  RealtimeChannel? _subscriptionChannel;
  DashboardData? _lastKnownData;
  bool _isFetching = false;
  Timer? _realtimeDebounceTimer;

  DashboardRepository._privateConstructor();
  static final DashboardRepository instance = DashboardRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _setupRealtimeSubscription();
    _isInitialized = true;
    developer.log('✅ DashboardRepository inicializado TEMPRANAMENTE.', name: 'DashboardRepository');
  }

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
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'accounts', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'goals', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'budgets', callback: (_) => _handleRealtimeUpdate())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'debts', callback: (_) => _handleRealtimeUpdate()) // Añadimos debts al realtime
        .subscribe();
  }

  void _handleRealtimeUpdate() {
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 700), () {
      developer.log('⚡️ [Repo-Realtime] Cambio detectado. Refrescando datos del dashboard.', name: 'DashboardRepository');
      forceRefresh();
    });
  }

  Future<void> forceRefresh({bool silent = true}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!silent && _lastKnownData == null) {
      _dashboardDataController.add(DashboardData.empty());
    }

    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado.');

      // Etapa 1: Balance y Health Score (rápido)
      final balanceDataMap = await client.rpc('get_dashboard_balance', params: {'p_user_id': userId});
      DashboardData partialData = DashboardData.fromPartialMap(balanceDataMap);
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(partialData);
      }

      final startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      final endDate = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

      // Etapa 2: Llamadas a RPCs para los detalles (AÑADIMOS DEUDAS EN EL ÍNDICE 6)
      final detailsResults = await Future.wait([
        client.rpc('get_recent_transactions', params: {'user_id_param': userId}).catchError((_) => []), // 0
        client.rpc('get_user_goals', params: {'user_id_param': userId}).catchError((_) =>[]), // 1
        client.rpc('get_active_budgets_with_progress', params: {'p_user_id': userId}).catchError((_) =>[]), // 2
        client.rpc('get_expense_summary_by_category', params: {
          'p_user_id': userId,
          'client_date': DateFormat('yyyy-MM-dd').format(DateTime.now())
        }).catchError((_) =>[]), // 3
        client.rpc('get_category_spending_summary', params: {
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
        }).catchError((_) =>[]), // 4
        client.rpc('get_dashboard_alerts', params: {'p_user_id': userId}).catchError((_) =>[]), // 5
        // --- 👇 PETICIÓN NUEVA: BUSCAMOS LAS DEUDAS ---
        client.from('debts').select('type, current_balance, impact_type').eq('user_id', userId).eq('status', 'active').catchError((_) =>[]), // 6
      ]);

      // --- 👇 CÁLCULOS CONTABLES INTELIGENTES ---
      double totalDebt = 0.0;
      double restrictedFromDebts = 0.0;
      
      final debtsData = detailsResults[6] as List<dynamic>? ??[];
      for (var d in debtsData) {
        final type = d['type'];
        final impact = d['impact_type'];
        final balance = (d['current_balance'] as num? ?? 0.0).toDouble();

        if (type == 'debt') {
          totalDebt += balance; // Dinero que DEBES pagar
          if (impact == 'restricted') {
            restrictedFromDebts += balance; // Dinero que te prestaron y debes reservar
          }
        }
      }

      double restrictedFromGoals = 0.0;
      final goalsData = detailsResults[1] as List<dynamic>? ??[];
      for (var g in goalsData) {
        restrictedFromGoals += (g['current_amount'] as num? ?? 0.0).toDouble(); // Dinero guardado en metas
      }

      // Matemáticas Finales
      double restrictedBalance = restrictedFromDebts + restrictedFromGoals;
      double availableBalance = partialData.totalBalance - restrictedBalance;
      // ------------------------------------------

      final categorySummaryData = (detailsResults[4] as List)
          .map((item) => CategorySpending(
                categoryName: item['category_name'] as String? ?? 'Sin Categoría',
                totalAmount: (item['total_amount'] as num? ?? 0).toDouble(),
                color: item['color'] as String? ?? '#CCCCCC',
              ))
          .toList();

      final detailsDataMap = {
        'recent_transactions': detailsResults[0],
        'goals': detailsResults[1],
        'budgets_progress': detailsResults[2],
        'expense_summary_for_widget': detailsResults[3],
        'alerts': detailsResults[5],
        // Pasamos la nueva info calculada al modelo
        'available_balance': availableBalance,
        'restricted_balance': restrictedBalance,
        'total_debt': totalDebt,
      };

      DashboardData fullData = partialData.copyWithDetails(detailsDataMap);

      fullData = fullData.copyWith(
        categorySpendingSummary: categorySummaryData,
        isLoading: false,
      );

      _lastKnownData = fullData;

      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.add(fullData);
      }
    } catch (e, stackTrace) {
      developer.log('🔥 [Repo] Error durante la carga del dashboard: $e', name: 'DashboardRepository', error: e, stackTrace: stackTrace);
      if (!_dashboardDataController.isClosed) {
        _dashboardDataController.addError(e);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<List<Manifestation>> getManifestations({required String userId}) async {
    final dashboardData = await fetchDataForWidget(userId: userId);
    if (dashboardData == null) return[];

    final manifestations = (dashboardData.expenseSummaryForWidget as List)
        .map((item) => Manifestation.fromMap(item as Map<String, dynamic>))
        .toList();

    return manifestations;
  }

  Future<DashboardData?> fetchDataForWidget({required String userId}) async {
    try {
      if (userId.isEmpty) return null;

      // Hacemos el mismo ajuste de llamadas aquí para los widgets
      final results = await Future.wait([
        client.rpc('get_dashboard_balance', params: {'p_user_id': userId}), // 0
        client.rpc('get_recent_transactions', params: {'user_id_param': userId}).catchError((_) => []), // 1
        client.rpc('get_user_goals', params: {'user_id_param': userId}).catchError((_) =>[]), // 2
        client.rpc('get_active_budgets_with_progress', params: {'p_user_id': userId}).catchError((_) =>[]), // 3
        client.rpc('get_expense_summary_by_category', params: {
          'p_user_id': userId,
          'client_date': DateFormat('yyyy-MM-dd').format(DateTime.now())
        }).catchError((_) =>[]), // 4
        client.from('debts').select('type, current_balance, impact_type').eq('user_id', userId).eq('status', 'active').catchError((_) =>[]), // 5
      ]);

      final balanceMap = results[0] as Map<String, dynamic>;
      
      // Mismos cálculos contables para los widgets
      double totalDebt = 0.0;
      double restrictedFromDebts = 0.0;
      final debtsData = results[5] as List<dynamic>? ??[];
      for (var d in debtsData) {
        if (d['type'] == 'debt') {
          totalDebt += (d['current_balance'] as num? ?? 0.0).toDouble();
          if (d['impact_type'] == 'restricted') {
            restrictedFromDebts += (d['current_balance'] as num? ?? 0.0).toDouble();
          }
        }
      }

      double restrictedFromGoals = 0.0;
      final goalsData = results[2] as List<dynamic>? ??[];
      for (var g in goalsData) {
        restrictedFromGoals += (g['current_amount'] as num? ?? 0.0).toDouble();
      }

      double tBalance = (balanceMap['total_balance'] as num?)?.toDouble() ?? 0.0;
      double restrictedBalance = restrictedFromDebts + restrictedFromGoals;
      double availableBalance = tBalance - restrictedBalance;

      final detailsMap = {
        'recent_transactions': results[1],
        'goals': results[2],
        'budgets_progress': results[3],
        'expense_summary_for_widget': results[4],
        'available_balance': availableBalance,
        'restricted_balance': restrictedBalance,
        'total_debt': totalDebt,
      };

      DashboardData partialData = DashboardData.fromPartialMap(balanceMap, loadingDetails: false);
      DashboardData fullData = partialData.copyWithDetails(detailsMap);

      return fullData;
    } catch (e, stackTrace) {
      developer.log('🔥[Repo-Widget] Error obteniendo datos para widget: $e', name: 'DashboardRepository', stackTrace: stackTrace);
      return null;
    }
  }

  void dispose() {
    if (_subscriptionChannel != null) {
      client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _realtimeDebounceTimer?.cancel();
    _dashboardDataController.close();
  }
}