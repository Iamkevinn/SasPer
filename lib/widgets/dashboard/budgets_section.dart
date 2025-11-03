// lib/widgets/dashboard/budgets_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/budget_details_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';

class BudgetsSection extends StatefulWidget {
  final List<Budget> budgets;

  const BudgetsSection({
    super.key,
    required this.budgets,
  });

  @override
  State<BudgetsSection> createState() => _BudgetsSectionState();
}

class _BudgetsSectionState extends State<BudgetsSection>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  bool _showRecommendation = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Calcula el estado general de los presupuestos
  Map<String, dynamic> _getBudgetHealth() {
    if (widget.budgets.isEmpty) {
      return {'status': 'empty', 'percentage': 0.0, 'message': ''};
    }

    double totalSpent = 0;
    double totalBudget = 0;
    int onTrack = 0;
    int exceeded = 0;

    for (var budget in widget.budgets) {
      totalSpent += budget.spentAmount;
      totalBudget += budget.amount;
      
      final percentage = (budget.spentAmount / budget.amount) * 100;
      if (percentage > 100) {
        exceeded++;
      } else if (percentage <= 80) {
        onTrack++;
      }
    }

    final overallPercentage = (totalSpent / totalBudget) * 100;
    String status = 'excellent';
    String message = '¡Excelente control financiero! 🌟';

    if (overallPercentage > 95) {
      status = 'critical';
      message = 'Cuidado, casi al límite 🔴';
    } else if (overallPercentage > 80) {
      status = 'warning';
      message = 'Monitorea tus gastos 🟡';
    } else if (overallPercentage > 60) {
      status = 'good';
      message = 'Vas por buen camino 💚';
    }

    return {
      'status': status,
      'percentage': overallPercentage,
      'message': message,
      'onTrack': onTrack,
      'exceeded': exceeded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final health = _getBudgetHealth();

    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModernHeader(context, health),
          const SizedBox(height: 16),
          if (_showRecommendation && widget.budgets.isNotEmpty)
            _buildAIRecommendation(context, health),
          if (widget.budgets.isEmpty)
            _buildEmptyState(context)
          else
            _buildPremiumBudgetsList(context),
        ],
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, Map<String, dynamic> health) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tus Presupuestos',
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    if (widget.budgets.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildHealthIndicator(health['status']),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              health['message'],
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _getHealthColor(health['status']),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BudgetsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ver Todos',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Iconsax.arrow_right_3,
                            size: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIndicator(String status) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getHealthColor(status),
            boxShadow: [
              BoxShadow(
                color: _getHealthColor(status).withOpacity(0.4 * value),
                blurRadius: 8 * value,
                spreadRadius: 2 * value,
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getHealthColor(String status) {
    switch (status) {
      case 'excellent':
        return const Color(0xFF10B981);
      case 'good':
        return const Color(0xFF22C55E);
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'critical':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  Widget _buildAIRecommendation(
      BuildContext context, Map<String, dynamic> health) {
    final recommendations = [
      {
        'icon': Iconsax.lamp_charge,
        'title': 'Pequeños cambios, grandes resultados',
        'message':
            'Reduce un 10% tu gasto en comida esta semana y alcanza tu meta más rápido',
        'impact': '+\$45,000',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'icon': Iconsax.chart_success,
        'title': 'Vas por excelente camino',
        'message':
            'Mantén este ritmo y superarás tu objetivo de ahorro del mes',
        'impact': 'Meta en 5 días',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Iconsax.warning_2,
        'title': 'Alerta de presupuesto',
        'message':
            'Tu categoría Entretenimiento está al 85%. Considera ajustar.',
        'impact': '-\$28,000',
        'color': const Color(0xFFF59E0B),
      },
    ];

    final rec = recommendations[health['status'] == 'critical' ? 2 : 
                              health['status'] == 'warning' ? 2 : 1];

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Dismissible(
          key: const Key('ai_recommendation'),
          direction: DismissDirection.horizontal,
          onDismissed: (direction) {
            setState(() {
              _showRecommendation = false;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  rec['color'] as Color,
                  (rec['color'] as Color).withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (rec['color'] as Color).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          rec['icon'] as IconData,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rec['title'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    rec['impact'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rec['message'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.95),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBudgetsList(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.budgets.length,
        itemBuilder: (context, index) {
          final budget = widget.budgets[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: 260,
                    margin: const EdgeInsets.only(right: 16),
                    child: _buildPremiumBudgetCard(context, budget),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPremiumBudgetCard(BuildContext context, Budget budget) {
    final percentage = (budget.spentAmount / budget.amount).clamp(0.0, 1.0);
    final isOverBudget = budget.spentAmount > budget.amount;
    final remaining = budget.amount - budget.spentAmount;

    Color getCardColor() {
      if (isOverBudget) return const Color(0xFFEF4444);
      if (percentage > 0.8) return const Color(0xFFF59E0B);
      if (percentage > 0.6) return const Color(0xFF3B82F6);
      return const Color(0xFF10B981);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            getCardColor(),
            getCardColor().withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: getCardColor().withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => BudgetDetailsScreen(
                  budgetId: budget.id,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getCategoryIcon(budget.category),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(percentage * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  budget.category,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '\$${_formatNumber(budget.spentAmount)}',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      ' / \$${_formatNumber(budget.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: percentage),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      isOverBudget ? Iconsax.danger : Iconsax.tick_circle,
                      size: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isOverBudget
                            ? 'Excedido por \$${_formatNumber(remaining.abs())}'
                            : 'Quedan \$${_formatNumber(remaining)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Theme.of(context).primaryColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.wallet_add,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Crea tu Primer Presupuesto',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Los presupuestos te ayudan a controlar tus gastos y alcanzar tus metas financieras.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BudgetsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.add_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Crear Presupuesto',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final icons = {
      'Comida': Iconsax.card,
      'Transporte': Iconsax.car,
      'Entretenimiento': Iconsax.game,
      'Compras': Iconsax.shopping_cart,
      'Salud': Iconsax.health,
      'Educación': Iconsax.book,
      'Hogar': Iconsax.home,
      'Viajes': Iconsax.airplane,
    };
    return icons[category] ?? Iconsax.wallet;
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toStringAsFixed(0);
  }
}