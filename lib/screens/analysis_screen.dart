import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'dart:math'; // --- NUEVO: Necesario para 'max' y 'min'

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late Future<void> _dataFutures;
  List<Map<String, dynamic>> _pieChartData = [];
  List<Map<String, dynamic>> _barChartData = [];
  List<Map<String, dynamic>> _lineChartData = [];

  final List<Color> _chartColors = [
    Colors.blue.shade400, Colors.red.shade400, Colors.green.shade400,
    Colors.orange.shade400, Colors.purple.shade400, Colors.teal.shade400,
    Colors.pink.shade400, Colors.indigo.shade400,
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    // Usamos Future.wait para cargar todos los datos en paralelo
    _dataFutures = Future.wait([
      Supabase.instance.client.rpc('get_expense_summary_by_category').then((data) => _pieChartData = (data as List).cast<Map<String, dynamic>>()),
      Supabase.instance.client.rpc('get_monthly_income_expense_summary').then((data) => _barChartData = (data as List).cast<Map<String, dynamic>>()),
      Supabase.instance.client.rpc('get_net_worth_trend').then((data) => _lineChartData = (data as List).cast<Map<String, dynamic>>()),
    ]);
    // Forzamos un rebuild una vez que los futuros se han asignado
    if(mounted) setState(() {});
  }

  // Helper para los límites del eje Y, ahora más robusto
  (double, double) _getMinMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return (0, 100);
    // Si solo hay un punto, creamos un rango artificial para que se vea bien
    if (spots.length == 1) {
      final y = spots.first.y;
      return (y - 500, y + 500);
    }
    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (var spot in spots) {
      minY = min(minY, spot.y);
      maxY = max(maxY, spot.y);
    }
    // Si todos los puntos son iguales, creamos un rango artificial
    if (minY == maxY) {
      return (minY - 500, maxY + 500);
    }
    final padding = (maxY - minY) * 0.20; // 20% de margen
    return (minY - padding, maxY + padding);
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
      body: FutureBuilder(
        future: _dataFutures,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
              children: [
                _buildLineChartSection(context, _lineChartData),
                const SizedBox(height: 32),
                _buildBarChartSection(context, _barChartData),
                const SizedBox(height: 32),
                _buildPieChartSection(context, _pieChartData),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET DE GRÁFICO DE BARRAS - CON LA SINTAXIS EXACTA QUE PIDE TU EDITOR ---
  Widget _buildBarChartSection(BuildContext context, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.chart, size: 20), const SizedBox(width: 8), Text('Ingresos vs. Gastos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              
              // --- CÓDIGO DE INTERACTIVIDAD ESCRITO PARA TU VERSIÓN EXACTA ---
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  
                  // Usamos la función que acabamos de descubrir
                  getTooltipColor: (group) => Theme.of(context).colorScheme.secondaryContainer,

                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final formatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
                    String valueText = formatter.format(rod.toY);
                    
                    String rodName = rodIndex == 0 ? 'Ingreso' : 'Gasto';

                    return BarTooltipItem(
                      '$rodName\n',
                      TextStyle(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: valueText,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    final monthDate = DateTime.parse(data[index]['month_start'] + '-01');
                    return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat.MMM('es_MX').format(monthDate), style: Theme.of(context).textTheme.bodySmall));
                  }
                  return const Text('');
                })),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (value, meta) {
                  if (value % 5000 != 0) return const SizedBox.shrink();
                  return Text('${(value ~/ 1000)}k');
                })),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: List.generate(data.length, (index) {
                final item = data[index];
                return BarChartGroupData(x: index, barRods: [
                  BarChartRodData(toY: (item['total_income'] as num).toDouble(), color: Colors.green.shade400, width: 14, borderRadius: const BorderRadius.all(Radius.circular(4))),
                  BarChartRodData(toY: (item['total_expense'] as num).toDouble(), color: Colors.red.shade400, width: 14, borderRadius: const BorderRadius.all(Radius.circular(4))),
                ]);
              }),
            ),
          ),
        ),
      ],
    );
  }

  // --- GRÁFICO DE LÍNEA: EVOLUCIÓN DEL PATRIMONIO NETO ---
  Widget _buildLineChartSection(BuildContext context, List<Map<String, dynamic>> data) {
    if (data.isEmpty || data.every((d) => (d['net_worth'] as num) == 0)) {
        return const SizedBox.shrink();
    }

    final spots = List.generate(data.length, (index) {
      final item = data[index]; // No damos la vuelta, la nueva SQL ya viene ordenada ASC
      return FlSpot(index.toDouble(), (item['net_worth'] as num).toDouble());
    });
    
    final (minY, maxY) = _getMinMaxY(spots);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.trend_up, size: 20), const SizedBox(width: 8), Text('Evolución de tu Patrimonio', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.fromLTRB(8, 20, 20, 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta){
                      final index = value.toInt();
                      if (index >= 0 && index < data.length) {
                        final monthDate = DateTime.parse(data[index]['month_end'] + '-01');
                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat.MMM('es_MX').format(monthDate), style: Theme.of(context).textTheme.bodySmall));
                      }
                      return const Text('');
                  })),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45, getTitlesWidget: (value, meta) {
                    if (value == minY || value == maxY) return const SizedBox.shrink();
                    // Muestra etiquetas de forma más inteligente para evitar superposición
                    if ((maxY - minY) > 10000 && value % 2000 != 0) return const SizedBox.shrink();
                    if ((maxY - minY) <= 10000 && value % 1000 != 0) return const SizedBox.shrink();
                    return Text('${(value / 1000).toStringAsFixed(0)}k');
                  })),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  // ¡LÍNEA CONFLICTIVA ELIMINADA!
                  getTooltipColor: (touchedSpot) => Theme.of(context).colorScheme.primary,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final formatter = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
                      return LineTooltipItem(
                        formatter.format(spot.y),
                        // Usamos un color que contraste con el color de fondo por defecto
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), 
                      );
                    }).toList();
                  }
                )
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary.withOpacity(0.3), Theme.of(context).colorScheme.primary.withOpacity(0.0)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- GRÁFICO DE PASTEL: DISTRIBUCIÓN DE GASTOS (CON INTERACTIVIDAD) ---
  Widget _buildPieChartSection(BuildContext context, List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final double totalExpenses = data.fold(0, (sum, item) => sum + (item['total_spent'] as num));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.chart_21, size: 20), const SizedBox(width: 8), Text('Gastos del Mes por Categoría', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              SizedBox(
                height: 200, width: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3, centerSpaceRadius: 50,
                    pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      // Aquí podrías implementar lógica para agrandar la sección tocada
                    }),
                    sections: List.generate(data.length, (index) {
                      final item = data[index];
                      final percentage = ((item['total_spent'] as num) / totalExpenses) * 100;
                      return PieChartSectionData(
                        color: _chartColors[index % _chartColors.length],
                        value: (item['total_spent'] as num).toDouble(),
                        title: '${percentage.toStringAsFixed(0)}%',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                      );
                    }),
                  ),
                ),
              ),
              const Divider(height: 32),
              Wrap(
                spacing: 16.0, runSpacing: 8.0,
                children: List.generate(data.length, (index) {
                  final item = data[index];
                  return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, color: _chartColors[index % _chartColors.length]), const SizedBox(width: 8), Text(item['category'])]);
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}