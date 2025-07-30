// lib/screens/analysis_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Repositorios y Modelos
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/analysis_models.dart';

// Widgets de Gráficos
import 'package:sasper/widgets/analysis_charts/heatmap_section.dart';
import 'package:sasper/widgets/analysis_charts/monthly_cashflow_chart.dart';
import 'package:sasper/widgets/analysis_charts/net_worth_trend_chart.dart';
import 'package:sasper/widgets/analysis_charts/income_expense_bar_chart.dart';
import 'package:sasper/widgets/analysis_charts/category_comparison_chart.dart';
import 'package:sasper/widgets/analysis_charts/expense_pie_chart.dart';
import 'package:sasper/widgets/analysis_charts/income_pie_chart.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => AnalysisScreenState();
}

class AnalysisScreenState extends State<AnalysisScreen> {
  // Obtenemos la instancia del Singleton.
  final AnalysisRepository _repository = AnalysisRepository.instance;

  late Future<AnalysisData> _analysisFuture;
  RealtimeChannel? _transactionsChannel;

  @override
  void initState() {
    super.initState();
    // La primera carga se hace a través del FutureBuilder, usando el Singleton.
    _analysisFuture = _repository.fetchAllAnalysisData();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    // Obtenemos el cliente de Supabase una sola vez de forma segura.
    final client = Supabase.instance.client;

    _transactionsChannel = client
        .channel('public:transactions:analysis')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) {
            // Un pequeño retraso para asegurar que la DB se ha actualizado
            // antes de pedir los nuevos datos agregados.
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _handleRefresh();
              }
            });
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    // Es importante cancelar la suscripción y limpiar el canal.
    if (_transactionsChannel != null) {
      Supabase.instance.client.removeChannel(_transactionsChannel!);
      _transactionsChannel = null;
    }
    super.dispose();
  }

  /// Dispara una recarga de los datos de análisis.
  /// Es llamado por el RefreshIndicator y la suscripción de Realtime.
  Future<void> _handleRefresh() async {
    // Reasignamos el future, lo que hará que el FutureBuilder se reconstruya y muestre los nuevos datos.
    if (mounted) {
      setState(() {
        _analysisFuture = _repository.fetchAllAnalysisData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Análisis Detallado',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<AnalysisData>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _buildChartsShimmer();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: EmptyStateCard(
                  title: 'Ocurrió un Error',
                  message:
                      'No se pudieron cargar los datos. Intenta refrescar la pantalla.\nError: ${snapshot.error}',
                  icon: Iconsax.warning_2,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
                child: EmptyStateCard(
              title: 'Sin Datos',
              message: 'No hay suficientes datos para generar un análisis.',
              icon: Iconsax.chart_21,
            ));
          }

          final analysisData = snapshot.data!;

          // Lógica para comprobar si TODOS los datos están vacíos
          final bool hasDataToShow = analysisData.expensePieData.isNotEmpty ||
              analysisData.cashflowBarData.isNotEmpty ||
              analysisData.netWorthLineData.isNotEmpty ||
              analysisData.categoryComparisonData.isNotEmpty ||
              analysisData.incomePieData.isNotEmpty ||
              analysisData.incomeExpenseBarData.isNotEmpty ||
              analysisData.heatmapData.isNotEmpty;

          if (!hasDataToShow) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Stack(
                children: [
                  ListView(), // ListView vacío para que el RefreshIndicator funcione
                  const Center(
                    child: EmptyStateCard(
                      title: 'Sin Datos Suficientes',
                      message:
                          'Aún no hay suficientes transacciones para generar un análisis detallado.',
                      icon: Iconsax.chart_21,
                    ),
                  ),
                ],
              ),
            );
          }

          // 1. Define las fechas que usará el Heatmap.
          final today = DateTime.now();
          final heatmapStartDate =
              today.subtract(const Duration(days: 119)); // Rango de 120 días

          // Crea una lista con los widgets de los gráficos para organizar el código.
          final List<Widget> chartWidgets = [
            if (analysisData.heatmapData.isNotEmpty)
              // 3. Pasa las fechas al constructor del widget.
              HeatmapSection(
                data: analysisData.heatmapData,
                startDate: heatmapStartDate,
                endDate: today,
              ),
            if (analysisData.cashflowBarData.isNotEmpty)
              MonthlyCashflowChart(data: analysisData.cashflowBarData),
            if (analysisData.netWorthLineData.isNotEmpty)
              NetWorthTrendChart(data: analysisData.netWorthLineData),
            if (analysisData.incomeExpenseBarData.isNotEmpty)
              IncomeExpenseBarChart(data: analysisData.incomeExpenseBarData),
            if (analysisData.categoryComparisonData.isNotEmpty)
              CategoryComparisonChart(
                  data: analysisData.categoryComparisonData),
            if (analysisData.expensePieData.isNotEmpty)
              ExpensePieChart(data: analysisData.expensePieData),
            if (analysisData.incomePieData.isNotEmpty)
              IncomePieChart(data: analysisData.incomePieData),
          ];
          // Si, después de filtrar, la lista de widgets está vacía,
          // significa que no hay absolutamente nada que mostrar.
          if (chartWidgets.isEmpty) {
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Stack(
                children: [
                  ListView(), // Para que el RefreshIndicator funcione
                  const Center(
                    child: EmptyStateCard(
                      title: 'Sin Datos Suficientes',
                      message:
                          'Aún no hay transacciones para generar un análisis detallado.',
                      icon: Iconsax.chart_21,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
              itemCount: chartWidgets.length,
              itemBuilder: (context, index) {
                // El builder solo se llama para los items visibles.
                return chartWidgets[index];
              },
              separatorBuilder: (context, index) {
                // Añade el espaciado entre los gráficos.
                return const SizedBox(height: 32);
              },
            ),
          );
        },
      ),
    );
  }

  /// Construye el esqueleto de la UI mientras los datos cargan.
  Widget _buildChartsShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView(
      physics:
          const NeverScrollableScrollPhysics(), // Evita el scroll sobre el shimmer
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      children: [
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }
}
