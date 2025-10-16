// lib/screens/planning_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/screens/accounts_screen.dart';
import 'package:sasper/screens/analysis_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/screens/debts_screen.dart';
import 'package:sasper/screens/goals_screen.dart';
import 'package:sasper/screens/recurring_transactions_screen.dart';
import 'package:sasper/screens/challenges_screen.dart';

class PlanningHubScreen extends StatefulWidget {
  const PlanningHubScreen({super.key});

  @override
  State<PlanningHubScreen> createState() => _PlanningHubScreenState();
}

class _PlanningHubScreenState extends State<PlanningHubScreen> {
  String _selectedCategory = 'Todas';
  
  final List<String> _categories = [
    'Todas',
    'Finanzas',
    'Análisis',
    'Objetivos',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar moderna con búsqueda
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Centro de',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Planificación',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer.withOpacity(0.3),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Filtros de categoría
          SliverToBoxAdapter(
            child: _buildCategoryFilters(),
          ),

          // Subtítulo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                _getSubtitleForCategory(),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // Grid de herramientas
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildListDelegate(
                _getFilteredTools()
                    .asMap()
                    .entries
                    .map((entry) => _buildToolCard(
                          context,
                          tool: entry.value,
                          index: entry.key,
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              labelStyle: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          );
        },
      ),
    );
  }

  String _getSubtitleForCategory() {
    switch (_selectedCategory) {
      case 'Finanzas':
        return 'Administra tus cuentas, presupuestos y deudas';
      case 'Análisis':
        return 'Visualiza y comprende tus patrones financieros';
      case 'Objetivos':
        return 'Alcanza tus metas y desarrolla buenos hábitos';
      default:
        return 'Gestiona todos los aspectos de tus finanzas';
    }
  }

  List<_ToolData> _getFilteredTools() {
    final allTools = _getAllTools();
    
    if (_selectedCategory == 'Todas') {
      return allTools;
    }
    
    return allTools.where((tool) => tool.category == _selectedCategory).toList();
  }

  List<_ToolData> _getAllTools() {
    return [
      _ToolData(
        icon: Iconsax.wallet_3,
        title: 'Cuentas',
        subtitle: 'Bancos y efectivo',
        description: 'Administra tu efectivo, bancos y tarjetas',
        color: Colors.blue,
        category: 'Finanzas',
        badge: null,
        destination: const AccountsScreen(),
      ),
      _ToolData(
        icon: Iconsax.money_tick,
        title: 'Presupuestos',
        subtitle: 'Control de gastos',
        description: 'Controla tus gastos mensuales por categoría',
        color: Colors.green,
        category: 'Finanzas',
        badge: null,
        destination: const BudgetsScreen(),
      ),
      _ToolData(
        icon: Iconsax.flag,
        title: 'Metas',
        subtitle: 'Objetivos de ahorro',
        description: 'Alcanza tus objetivos financieros',
        color: Colors.orange,
        category: 'Objetivos',
        badge: null,
        destination: const GoalsScreen(),
      ),
      _ToolData(
        icon: Iconsax.receipt_2_1,
        title: 'Deudas',
        subtitle: 'Préstamos activos',
        description: 'Administra y liquida tus deudas',
        color: Colors.red,
        category: 'Finanzas',
        badge: null,
        destination: const DebtsScreen(),
      ),
      _ToolData(
        icon: Iconsax.chart_1,
        title: 'Análisis',
        subtitle: 'Informes detallados',
        description: 'Entiende a dónde va tu dinero',
        color: Colors.purple,
        category: 'Análisis',
        badge: null,
        destination: const AnalysisScreen(),
      ),
      _ToolData(
        icon: Iconsax.repeat,
        title: 'Gastos Fijos',
        subtitle: 'Automatización',
        description: 'Automatiza ingresos y gastos',
        color: Colors.teal,
        category: 'Finanzas',
        badge: null,
        destination: const RecurringTransactionsScreen(),
      ),
      _ToolData(
        icon: Iconsax.cup,
        title: 'Retos',
        subtitle: 'Hábitos financieros',
        description: 'Mejora con objetivos divertidos',
        color: Colors.amber,
        category: 'Objetivos',
        badge: 'Nuevo',
        destination: const ChallengesScreen(),
      ),
    ];
  }

  Widget _buildToolCard(BuildContext context, {required _ToolData tool, required int index}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tool.color.withOpacity(0.1),
            tool.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: tool.color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tool.color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToTool(context, tool),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tool.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        tool.icon,
                        size: 28,
                        color: tool.color,
                      ),
                    ),
                    if (tool.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tool.badge!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  tool.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Abrir',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tool.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 14,
                      color: tool.color,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (100 * index).ms)
        .scale(
          begin: const Offset(0.8, 0.8),
          curve: Curves.easeOutCubic,
          delay: (100 * index).ms,
        );
  }

  void _navigateToTool(BuildContext context, _ToolData tool) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => tool.destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          
          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// ============================================================================
// MODELO DE DATOS PARA HERRAMIENTAS
// ============================================================================
class _ToolData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final String category;
  final String? badge;
  final Widget destination;

  _ToolData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.category,
    this.badge,
    required this.destination,
  });
}