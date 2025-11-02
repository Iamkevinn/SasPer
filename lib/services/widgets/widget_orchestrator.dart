import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/services/widgets/core/widget_config.dart';
import 'package:sasper/services/widgets/core/widget_performance_tracker.dart';
import 'package:sasper/services/widgets/core/widget_types.dart';
import 'package:sasper/services/widgets/data/widget_cache_manager.dart';
import 'package:sasper/services/widgets/rendering/widget_render_service.dart';
import 'package:sasper/utils/connectivity_checker.dart';
import 'package:sasper/utils/currency_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinador principal que orquesta todas las actualizaciones de widgets
class WidgetOrchestrator {
  static const String _logName = 'WidgetOrchestrator';
  
  final WidgetPerformanceTracker _tracker = WidgetPerformanceTracker();
  final WidgetCacheManager _cache = WidgetCacheManager.instance;
  final ConnectivityChecker _connectivity = ConnectivityChecker.instance;

  // Servicios especializados (se crearán en la siguiente parte)
  // final FinancialHealthWidgetService _healthService;
  // final GoalsWidgetService _goalsService;
  // etc.

  /// Actualiza todos los widgets desde el dashboard principal
  Future<void> updateAllFromDashboard(
    DashboardData data,
    BuildContext context,
  ) async {
    _tracker.start('update_all_widgets');

    if (kDebugMode) {
      developer.log(
        '🚀 Iniciando actualización completa de widgets',
        name: _logName,
      );
      developer.log(
        '📊 Balance: ${data.totalBalance}, '
        'Presupuestos: ${data.featuredBudgets.length}, '
        'Transacciones: ${data.recentTransactions.length}',
        name: _logName,
      );
    }

    try {
      // Verificar conectividad
      final hasConnection = await _connectivity.hasConnection();
      if (!hasConnection && kDebugMode) {
        developer.log('⚠️ Sin conexión a internet', name: _logName);
      }

      // It's crucial to check if the widget is still mounted before proceeding
      if (!context.mounted) return;

      // Ejecutar actualizaciones en paralelo con prioridad
      await Future.wait([
        _updateDashboardWidget(data, context),
        _updateFinancialHealthWidget(),
        _updateGoalsWidget(),
      ]);

      // Actualizaciones de menor prioridad
      await Future.wait([
        _updateMonthlyComparisonWidget(),
        _updateUpcomingPaymentsWidget(),
        _updateNextPaymentWidget(),
      ]);

      // Guardar estado válido como backup
      await _saveLastValidState(data);

      if (kDebugMode) {
        developer.log('✅ Actualización completa exitosa', name: _logName);
      }
    } catch (e, st) {
      developer.log(
        '🔥 Error en actualización de widgets: $e',
        name: _logName,
        error: e,
        stackTrace: st,
      );
      
      // Intentar recuperar del último estado válido
      await _restoreLastValidState();
    } finally {
      _tracker.stop('update_all_widgets');
      if (kDebugMode) {
        _tracker.printSummary();
      }
    }
  }

  Future<void> _updateDashboardWidget(
    DashboardData data,
    BuildContext context,
  ) async {
    _tracker.start('dashboard_widget');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      // Verificar si los datos han cambiado
      final dataChanged = await _cache.hasChanged('dashboard_data', {
        'balance': data.totalBalance,
        'budgets': data.featuredBudgets.length,
        'transactions': data.recentTransactions.length,
      });
      
       if (!context.mounted) return;

      if (!dataChanged && kDebugMode) {
        developer.log('ℹ️ Dashboard sin cambios, saltando actualización', name: _logName);
        return;
      }

      // Formatear datos
      final formattedBalance = CurrencyFormatter.format(data.totalBalance);
      final budgetsJson = jsonEncode(
        data.featuredBudgets.map((b) => b.toJson()).toList(),
      );
      final transactionsJson = jsonEncode(
        data.recentTransactions.take(3).map((t) => t.toJson()).toList(),
      );

      // Renderizar gráfico solo si hay datos
      String? chartPath;
      if (data.expenseSummaryForWidget.isNotEmpty) {
        _tracker.start('chart_render');
        
        final chartData = data.expenseSummaryForWidget
            .map((e) => CategoryData(
                  category: e.category,
                  amount: e.totalSpent.abs(),
                ))
            .toList();

        final chartBytes = await WidgetRenderService.renderPieChart(
          data: chartData,
          isDarkMode: isDark,
          size: WidgetSize.medium,
        );

        if (chartBytes != null) {
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_chart_v2.png');
          await file.writeAsBytes(chartBytes);
          chartPath = file.path;
        }

        _tracker.stop('chart_render');
      }

      // Guardar en HomeWidget
      await Future.wait([
        HomeWidget.saveWidgetData<String>('total_balance', formattedBalance),
        HomeWidget.saveWidgetData<String>('widget_chart_path', chartPath ?? ''),
        HomeWidget.saveWidgetData<String>('featured_budgets_json', budgetsJson),
        HomeWidget.saveWidgetData<String>('recent_transactions_json', transactionsJson),
      ]);

      // Notificar widgets
      await HomeWidget.updateWidget(
        name: WidgetType.dashboard.providerName,
        androidName: WidgetType.dashboard.providerName,
      );

      // Actualizar caché
      await _cache.save('dashboard_data', {
        'balance': data.totalBalance,
        'chart_path': chartPath,
        'budgets': budgetsJson,
        'transactions': transactionsJson,
      });

    } finally {
      _tracker.stop('dashboard_widget');
    }
  }

  Future<void> _updateFinancialHealthWidget() async {
    _tracker.start('financial_health_widget');
    
    try {
      // Lógica específica (se implementará en servicios especializados)
      // Por ahora, placeholder
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      _tracker.stop('financial_health_widget');
    }
  }

  Future<void> _updateGoalsWidget() async {
    _tracker.start('goals_widget');
    
    try {
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      _tracker.stop('goals_widget');
    }
  }

  Future<void> _updateMonthlyComparisonWidget() async {
    _tracker.start('monthly_comparison_widget');
    
    try {
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      _tracker.stop('monthly_comparison_widget');
    }
  }

  Future<void> _updateUpcomingPaymentsWidget() async {
    _tracker.start('upcoming_payments_widget');
    
    try {
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      _tracker.stop('upcoming_payments_widget');
    }
  }

  Future<void> _updateNextPaymentWidget() async {
    _tracker.start('next_payment_widget');
    
    try {
      await Future.delayed(const Duration(milliseconds: 100));
    } finally {
      _tracker.stop('next_payment_widget');
    }
  }

  Future<void> _saveLastValidState(DashboardData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        WidgetConfig.lastValidStateKey,
        jsonEncode({
          'balance': data.totalBalance,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      developer.log('⚠️ Error guardando estado válido: $e', name: _logName);
    }
  }

  Future<void> _restoreLastValidState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateJson = prefs.getString(WidgetConfig.lastValidStateKey);
      
      if (stateJson != null) {
        final state = jsonDecode(stateJson);
        developer.log(
          '🔄 Restaurando último estado válido del ${state['timestamp']}',
          name: _logName,
        );
        // Lógica de restauración
      }
    } catch (e) {
      developer.log('⚠️ Error restaurando estado: $e', name: _logName);
    }
  }
}
