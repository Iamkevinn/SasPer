import 'package:finanzas_app/widgets/dashboard/ai_analysis_section.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/dashboard_repository.dart';
import '../models/dashboard_data_model.dart';
import '../widgets/dashboard/balance_card.dart';
import '../widgets/dashboard/budgets_section.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/recent_transactions_section.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late final DashboardRepository _repository;
  // CAMBIO: De un Future a un Stream. ¡Adiós a la recarga manual!
  late Stream<DashboardData> _dashboardDataStream;

  @override
  void initState() {
    super.initState();
    _repository = DashboardRepository(Supabase.instance.client);
    // CAMBIO: Nos suscribimos al stream.
    _dashboardDataStream = _repository.getDashboardDataStream();
  }

  // ELIMINADO: La función refreshDashboard() y la _futureBuilderKey ya no son necesarias.

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    return Padding(
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        // CAMBIO: De FutureBuilder a StreamBuilder
        child: StreamBuilder<DashboardData>(
          stream: _dashboardDataStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return _buildLoadingShimmer();
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error al cargar: ${snapshot.error}'));
            }
            if (snapshot.hasData) {
              final data = snapshot.data!;
              return _buildDashboardContent(data);
            }
            return _buildLoadingShimmer(); // Estado por defecto
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent(DashboardData data) {
    return RefreshIndicator(
      onRefresh: () async {
        // El stream se actualiza solo, pero si el usuario tira para refrescar,
        // podemos forzar una llamada para que sienta que la app responde.
        // La forma de hacerlo es pedirle al repositorio que lo haga.
        // Para este caso, podríamos añadir un método `forceRefresh()` en el repo,
        // pero por ahora, esto es suficiente. El stream ya hace el trabajo pesado.
        setState(() {
          _dashboardDataStream = _repository.getDashboardDataStream();
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardHeader(userName: data.fullName),
            BalanceCard(totalBalance: data.totalBalance),
            const SizedBox(height: 24),
            AiAnalysisSection(), 
            const SizedBox(height: 24),
            if (data.budgetsProgress.isNotEmpty)
              BudgetsSection(budgets: data.budgetsProgress),
            // Ya no pasamos callbacks a los hijos. Es mucho más limpio.
            RecentTransactionsSection(
              transactions: data.recentTransactions,
            ),
            const SizedBox(height: 150),
          ],
        ),
      ),
    );
  }

  // Tu widget de Shimmer está perfecto, no necesita cambios.
  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Container(
      width: double.infinity, // Asegura que ocupe todo el ancho
      color: Theme.of(context).scaffoldBackgroundColor, // Le da un fondo sólido
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        direction: ShimmerDirection.ltr,
        child: SingleChildScrollView(
          // <-- Usando SingleChildScrollView
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            // <-- Usando Column
            crossAxisAlignment:
                CrossAxisAlignment.start, // Alinea los elementos a la izquierda
            children: [
              // Padding general para que no esté pegado a los bordes
              const SizedBox(height: 16),
              // Shimmer para el Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150.0,
                      height: 24.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200.0,
                      height: 32.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Shimmer para la Tarjeta de Saldo
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              // --- NUEVO: SHIMMER PARA LA SECCIÓN DE PRESUPUESTOS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: 250.0,
                  height: 28.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140, // Misma altura que tu lista de presupuestos real
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3, // Muestra 3 placeholders de tarjetas
                  itemBuilder: (context, index) => Container(
                    width:
                        220, // Mismo ancho que tus tarjetas de presupuesto reales
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              // --- FIN DEL SHIMMER DE PRESUPUESTOS ---
              const SizedBox(height: 24),
              // Shimmer para la sección de IA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 220.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


