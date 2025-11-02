import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/services/ai_analysis_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

// =============================================================================
// 🤖 AI ANALYSIS MODELS
// =============================================================================

enum AiAnalysisState { initial, loading, success, error }

enum FinancialHealth { critical, poor, fair, good, excellent }

class FinancialInsight {
  final String title;
  final String description;
  final String impact;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback? onAction;

  FinancialInsight({
    required this.title,
    required this.description,
    required this.impact,
    required this.icon,
    required this.color,
    required this.actionLabel,
    this.onAction,
  });
}

class AIRecommendation {
  final String title;
  final String description;
  final double projectedImpact;
  final String impactUnit;
  final IconData icon;
  final Color color;

  AIRecommendation({
    required this.title,
    required this.description,
    required this.projectedImpact,
    required this.impactUnit,
    required this.icon,
    required this.color,
  });
}

// =============================================================================
// 🎯 MAIN SCREEN
// =============================================================================

class AiFinancialAnalysisScreen extends StatefulWidget {
  const AiFinancialAnalysisScreen({super.key});

  @override
  State<AiFinancialAnalysisScreen> createState() =>
      _AiFinancialAnalysisScreenState();
}

class _AiFinancialAnalysisScreenState extends State<AiFinancialAnalysisScreen>
    with TickerProviderStateMixin {
  final AiAnalysisService _aiService = AiAnalysisService();

  AiAnalysisState _currentState = AiAnalysisState.initial;
  String? _analysisResult;
  String? _aiErrorMessage;

  late AnimationController _pulseController;
  late AnimationController _brainController;
  late AnimationController _scoreController;

  // Mock data
  final FinancialHealth _healthScore = FinancialHealth.good;
  final double _scoreValue = 78;
  final double _savingsImprovement = 12;
  final int _monthsAhead = 4;

  final List<AIRecommendation> _recommendations = [];
  final List<FinancialInsight> _insights = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _brainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _initializeMockData();
  }

  void _initializeMockData() {
    _recommendations.addAll([
      AIRecommendation(
        title: 'Reducir gastos fijos',
        description:
            'Al disminuir gastos recurrentes en 5%, liberarás más capital',
        projectedImpact: 200000,
        impactUnit: '/mes',
        icon: Iconsax.money_remove,
        color: Colors.orange,
      ),
      AIRecommendation(
        title: 'Automatizar inversiones',
        description: 'Invierte excedentes automáticamente cada mes',
        projectedImpact: 8,
        impactUnit: '% anual',
        icon: Iconsax.chart_success,
        color: Colors.green,
      ),
      AIRecommendation(
        title: 'Optimizar deudas',
        description: 'Consolida deudas de alta tasa en un solo préstamo',
        projectedImpact: 150000,
        impactUnit: '/año',
        icon: Iconsax.receipt_discount,
        color: Colors.blue,
      ),
    ]);

    _insights.addAll([
      FinancialInsight(
        title: 'Riesgo de sobregiro',
        description:
            'Tu flujo de efectivo podría estar en riesgo dentro de 21 días',
        impact: 'Alto riesgo',
        icon: Iconsax.danger,
        color: Colors.red,
        actionLabel: 'Prevenir ahora',
      ),
      FinancialInsight(
        title: 'Oportunidad de ahorro',
        description: 'Puedes redirigir \$300.000 a inversiones este mes',
        impact: '+\$3.6M anual',
        icon: Iconsax.coin_1,
        color: Colors.green,
        actionLabel: 'Activar ahorro',
      ),
    ]);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _brainController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalysis() async {
    HapticFeedback.mediumImpact();
    setState(() => _currentState = AiAnalysisState.loading);
    _scoreController.forward(from: 0);

    try {
      await Future.delayed(const Duration(milliseconds: 2500));
      final result = await _aiService.getFinancialAnalysis();

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _currentState = AiAnalysisState.success;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiErrorMessage = e.toString().replaceFirst("Exception: ", "");
          _currentState = AiAnalysisState.error;
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          _buildGlassAppBar(),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildContentForCurrentState(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // GLASS APP BAR
  // ==========================================================================

  Widget _buildGlassAppBar() {
    return SliverAppBar.large(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  Theme.of(context).colorScheme.surface.withOpacity(0.6),
                ],
              ),
            ),
            child: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3 * _pulseController.value),
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1 * _pulseController.value),
                            ],
                          ),
                        ),
                        child: Icon(
                          Iconsax.cpu_charge5,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Análisis IA',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
          ),
        ),
      ),
      actions: [
        if (_currentState == AiAnalysisState.success)
          IconButton(
            icon: const Icon(Iconsax.refresh),
            onPressed: _fetchAnalysis,
            tooltip: 'Recalcular análisis',
          ),
        IconButton(
          icon: const Icon(Iconsax.setting_4),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showSettingsSheet();
          },
          tooltip: 'Configuración de IA',
        ),
      ],
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AISettingsSheet(),
    );
  }

  // ==========================================================================
  // CONTENT SWITCHER
  // ==========================================================================

  Widget _buildContentForCurrentState() {
    switch (_currentState) {
      case AiAnalysisState.initial:
        return _buildInitialState();
      case AiAnalysisState.loading:
        return _buildLoadingState();
      case AiAnalysisState.success:
        return _buildSuccessState();
      case AiAnalysisState.error:
        return _buildErrorState();
    }
  }

  // ==========================================================================
  // INITIAL STATE
  // ==========================================================================

  Widget _buildInitialState() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        key: const ValueKey('initial'),
        children: [
          const SizedBox(height: 40),

          // AI Illustration
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.surface,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Iconsax.cpu_charge5,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ).animate().scale(delay: 200.ms, duration: 600.ms),

          const SizedBox(height: 40),

          Text(
            'Tu Asesor Financiero Personal',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          Text(
            'Activa el análisis inteligente para recibir recomendaciones personalizadas, detectar oportunidades y optimizar tu salud financiera en tiempo real.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 40),

          // Features Grid
          _FeaturesGrid().animate().fadeIn(delay: 800.ms),

          const SizedBox(height: 40),

          // CTA Button
          FilledButton.icon(
            onPressed: _fetchAnalysis,
            icon: const Icon(Iconsax.flash_15, size: 24),
            label: Text(
              'Activar Análisis Inteligente',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ).animate().slideY(begin: 0.3, delay: 1000.ms),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOADING STATE
  // ==========================================================================

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        key: const ValueKey('loading'),
        children: [
          const SizedBox(height: 60),

          // Animated Brain Processing
          AnimatedBuilder(
            animation: _brainController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(200, 200),
                painter: _NeuralNetworkPainter(
                  progress: _brainController.value,
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          Text(
            'Procesando tu información financiera',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'La IA está analizando patrones, detectando oportunidades y generando recomendaciones personalizadas...',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Loading Steps
          _LoadingSteps().animate().fadeIn(),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUCCESS STATE
  // ==========================================================================

  Widget _buildSuccessState() {
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 20),

        // Hero Insight Card
        _HeroInsightCard(
          healthScore: _healthScore,
          scoreValue: _scoreValue,
          savingsImprovement: _savingsImprovement,
          monthsAhead: _monthsAhead,
          scoreController: _scoreController,
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

        const SizedBox(height: 24),

        // Financial Health Dashboard
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu Salud Financiera',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _HealthMetricsRow().animate().fadeIn(delay: 300.ms),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // AI Insights
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Iconsax.eye,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Insights Detectados',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._insights.asMap().entries.map((entry) {
                return _InsightCard(
                  insight: entry.value,
                ).animate().fadeIn(delay: (400 + (entry.key * 100)).ms);
              }),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // AI Recommendations
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Iconsax.lamp_on5,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Recomendaciones Inteligentes',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._recommendations.asMap().entries.map((entry) {
                return _RecommendationChip(
                  recommendation: entry.value,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showRecommendationDetails(entry.value);
                  },
                ).animate().fadeIn(delay: (600 + (entry.key * 100)).ms);
              }),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Markdown Analysis
        if (_analysisResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainer
                    .withOpacity(0.5),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.document_text5,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Análisis Detallado',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MarkdownBody(
                    data: _analysisResult!,
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.7,
                      ),
                      h3: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 800.ms),
          ),

        const SizedBox(height: 100),
      ],
    );
  }

  void _showRecommendationDetails(AIRecommendation recommendation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _RecommendationDetailSheet(
        recommendation: recommendation,
      ),
    );
  }

  // ==========================================================================
  // ERROR STATE
  // ==========================================================================

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        key: const ValueKey('error'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.errorContainer,
            ),
            child: Icon(
              Iconsax.warning_25,
              size: 60,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Ups, algo salió mal',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _aiErrorMessage ??
                'No pudimos completar el análisis. Por favor, intenta nuevamente.',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: _fetchAnalysis,
            icon: const Icon(Iconsax.refresh),
            label: const Text('Reintentar con IA Mejorada'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showTroubleshootingTips();
            },
            icon: const Icon(Iconsax.info_circle),
            label: const Text('Ver Soluciones'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  void _showTroubleshootingTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '💡 Consejos para Solucionar',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '• Verifica tu conexión a internet\n'
          '• Asegúrate de tener transacciones registradas\n'
          '• Intenta cerrar y abrir la app\n'
          '• Si el problema persiste, contacta soporte',
          style: GoogleFonts.inter(height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 🎨 CUSTOM WIDGETS
// =============================================================================

class _FeaturesGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final features = [
      {'icon': Iconsax.chart_success, 'label': 'Proyecciones\nIA'},
      {'icon': Iconsax.shield_tick, 'label': 'Detección\nde Riesgos'},
      {'icon': Iconsax.lamp_on, 'label': 'Recomendaciones\nPersonalizadas'},
      {'icon': Iconsax.trend_up, 'label': 'Optimización\nAutomática'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).colorScheme.surfaceContainer,
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                feature['icon'] as IconData,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                feature['label'] as String,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingSteps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      'Analizando transacciones...',
      'Detectando patrones...',
      'Generando recomendaciones...',
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Center(
                  child: Text(
                    '${entry.key + 1}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  entry.value,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ).animate(delay: (entry.key * 500).ms).fadeIn();
      }).toList(),
    );
  }
}

class _NeuralNetworkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _NeuralNetworkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // Draw rotating neural network
    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + (progress * math.pi * 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      final nodePos = Offset(x, y);

      // Draw connections
      canvas.drawLine(center, nodePos, paint);

      // Draw nodes
      canvas.drawCircle(nodePos, 6, nodePaint);
    }

    // Draw center node
    canvas.drawCircle(center, 10, nodePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _HeroInsightCard extends StatelessWidget {
  final FinancialHealth healthScore;
  final double scoreValue;
  final double savingsImprovement;
  final int monthsAhead;
  final AnimationController scoreController;

  const _HeroInsightCard({
    required this.healthScore,
    required this.scoreValue,
    required this.savingsImprovement,
    required this.monthsAhead,
    required this.scoreController,
  });

  @override
  Widget build(BuildContext context) {
    Color healthColor;
    String healthLabel;

    switch (healthScore) {
      case FinancialHealth.excellent:
        healthColor = Colors.green;
        healthLabel = 'Excelente';
        break;
      case FinancialHealth.good:
        healthColor = Colors.blue;
        healthLabel = 'Buena';
        break;
      case FinancialHealth.fair:
        healthColor = Colors.orange;
        healthLabel = 'Regular';
        break;
      case FinancialHealth.poor:
        healthColor = Colors.deepOrange;
        healthLabel = 'Mejorable';
        break;
      case FinancialHealth.critical:
        healthColor = Colors.red;
        healthLabel = 'Crítica';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              healthColor.withOpacity(0.15),
              Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.8),
            ],
          ),
          border: Border.all(color: healthColor.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: healthColor.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: healthColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: healthColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.cpu_charge5, size: 14, color: healthColor),
                      const SizedBox(width: 6),
                      Text(
                        'IA en tiempo real',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: healthColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: scoreController,
              builder: (context, child) {
                return SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: scoreController.value * (scoreValue / 100),
                        strokeWidth: 12,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainer,
                        valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(scoreValue * scoreController.value).toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: healthColor,
                              height: 1,
                            ),
                          ),
                          Text(
                            healthLabel,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Tu capacidad de ahorro ha mejorado un ${savingsImprovement.toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.flash_15, size: 16, color: healthColor),
                const SizedBox(width: 8),
                Text(
                  'Te acerca a tu objetivo $monthsAhead meses antes',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthMetricsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final metrics = [
      {
        'label': 'Ingresos',
        'value': '\$3.2M',
        'trend': '+12%',
        'color': Colors.green
      },
      {
        'label': 'Gastos',
        'value': '\$2.1M',
        'trend': '-5%',
        'color': Colors.blue
      },
      {
        'label': 'Ahorro',
        'value': '\$1.1M',
        'trend': '+34%',
        'color': Colors.purple
      },
    ];

    return Row(
      children: metrics.map((metric) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: (metric['color'] as Color).withOpacity(0.1),
              border: Border.all(
                color: (metric['color'] as Color).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  metric['value'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Iconsax.arrow_up_3,
                      size: 12,
                      color: metric['color'] as Color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      metric['trend'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: metric['color'] as Color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final FinancialInsight insight;

  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: insight.color.withOpacity(0.08),
        border: Border.all(color: insight.color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: insight.color.withOpacity(0.15),
                ),
                child: Icon(insight.icon, color: insight.color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      insight.impact,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: insight.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              insight.onAction?.call();
            },
            icon: Icon(Iconsax.flash_15, size: 18),
            label: Text(insight.actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: insight.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  final AIRecommendation recommendation;
  final VoidCallback onTap;

  const _RecommendationChip({
    required this.recommendation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              recommendation.color.withOpacity(0.1),
              Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
            ],
          ),
          border: Border.all(
            color: recommendation.color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    recommendation.color.withOpacity(0.3),
                    recommendation.color.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                recommendation.icon,
                color: recommendation.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: recommendation.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recommendation.impactUnit.contains('%')
                          ? '+${recommendation.projectedImpact}${recommendation.impactUnit}'
                          : '+${currencyFormat.format(recommendation.projectedImpact)}${recommendation.impactUnit}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: recommendation.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              color: recommendation.color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationDetailSheet extends StatelessWidget {
  final AIRecommendation recommendation;

  const _RecommendationDetailSheet({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      recommendation.color.withOpacity(0.3),
                      recommendation.color.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(
                  recommendation.icon,
                  size: 48,
                  color: recommendation.color,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                recommendation.title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                recommendation.description,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: recommendation.color.withOpacity(0.1),
                  border: Border.all(
                    color: recommendation.color.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Impacto Proyectado',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recommendation.impactUnit.contains('%')
                          ? '+${recommendation.projectedImpact}${recommendation.impactUnit}'
                          : '+${currencyFormat.format(recommendation.projectedImpact)}${recommendation.impactUnit}',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: recommendation.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        // TODO: Implement activation
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: recommendation.color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Activar Ahora'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AISettingsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Iconsax.setting_45,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Configuración de IA',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SettingsTile(
                icon: Iconsax.personalcard,
                title: 'Nivel de Personalización',
                subtitle: 'Alto',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Iconsax.notification,
                title: 'Notificaciones Predictivas',
                subtitle: 'Activadas',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Iconsax.timer_1,
                title: 'Frecuencia de Análisis',
                subtitle: 'Diaria',
                onTap: () {},
              ),
              _SettingsTile(
                icon: Iconsax.shield_tick,
                title: 'Privacidad de Datos',
                subtitle: 'Máxima seguridad',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('Guardar Cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
