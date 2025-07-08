import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'budgets_screen.dart';
import 'edit_transaction_screen.dart';
import '../services/ai_analysis_service.dart'; // <-- Ya lo tenías importado, ¡genial!

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardDataFuture;

  // --- NUEVO: Variables de estado para la sección de IA ---
  final AiAnalysisService _aiService = AiAnalysisService();
  String? _analysisResult;
  bool _isAiLoading = false;
  String? _aiErrorMessage;

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
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final data = await Supabase.instance.client.rpc('get_dashboard_data');
    return data as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No hay datos disponibles.'));
          }

          final dashboardData = snapshot.data!;
          final totalBalance = (dashboardData['total_balance'] as num).toDouble();
          final transactions = List<Map<String, dynamic>>.from(dashboardData['recent_transactions']);
          final budgets = (dashboardData['budgets_progress'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _dashboardDataFuture = _fetchDashboardData();
                // --- NUEVO: Reseteamos el análisis al refrescar ---
                _analysisResult = null;
                _aiErrorMessage = null;
              });
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 150),
              children: [
                _buildHeader(context),
                _buildBalanceCard(context, totalBalance),
                const SizedBox(height: 24),
                
                // --- NUEVO: Sección de Análisis con IA ---
                _buildAiAnalysisSection(context),
                const SizedBox(height: 24),
                
                if (budgets.isNotEmpty)
                  _buildBudgetsSection(context, budgets),

                _buildTransactionsSection(context, transactions),
              ],
            ),
          );
        },
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
            Text(
              _analysisResult!,
              // Usamos un estilo que respeta los saltos de línea y es legible
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5, // Mejora la legibilidad
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (El resto de tus widgets _buildHeader, _buildBalanceCard, etc., se quedan exactamente igual)
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text('Resumen General', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
  
  Widget _buildBalanceCard(BuildContext context, double totalBalance) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo Total Actual', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(totalBalance),
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsSection(BuildContext context, List<Map<String, dynamic>> budgets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tus Presupuestos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const BudgetsScreen())).then((_) {
                  setState(() { _dashboardDataFuture = _fetchDashboardData(); });
                });
              }, child: const Text('Ver Todos'))
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final category = budget['category'] as String;
              final budgetAmount = (budget['budget_amount'] as num).toDouble();
              final spentAmount = (budget['spent_amount'] as num).toDouble();
              final progress = (spentAmount / budgetAmount).clamp(0.0, 1.0);
              return _buildBudgetCard(category, budgetAmount, spentAmount, progress);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBudgetCard(String category, double budgetAmount, double spentAmount, double progress) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            '${NumberFormat.currency(symbol: '\$').format(spentAmount)} / ${NumberFormat.currency(symbol: '\$').format(budgetAmount)}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            borderRadius: BorderRadius.circular(5),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? Colors.red.shade700 : (progress > 0.8 ? Colors.orange.shade700 : Theme.of(context).colorScheme.primary),
            ),
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
    return InkWell(
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
    );
  }
}