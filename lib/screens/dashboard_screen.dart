// lib/screens/dashboard_screen.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// Importamos la arquitectura limpia
import '../data/dashboard_repository.dart';
import '../models/dashboard_data_model.dart';
import '../services/event_service.dart';
import '../services/widget_service.dart';
import '../widgets/dashboard/ai_analysis_section.dart';
import '../widgets/dashboard/balance_card.dart';
import '../widgets/dashboard/budgets_section.dart';
import '../widgets/dashboard/dashboard_header.dart';
import '../widgets/dashboard/recent_transactions_section.dart';

class DashboardScreen extends StatefulWidget {
  // 1. Es una buena práctica recibir el repositorio en el constructor.
  // Esto se conoce como Inyección de Dependencias.
  final DashboardRepository repository;

  const DashboardScreen({super.key, required this.repository});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late final Stream<DashboardData> _dashboardDataStream;
  late final StreamSubscription<AppEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    // 2. SIMPLIFICACIÓN: Obtenemos el stream. El repositorio se encargará
    // de la carga inicial la primera vez que el StreamBuilder escuche.
    _dashboardDataStream = widget.repository.getDashboardDataStream();

    // La suscripción a eventos sigue siendo útil para forzar recargas
    // desde otras partes de la app.
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      if ({AppEvent.transactionsChanged, AppEvent.transactionDeleted, AppEvent.accountCreated, AppEvent.debtsChanged, AppEvent.goalsChanged}.contains(event)) {
        if (kDebugMode) print("Dashboard: Evento '$event' recibido. Forzando refresh...");
        widget.repository.forceRefresh();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    // No necesitamos llamar a repository.dispose() aquí si el repositorio
    // es manejado por un provider (como Riverpod) que gestiona su ciclo de vida.
    // Si no, sí sería necesario.
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    // El 'silent: false' es importante para que el repositorio emita el estado de carga.
    await widget.repository.forceRefresh(silent: false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DashboardData>(
        stream: _dashboardDataStream,
        builder: (context, snapshot) {
          // Si tenemos datos, los usamos. La propiedad 'isLoading' del modelo
          // nos dirá si estamos en medio de una recarga.
          if (snapshot.hasData) {
            final data = snapshot.data!;
            
            // Actualizamos el widget de la pantalla de inicio cada vez que hay datos nuevos
            WidgetService.updateWidgetData(totalBalance: data.totalBalance);

            // Si data.isLoading es true, podríamos mostrar el shimmer sobre el contenido antiguo
            // pero el RefreshIndicator ya da buen feedback.
            return _buildDashboardContent(data);
          }
          // Si hay un error, lo mostramos
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar los datos: ${snapshot.error}'));
          }
          // Si no hay datos ni error (estado inicial), mostramos el shimmer
          return _buildLoadingShimmer();
        },
      ),
    );
  }

  Widget _buildDashboardContent(DashboardData data) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: CustomScrollView( // Usar CustomScrollView es a menudo más performante que SingleChildScrollView+Column
        slivers: [
          SliverToBoxAdapter(child: DashboardHeader(userName: data.fullName)),
          SliverToBoxAdapter(child: BalanceCard(totalBalance: data.totalBalance)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: AiAnalysisSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          if (data.budgetsProgress.isNotEmpty)
            SliverToBoxAdapter(child: BudgetsSection(budgets: data.budgetsProgress)),
          SliverToBoxAdapter(
            child: RecentTransactionsSection(
              transactions: data.recentTransactions,
              onViewAllPressed: () {
                // Lógica para cambiar de pestaña en MainScreen
                if (kDebugMode) print('Navegar a la pantalla completa de transacciones');
              },
            ),
          ),
          // Espaciador final para que el contenido no quede pegado al fondo
          const SliverToBoxAdapter(child: SizedBox(height: 150)),
        ],
      ),
    );
  }

  // El Shimmer sigue siendo el mismo, está muy bien.
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


