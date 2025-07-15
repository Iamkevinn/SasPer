import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sas_per/data/dashboard_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:async';
import '../services/event_service.dart';
import '../widgets/goals/contribute_to_goal_dialog.dart';
import '../models/goal_model.dart';
import 'add_goal_screen.dart';
import '../utils/custom_page_route.dart';
import 'package:shimmer/shimmer.dart';
import '../models/dashboard_data_model.dart';

class GoalsScreen extends StatefulWidget {
  final DashboardRepository repository;
  const GoalsScreen({super.key, required this.repository});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late Stream<DashboardData> _dataStream;
  final supabase = Supabase.instance.client;
  StreamSubscription<AppEvent>? _eventSubscription;
  @override
  void initState() {
    super.initState();
    _dataStream = widget.repository.getDashboardDataStream();
  }

  Future<void> _handleRefresh() async {
    // Llama al método del repositorio para forzar la recarga
    await widget.repository.forceRefresh();
  }

  // --- NUEVA FUNCIÓN QUE DEVUELVE UN STREAM ---
  Stream<List<Goal>> _fetchGoalsStream() {
    // Escuchamos cambios en la tabla 'goals'
    return supabase
        .from('goals')
        .stream(primaryKey: ['id']) // Escucha cambios en la tabla
        .order('created_at', ascending: true)
        .map((listOfMaps) {
          // Cada vez que hay un cambio, `map` convierte la lista de mapas
          // en una lista de objetos Goal.
          final goals = listOfMaps.map((data) => Goal.fromMap(data)).toList();
          // Filtramos para mostrar solo las activas en la UI
          return goals.where((goal) => goal.status == 'active').toList();
        });
  }


  // La navegación se simplifica. Ya no necesita devolver un valor para refrescar.
  void _navigateToAddGoal() {
    Navigator.of(context).push(
      FadePageRoute(child: const AddGoalScreen()),
    );
    // No hace falta esperar el `result`, el stream lo detectará.
  }

  @override
  Widget build(BuildContext context) {
    // Altura de tu barra de navegación para calcular el padding necesario.
    final navBarHeight = 68.0 + MediaQuery.of(context).padding.bottom;
    
    // Padding para el FAB. Lo sube por encima de la barra de navegación.
    final fabBottomPadding = navBarHeight + 12; // Ajusta el '-20' para la altura deseada

    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Metas', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      // --- CAMBIOS PRINCIPALES PARA EL FAB ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // <-- 1. CENTRA EL FAB
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottomPadding), // <-- 2. APLICA EL PADDING PARA SUBIRLO
        child: FloatingActionButton(
          onPressed: _navigateToAddGoal,
          child: const Icon(Iconsax.add),
        ),
      ),
      // --- FIN DE CAMBIOS PARA EL FAB ---
      body: StreamBuilder<DashboardData>(
        stream: _dataStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingShimmer();
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Usamos `!snapshot.hasData` para cubrir el caso de un stream vacío inicial
          if (!snapshot.hasData || snapshot.data!.goals.isEmpty) {
            return _buildEmptyState();
          }

          final goals = snapshot.data!.goals;
          
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: AnimationLimiter(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, fabBottomPadding + 80.0),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _GoalCard(goal: goal),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // --- NUEVO WIDGET SHIMMER PARA METAS ---
  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 5, // Muestra 5 placeholders de metas
        itemBuilder: (context, index) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 20.0,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                      Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.flag_2, size: 80, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 20),
          Text(
            'Aún no tienes metas',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            '¡Crea tu primera meta para empezar a ahorrar!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _navigateToAddGoal,
            icon: const Icon(Iconsax.add),
            label: const Text('Crear mi primera meta'),
          )
        ],
      ),
    );
  }
}

// --- WIDGET DE LA TARJETA DE META CON LA CORRECCIÓN DE OVERFLOW ---
class _GoalCard extends StatelessWidget {
  final Goal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.name,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Ahorrado: ${currencyFormat.format(goal.currentAmount)}',
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showContributeDialog(context, goal , () {
                    // Ya no necesita hacer nada, el stream se encarga.
                    print("Aportación exitosa, el stream actualizará la UI.");
                  }),
                  icon: const Icon(Iconsax.additem, size: 18),
                  label: const Text('Aportar'),
                ),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Meta: ${currencyFormat.format(goal.targetAmount)}',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 10,
                backgroundColor: colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(goal.progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContributeDialog(BuildContext context, Goal goal, VoidCallback onSuccess) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return ContributeToGoalDialog(
          goal: goal,
          onSuccess: () {
             // Ya no necesita hacer nada, el stream se encarga.
             // Podemos imprimir algo para depurar si queremos.
             print("Aportación exitosa, el stream actualizará la UI.");
          },
        );
      },
    );
  }
}