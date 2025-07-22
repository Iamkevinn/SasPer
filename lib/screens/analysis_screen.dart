// lib/screens/analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importante

import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/analysis_models.dart';

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
  final AnalysisRepository _repository = AnalysisRepository();
  // CAMBIO CLAVE: De Future a Stream.
  late Stream<AnalysisData> _analysisStream;

  @override
  void initState() {
    super.initState();
    // Creamos un stream que escucha cambios en las transacciones
    // y cada vez que hay uno, vuelve a llamar a tu repositorio.
    _analysisStream = Supabase.instance.client
      .from('transactions')
      .stream(primaryKey: ['id'])
      .asyncMap((_) => _repository.fetchAllAnalysisData()); // .asyncMap para llamar a un Future
  }

  // ELIMINADO: _listenToEvents, _refreshData, refreshAnalysis, dispose, _futureBuilderKey
  // Ya no son necesarios.

  Future<void> _manualRefresh() async {
    // Para el RefreshIndicator, podemos forzar una recarga.
    setState(() {
      _analysisStream = Supabase.instance.client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .asyncMap((_) => _repository.fetchAllAnalysisData());
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis Detallado'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      // CAMBIO CLAVE: De FutureBuilder a StreamBuilder
      body: StreamBuilder<AnalysisData>(
        stream: _analysisStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildChartsShimmer();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: EmptyStateCard(
                  title: 'Ocurrió un Error',
                  message: 'No se pudieron cargar los datos. Intenta refrescar la pantalla.\nError: ${snapshot.error}',
                  icon: Iconsax.warning_2,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: EmptyStateCard(
                title: 'Sin Datos',
                message: 'No hay suficientes datos para generar un análisis.',
                icon: Iconsax.chart_21,
            ));
          }

          final analysisData = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _manualRefresh, // Conectamos el refresh manual
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
              children: [
                HeatmapSection(data: analysisData.heatmapData),
                const SizedBox(height: 32),
                MonthlyCashflowChart(data: analysisData.cashflowBarData),
                const SizedBox(height: 32),
                NetWorthTrendChart(data: analysisData.netWorthLineData),
                const SizedBox(height: 32),
                IncomeExpenseBarChart(data: analysisData.incomeExpenseBarData),
                const SizedBox(height: 32),
                CategoryComparisonChart(data: analysisData.categoryComparisonData),
                const SizedBox(height: 32),
                ExpensePieChart(data: analysisData.expensePieData),
                const SizedBox(height: 32),
                IncomePieChart(data: analysisData.incomePieData),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // El widget del Shimmer está perfecto y no necesita cambios.
  Widget _buildChartsShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor    = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    // Aquí no envolvemos TODO el ListView en el shimmer,
    // sino cada tarjeta por separado, para que herede su estilo.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
      children: [
        // Línea
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer, 
                borderRadius: BorderRadius.circular(20),
                // opcional: sombra ligera
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
            ),
          ),
        ),
        // Barras
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
            ),
          ),
        ),
        // Pastel
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 350,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}