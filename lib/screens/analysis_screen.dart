  // lib/screens/analysis_screen.dart

  import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final _repository = AnalysisRepository();
    // --- ¡CORRECCIÓN CLAVE! ---
    // Usamos un StreamController para controlar cuándo se emiten nuevos datos.
    // Volvemos a un Future. Es más simple y claro para esta pantalla.
    late Future<AnalysisData> _analysisFuture;
    
    // Mantenemos la suscripción para la reactividad automática.
    late final RealtimeChannel _transactionsChannel;


    @override
    void initState() {
      super.initState();
      // La primera carga se hace a través del FutureBuilder.
      _analysisFuture = _repository.fetchAllAnalysisData();
      
      // Nos suscribimos a los cambios para recargar automáticamente.
      _transactionsChannel = Supabase.instance.client
          .channel('public:transactions:analysis')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            // Llama a _handleRefresh, que es el método correcto.
            callback: (payload) {
              // Añadimos un pequeño retraso para asegurar que la DB se ha actualizado
              Future.delayed(const Duration(milliseconds: 500), () {
                _handleRefresh();
              });
            },
          )
          .subscribe();
    }

    @override
    void dispose() {
      // Es importante cancelar la suscripción.
      Supabase.instance.client.removeChannel(_transactionsChannel);
      super.dispose();
    }
    
    // Esta función ahora es llamada por el RefreshIndicator y la suscripción.
    Future<void> _handleRefresh() async {
      // Reasignamos el future, lo que hará que el FutureBuilder se reconstruya.
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
          title: Text('Análisis Detallado', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        // CAMBIO CLAVE: De FutureBuilder a StreamBuilder
        body: FutureBuilder<AnalysisData>(
          future: _analysisFuture,
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

            // Lógica para comprobar si TODOS los datos están vacíos
            final bool hasDataToShow = 
              analysisData.expensePieData.isNotEmpty ||
              analysisData.cashflowBarData.isNotEmpty ||
              analysisData.netWorthLineData.isNotEmpty ||
              analysisData.categoryComparisonData.isNotEmpty ||
              analysisData.incomePieData.isNotEmpty ||
              analysisData.incomeExpenseBarData.isNotEmpty ||
              analysisData.heatmapData.isNotEmpty;
            
            if (!hasDataToShow) {
              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: Stack( // Usamos un Stack para que el ListView permita el scroll
                  children: [
                    ListView(), // ListView vacío para que el RefreshIndicator funcione
                    const Center(
                      child: EmptyStateCard(
                        title: 'Sin Datos Suficientes',
                        message: 'Aún no hay suficientes transacciones para generar un análisis detallado.',
                        icon: Iconsax.chart_21,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _handleRefresh, // Conectamos el refresh manual
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