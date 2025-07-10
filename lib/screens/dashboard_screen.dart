import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'budgets_screen.dart';
import 'edit_transaction_screen.dart';
import '../services/ai_analysis_service.dart'; // <-- Ya lo tenías importado, ¡genial!
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui'; // --- NUEVO: Necesario para ImageFilter.blur
import 'dart:async'; // Importa 'dart:async' para usar StreamSubscription
import 'package:flutter/services.dart'; // --- NUEVO: Necesario para HapticFeedback
import '../services/widget_service.dart';
import 'add_transaction_screen.dart'; // Asegúrate de importar la pantalla de añadir transacción
import 'package:home_widget/home_widget.dart'; // Importamos HomeWidget para manejar el segundo plano
import 'package:shimmer/shimmer.dart';

enum BudgetStatus { onTrack, warning, exceeded }
enum BalanceStatus { positive, negative, neutral } // Añadimos neutral para el caso de saldo cero

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Añade esta variable de estado
  static const platform = MethodChannel('com.example.finanzas_app/widget');

  late Future<Map<String, dynamic>> _dashboardDataFuture;
  StreamSubscription? _uriSubscription;
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Buenos días';
    }
    if (hour < 18) {
      return 'Buenas tardes';
    }
    return 'Buenas noches';
  }
  // --- NUEVO: Variables de estado para la sección de IA ---
  final AiAnalysisService _aiService = AiAnalysisService();
  String? _analysisResult;
  bool _isAiLoading = false;
  String? _aiErrorMessage;

  // --- NUEVO: Función para mostrar el diálogo de confirmación de borrado ---
  Future<bool?> _showDeleteConfirmationDialog(BuildContext context) {
    // Esto crea el efecto de cristalización/blur
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.85),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
            title: const Text('Confirmar eliminación'),
            content: const Text('Esta acción no se puede deshacer. ¿Estás seguro?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () {
                  Navigator.of(context).pop(false); // Devuelve false
                },
              ),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                ),
                child: const Text('Eliminar'),
                onPressed: () {
                  Navigator.of(context).pop(true); // Devuelve true
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- NUEVO: Función para determinar el estado del presupuesto ---
  BudgetStatus _getBudgetStatus(double progress) {
    if (progress >= 1.0) return BudgetStatus.exceeded;
    if (progress >= 0.75) return BudgetStatus.warning;
    return BudgetStatus.onTrack;
  }

  // --- NUEVO: Función para obtener el color del estado ---
  Color _getStatusColor(BudgetStatus status, BuildContext context) {
    switch (status) {
      case BudgetStatus.onTrack:
        return Colors.green.shade400;
      case BudgetStatus.warning:
        return Colors.orange.shade400;
      case BudgetStatus.exceeded:
        return Colors.red.shade400;
    }
  }

  // --- NUEVO: Función para obtener el icono del estado ---
  IconData _getStatusIcon(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.onTrack:
        return Iconsax.shield_tick;
      case BudgetStatus.warning:
        return Iconsax.warning_2;
      case BudgetStatus.exceeded:
        return Iconsax.close_circle;
    }
  }
// --- NUEVO: Helpers para el Saldo Total ---
  BalanceStatus _getBalanceStatus(double balance) {
    if (balance > 0) return BalanceStatus.positive;
    if (balance < 0) return BalanceStatus.negative;
    return BalanceStatus.neutral;
  }

  Color _getBalanceStatusColor(BalanceStatus status) {
    switch (status) {
      case BalanceStatus.positive:
        return Colors.green.shade400;
      case BalanceStatus.negative:
        return Colors.red.shade400;
      case BalanceStatus.neutral:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getBalanceStatusIcon(BalanceStatus status) {
    switch (status) {
      case BalanceStatus.positive:
        return Iconsax.trend_up;
      case BalanceStatus.negative:
        return Iconsax.trend_down;
      case BalanceStatus.neutral:
        return Iconsax.wallet_money;
    }
  }

  // --- NUEVO: Función para obtener el análisis de la IA ---
  void _fetchAnalysis() async {
    setState(() {
      _isAiLoading = true;
      _aiErrorMessage = null;
      _analysisResult = null;
    });

    try {
      final result = await _aiService.getFinancialAnalysis();
      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      setState(() {
        // Mostramos un mensaje más amigable en lugar del objeto de excepción completo
        _aiErrorMessage = 'Error al obtener análisis: ${e.toString().replaceFirst("Exception: ", "")}';
      });
    } finally {
      setState(() {
        _isAiLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _fetchDashboardData();
    _handleWidgetLaunch();
  }

  @override
  void dispose() {
    //_uriSubscription?.cancel();
    super.dispose();
  }

  void _handleInitialWidgetLaunch() {
    //MÉTODO CORRECTO: initiallyLaunchedFromHomeWidget
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleUri);
  }

  //void _listenForLaterWidgetLaunches() {
    //_uriSubscription = HomeWidget.widgetClicked.listen(_handleUri);
  //}

  // --- NUEVA LÓGICA DE MANEJO DE WIDGET ---
  Future<void> _handleWidgetLaunch() async {
    try {
      final String? action = await platform.invokeMethod('getWidgetAction');
      if (action != null) {
        print("✅ Acción recibida del widget: $action");
        _handleAction(action);
      }
    } on PlatformException catch (e) {
      print("Error al obtener la acción del widget: ${e.message}");
    }
  }

  void _handleAction(String action) {
    if (action == 'add_transaction') {
      print("🚀 Navegando a AddTransactionScreen...");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        }
      });
    }
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    print("✅ _handleUri triggered with: ${uri.toString()}");
    print("✅✅✅ URI RECIBIDA POR EL LISTENER: ${uri.toString()} ✅✅✅");

    if (uri.host == 'add_transaction') {
      print("🚀 Navigating to AddTransactionScreen...");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
          );
        }
      });
    } else if (uri.host == 'open_dashboard') {
      print("🏠 Widget tapped to open dashboard (already here).");
    }
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final data = await Supabase.instance.client.rpc('get_dashboard_data');
    // --- NUEVO: Actualizamos el widget cuando obtenemos los datos ---
    WidgetService.updateBalanceWidget();
    return data as Map<String, dynamic>;
  }

  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      period: const Duration(milliseconds: 1500),
      direction: ShimmerDirection.ltr,
      child: SingleChildScrollView( // <-- Usando SingleChildScrollView
        physics: const NeverScrollableScrollPhysics(),
        child: Column( // <-- Usando Column
          crossAxisAlignment: CrossAxisAlignment.start, // Alinea los elementos a la izquierda
          children: [
            // Padding general para que no esté pegado a los bordes
            const SizedBox(height: 16),
            // Shimmer para el Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 150.0, height: 24.0, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 8),
                  Container(width: 200.0, height: 32.0, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Shimmer para la Tarjeta de Saldo
            Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            ),
            const SizedBox(height: 24),
            // Shimmer para la sección de IA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 220.0, height: 28.0, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 12),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          // Si estamos esperando, mostramos el shimmer. SIN AnimatedSwitcher por ahora.
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Devolvemos el shimmer directamente para evitar problemas de transición.
            return _buildLoadingShimmer();
          }
          
          // Si ya no estamos esperando (hay datos o error), mostramos el contenido.
          return _buildDashboardContent(snapshot);
        },
      ),
    );
  }

  Widget _buildDashboardContent(AsyncSnapshot<Map<String, dynamic>> snapshot) {
    // Key para que AnimatedSwitcher sepa que el widget ha cambiado
    const Key contentKey = ValueKey('dashboard_content');

    if (snapshot.hasError) {
      return Center(key: contentKey, child: Text('Error: ${snapshot.error.toString()}'));
    }

    // Usamos !snapshot.hasData porque FutureBuilder asegura que si la conexión está 'done', hay datos o error.
    // Pero añadimos una comprobación extra por si los datos son nulos o vacíos.
    if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
      return const Center(key: contentKey, child: Text('No hay datos disponibles.'));
    }

    // Extracción segura de datos
    final dashboardData = snapshot.data!;
    final totalBalance = (dashboardData['total_balance'] as num? ?? 0).toDouble();
    final userName = dashboardData['full_name'] as String? ?? 'Usuario';
    final transactions = (dashboardData['recent_transactions'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
    final budgets = (dashboardData['budgets_progress'] as List<dynamic>?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];

    return RefreshIndicator(
      key: contentKey,
      onRefresh: () async {
        setState(() {
          _dashboardDataFuture = _fetchDashboardData();
          _analysisResult = null;
          _aiErrorMessage = null;
        });
      },
      child: SingleChildScrollView( // <-- Usando SingleChildScrollView
        physics: const AlwaysScrollableScrollPhysics(), // Permite el scroll
        child: Column( // <-- Usando Column
          crossAxisAlignment: CrossAxisAlignment.start, // <--- AÑADE ESTA LÍNEA
          children: [
            // Aquí va el contenido de tu dashboard
            _buildHeader(context, userName),
            _buildBalanceCard(context, totalBalance),
            const SizedBox(height: 24),
            _buildAiAnalysisSection(context),
            const SizedBox(height: 24),
            if (budgets.isNotEmpty)
              _buildBudgetsSection(context, budgets),
            _buildTransactionsSection(context, transactions),
            // Padding inferior para que el último elemento no quede pegado al final
            const SizedBox(height: 150), 
          ],
        ),
      ),
    );
  }
  // --- NUEVO: Widget para toda la sección de IA ---
  Widget _buildAiAnalysisSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu Asistente IA',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Si no hay resultado, mostramos el botón. Si hay, mostramos el análisis.
          if (_analysisResult == null)
            _buildAiPromptCard(context)
          else
            _buildAiResultCard(context),
        ],
      ),
    );
  }

  // --- NUEVO: Tarjeta que contiene el botón y los estados ---
  Widget _buildAiPromptCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_isAiLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Analizando tus finanzas...", textAlign: TextAlign.center),
                ],
              )
            else if (_aiErrorMessage != null)
              Column(
                children: [
                  Icon(Iconsax.warning_2, color: Theme.of(context).colorScheme.error, size: 32),
                  const SizedBox(height: 8),
                  Text(_aiErrorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _fetchAnalysis, child: const Text("Intentar de nuevo")),
                ],
              )
            else
              Column(
                children: [
                  Icon(Iconsax.magic_star, color: Theme.of(context).colorScheme.primary, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    "¿Quieres un resumen inteligente de tus finanzas?",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fetchAnalysis,
                    icon: const Icon(Iconsax.flash_1),
                    label: const Text('Generar Análisis'),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  // --- NUEVO: Tarjeta para mostrar el resultado del análisis ---
  Widget _buildAiResultCard(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.magic_star, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  "Análisis de Financiero AI",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            MarkdownBody(
              data: _analysisResult!,
              styleSheet: MarkdownStyleSheet(
                // Personalizamos los estilos para que se vean bien con tu tema
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, height: 2.0),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                listBullet: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (El resto de tus widgets _buildHeader, _buildBalanceCard, etc., se quedan exactamente igual)
  Widget _buildHeader(BuildContext context, String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getGreeting()},', // Saludo dinámico
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            userName, // Nombre del usuario
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // --- WIDGET DE TARJETA DE SALDO - TOTALMENTE REDISEÑADO ---
  Widget _buildBalanceCard(BuildContext context, double totalBalance) {
    final status = _getBalanceStatus(totalBalance);
    final statusColor = _getBalanceStatusColor(status);
    final statusIcon = _getBalanceStatusIcon(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      // Usamos BoxDecoration para tener borde y color de fondo dinámicos
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias, // Importante para que el borde funcione bien con el color
      child: Container(
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          border: Border(
            left: BorderSide(color: statusColor, width: 6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Saldo Total Actual', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16)),
                  Icon(statusIcon, color: statusColor, size: 24),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(totalBalance),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: statusColor, // El color del número también cambia
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetsSection(BuildContext context, List<Map<String, dynamic>> budgets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tus Presupuestos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BudgetsScreen())).then((_) => setState(() => _dashboardDataFuture = _fetchDashboardData()));
              }, child: const Text('Ver Todos'))
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildBudgetCard(budgets[index]); // Pasamos el mapa completo
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- WIDGET DE TARJETA DE PRESUPUESTO - CORREGIDO Y FINAL ---
  Widget _buildBudgetCard(Map<String, dynamic> budget) {
    final category = budget['category'] as String;
    final budgetAmount = (budget['budget_amount'] as num).toDouble();
    final spentAmount = (budget['spent_amount'] as num).toDouble();
    
    final progress = budgetAmount > 0 ? (spentAmount / budgetAmount) : 0.0;
    
    final status = _getBudgetStatus(progress);
    final statusColor = _getStatusColor(status, context);
    final statusIcon = _getStatusIcon(status);
    
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Color de fondo pastel basado en el estado
        color: statusColor.withOpacity(0.15),
        // Borde sutil que también cambia de color
        border: Border.all(
          color: statusColor.withOpacity(0.4),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Icon(statusIcon, color: statusColor, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            '${NumberFormat.currency(symbol: '\$').format(spentAmount)} de ${NumberFormat.currency(symbol: '\$').format(budgetAmount)}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0), // El valor visual se detiene en 100%
            borderRadius: BorderRadius.circular(8),
            backgroundColor: statusColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(statusColor), // Usa el color del estado
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsSection(BuildContext context, List<Map<String, dynamic>> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Movimientos Recientes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('No hay movimientos recientes.')),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              return _buildTransactionTile(transactions[index]);
            },
          ),
      ],
    );
  }

  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final bool isExpense = transaction['type'] == 'Gasto';
    // ¡IMPORTANTE! Necesitamos el ID para la key y para borrar.
    // Asegúrate de que tu RPC devuelve el 'id'.
    final transactionId = transaction['id'];

    return Dismissible(
      key: ValueKey(transactionId), // Key única para cada elemento
      direction: DismissDirection.endToStart, // Solo deslizar de derecha a izquierda
      
      // Fondo que aparece al deslizar
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: Icon(
          Iconsax.trash,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),

      // --- LÓGICA DE CONFIRMACIÓN Y BORRADO ---
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact(); // Feedback táctil satisfactorio
        final confirmed = await _showDeleteConfirmationDialog(context);
        
        if (confirmed == true) {
          try {
            // Llamada a Supabase para borrar el registro
            await Supabase.instance.client
                .from('transactions')
                .delete()
                .match({'id': transactionId});

            // Mostramos un mensaje de éxito
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transacción eliminada con éxito.'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refrescamos el dashboard para que desaparezca la transacción
              setState(() {
                 _dashboardDataFuture = _fetchDashboardData();
              });
            }
            // Devolvemos false porque ya hemos manejado la UI.
            // Si devolvemos true, Flutter intentaría quitarlo también, causando un error.
            return false;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al eliminar: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
            return false; // No borramos si hay un error
          }
        }
        return false; // No borramos si el usuario cancela
      },

      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => EditTransactionScreen(transaction: transaction)),
          );
          setState(() {
            _dashboardDataFuture = _fetchDashboardData();
          });
        },
        child: ListTile(
          leading: Icon(isExpense ? Iconsax.arrow_down_2 : Iconsax.arrow_up_1, color: isExpense ? Colors.redAccent : Colors.green),
          title: Text(transaction['category'] ?? 'Sin Categoría'),
          subtitle: (transaction['description'] != null && transaction['description'].isNotEmpty)
            ? Text(transaction['description'])
            : null,
          trailing: Text(
            '${isExpense ? '-' : '+'}${NumberFormat.currency(symbol: '\$').format(transaction['amount'])}',
            style: TextStyle(fontWeight: FontWeight.w600, color: isExpense ? Colors.redAccent : Colors.green),
          ),
        ),
      ),
    );
  }
}