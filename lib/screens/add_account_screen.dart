import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:developer' as developer;

import 'package:sasper/widgets/shared/custom_notification_widget.dart';

enum FinancialImpact { low, medium, high, excellent }

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen>
    with TickerProviderStateMixin {
  final AccountRepository _accountRepository = AccountRepository.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  late ConfettiController _confettiController;
  late AnimationController _successAnimController;
  late AnimationController _glowController;
  late AnimationController _projectionController;

  final _creditLimitController = TextEditingController();
  final _closingDayController = TextEditingController();
  final _dueDayController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _maintenanceFeeController = TextEditingController();

  String _selectedType = 'Cuenta Bancaria';
  bool _isLoading = false;
  bool _isSuccess = false;
  //final bool _showProjections = false;

  // 🤖 IA Financial Data (simulado)
  final double _totalAssets = 5800000; // Total actual del usuario
  final double _monthlyIncome = 3200000;
  final double _monthlyExpenses = 2100000;
  int _projectionDays = 30;

  final Map<String, Map<String, dynamic>> _accountTypes = {
    'Efectivo': {
      'icon': Iconsax.money_35,
      'description': 'Liquidez inmediata para gastos diarios',
      'aiTip': 'Perfecto para emergencias y gastos del día a día',
      'riskLevel': 0,
      'liquidity': 100,
      'returns': 0.0,
      'gradient': [Color(0xFF2ECC71), Color(0xFF27AE60)],
    },
    'Cuenta Bancaria': {
      'icon': Iconsax.building_45,
      'description': 'Tu centro de operaciones financieras',
      'aiTip': 'Ideal como cuenta principal para recibir ingresos',
      'riskLevel': 0,
      'liquidity': 95,
      'returns': 0.5,
      'gradient': [Color(0xFF3498DB), Color(0xFF2980B9)],
    },
    'Tarjeta de Crédito': {
      'icon': Iconsax.card5,
      'description': 'Compras a plazos con control inteligente',
      'aiTip': 'La IA te ayudará a evitar sobreendeudamiento',
      'riskLevel': 60,
      'liquidity': 90,
      'returns': -18.5,
      'gradient': [Color(0xFFE74C3C), Color(0xFFC0392B)],
    },
    'Ahorros': {
      'icon': Iconsax.safe_home5,
      'description': 'Construye tu fondo de emergencia',
      'aiTip': 'Protege tu futuro con una reserva sólida',
      'riskLevel': 5,
      'liquidity': 70,
      'returns': 3.2,
      'gradient': [Color(0xFF9B59B6), Color(0xFF8E44AD)],
    },
    'Inversión': {
      'icon': Iconsax.chart_215,
      'description': 'Haz crecer tu patrimonio',
      'aiTip': 'Potencial de 6.8% anual según tu perfil',
      'riskLevel': 45,
      'liquidity': 40,
      'returns': 6.8,
      'gradient': [Color(0xFFF39C12), Color(0xFFE67E22)],
    },
  };

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 2500));
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _projectionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _balanceController.addListener(() {
      setState(() {});
      if (double.tryParse(
              _balanceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) !=
          null) {
        _projectionController.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _confettiController.dispose();
    _successAnimController.dispose();
    _glowController.dispose();
    _projectionController.dispose();
    super.dispose();
  }

  double get _currentBalance {
    return double.tryParse(
            _balanceController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
  }

  FinancialImpact _calculateImpact() {
    final percentage = (_currentBalance / _totalAssets) * 100;
    if (percentage > 40) return FinancialImpact.excellent;
    if (percentage > 20) return FinancialImpact.high;
    if (percentage > 10) return FinancialImpact.medium;
    return FinancialImpact.low;
  }

  Future<void> _saveAccount() async {
    HapticFeedback.mediumImpact();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      final balanceText =
          _balanceController.text.replaceAll(RegExp(r'[^0-9.]'), '');
      final initialBalance = double.tryParse(balanceText) ?? 0.0;

      await _accountRepository.addAccount(
        name: _nameController.text.trim(),
        type: _selectedType,
        initialBalance: initialBalance,
        // Campos extra para Tarjeta de Crédito
        creditLimit: double.tryParse(_creditLimitController.text),
        closingDay: int.tryParse(_closingDayController.text),
        dueDay: int.tryParse(_dueDayController.text),
        interestRate: double.tryParse(_interestRateController.text),
        maintenanceFee: double.tryParse(_maintenanceFeeController.text),
      );

      if (mounted) {
        setState(() => _isSuccess = true);
        HapticFeedback.heavyImpact();
        _successAnimController.forward();
        _confettiController.play();
        EventService.instance.fire(AppEvent.accountCreated);

        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message:
                '¡Cuenta "${_nameController.text.trim()}" creada con éxito! 🎉',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL CREAR CUENTA: $e', name: 'AddAccountScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al crear la cuenta.', type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSuggestionTap(String name, String type) {
    HapticFeedback.mediumImpact();
    setState(() {
      _nameController.text = name;
      _selectedType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
            slivers: [
              _buildGlassAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // 🎯 HERO MOTIVATIONAL CARD
                        _HeroMotivationalCard()
                            .animate()
                            .fadeIn(delay: 100.ms)
                            .slideY(begin: 0.2),

                        const SizedBox(height: 32),

                        _buildSectionHeader(
                          '¿Qué tipo de cuenta necesitas?',
                          'La IA te ayudará a maximizar su potencial',
                        ),
                        const SizedBox(height: 20),
                        _buildAccountTypeSelector(),

                        const SizedBox(height: 32),
                        _buildSectionHeader(
                          'Dale un nombre memorable',
                          'Te ayudará a identificarla rápidamente',
                        ),
                        const SizedBox(height: 16),
                        _PremiumTextFormField(
                          controller: _nameController,
                          labelText: 'Nombre de la cuenta',
                          icon: Iconsax.text,
                          hintText: 'Ej: Mi Banco Principal',
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'El nombre es obligatorio'
                                  : null,
                        ),

                        const SizedBox(height: 24),
                        _buildSmartSuggestions(),
                        if (_selectedType == 'Tarjeta de Crédito') ...[
                          const SizedBox(height: 32),
                          _buildSectionHeader(
                            'Configuración de la Tarjeta',
                            'Datos vitales para que la IA evite intereses',
                          ).animate().fadeIn().slideX(),
                          const SizedBox(height: 16),
_PremiumTextFormField(
  controller: _maintenanceFeeController,
  labelText: 'Cuota de Manejo',
  icon: Iconsax.money_send,
  hintText: 'Ej: 25000',
  keyboardType: TextInputType.number,
),
                                   const SizedBox(height: 16),
                 // Fila para Cupo Total y Tasa de Interés
                          Row(
                            children: [
                              Expanded(
                                child: _PremiumTextFormField(
                                  controller: _creditLimitController,
                                  labelText: 'Cupo Total',
                                  icon: Iconsax.card_send,
                                  hintText: 'Ej: 5000000',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PremiumTextFormField(
                                  controller: _interestRateController,
                                  labelText: 'Interés EA %',
                                  icon: Iconsax.percentage_square,
                                  hintText: 'Ej: 25.5',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Fila para Corte y Pago
                          Row(
                            children: [
                              Expanded(
                                child: _PremiumTextFormField(
                                  controller: _closingDayController,
                                  labelText: 'Día de Corte',
                                  icon: Iconsax.calendar_tick,
                                  hintText: '1 al 31',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PremiumTextFormField(
                                  controller: _dueDayController,
                                  labelText: 'Día de Pago',
                                  icon: Iconsax.timer_1,
                                  hintText: '1 al 31',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // 🤖 Alerta IA de Intereses
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.info_circle5,
                                    color: Colors.orange),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Con una tasa del ${_interestRateController.text}% E.A., pagar a cuotas te costará dinero extra cada mes. ¡Te avisaremos antes de tu fecha de corte!',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),
                        _buildSectionHeader(
                          '¿Con cuánto quieres impulsar esta cuenta?',
                          'Define el saldo inicial para comenzar',
                        ),
                        const SizedBox(height: 16),
                        _BalanceInputField(controller: _balanceController),

                        const SizedBox(height: 32),

                        // 🤖 IA INSIGHTS MODULE
                        _AIInsightModule(
                          balance: _currentBalance,
                          accountType: _selectedType,
                          accountData: _accountTypes[_selectedType]!,
                          impact: _calculateImpact(),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 24),

                        // 📊 PROJECTION CENTER
                        _ProjectionCenter(
                          balance: _currentBalance,
                          monthlyIncome: _monthlyIncome,
                          monthlyExpenses: _monthlyExpenses,
                          accountType: _selectedType,
                          accountData: _accountTypes[_selectedType]!,
                          projectionController: _projectionController,
                          days: _projectionDays,
                          onDaysChanged: (days) =>
                              setState(() => _projectionDays = days),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 24),

                        // 🎯 FINANCIAL HEALTH RADAR
                        _FinancialHealthRadar(
                          balance: _currentBalance,
                          totalAssets: _totalAssets,
                          accountData: _accountTypes[_selectedType]!,
                          glowController: _glowController,
                        ).animate().fadeIn(delay: 400.ms),

                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildIntelligentSaveButton(),
        _buildPremiumConfetti(),
      ],
    );
  }

  // ==========================================================================
  // GLASSMORPHISM APP BAR
  // ==========================================================================

  Widget _buildGlassAppBar() {
    return SliverAppBar.large(
      expandedHeight: 140,
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
              title: Text(
                'Nueva Cuenta',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // ACCOUNT TYPE SELECTOR
  // ==========================================================================

  Widget _buildAccountTypeSelector() {
    return Column(
      children: _accountTypes.keys.map((key) {
        final data = _accountTypes[key]!;
        final isSelected = _selectedType == key;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AccountTypeCard(
            label: key,
            icon: data['icon'],
            description: data['description'],
            aiTip: data['aiTip'],
            gradient: data['gradient'],
            riskLevel: data['riskLevel'],
            liquidity: data['liquidity'],
            returns: data['returns'],
            isSelected: isSelected,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedType = key);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSmartSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.flash_15,
                size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Sugerencias inteligentes',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SuggestionChip(
                label: 'Billetera Digital',
                onTap: () => _onSuggestionTap('Billetera Digital', 'Efectivo')),
            _SuggestionChip(
                label: 'Banco Principal',
                onTap: () =>
                    _onSuggestionTap('Banco Principal', 'Cuenta Bancaria')),
            _SuggestionChip(
                label: 'Tarjeta Platino',
                onTap: () =>
                    _onSuggestionTap('Tarjeta Platino', 'Tarjeta de Crédito')),
            _SuggestionChip(
                label: 'Fondo de Emergencia',
                onTap: () =>
                    _onSuggestionTap('Fondo de Emergencia', 'Ahorros')),
            _SuggestionChip(
                label: 'Portafolio Growth',
                onTap: () =>
                    _onSuggestionTap('Portafolio Growth', 'Inversión')),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // INTELLIGENT SAVE BUTTON
  // ==========================================================================

  Widget _buildIntelligentSaveButton() {
    final accountData = _accountTypes[_selectedType]!;
    final gradient = accountData['gradient'] as List<Color>;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: AnimatedBuilder(
          animation: _successAnimController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isSuccess
                  ? 1.0 + (_successAnimController.value * 0.08)
                  : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                width: _isLoading ? 68 : double.infinity,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_isLoading ? 34 : 24),
                  gradient: LinearGradient(
                    colors: _isSuccess
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : gradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSuccess ? Colors.green : gradient[0])
                          .withOpacity(0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_isLoading || _isSuccess) ? null : _saveAccount,
                    borderRadius: BorderRadius.circular(_isLoading ? 34 : 24),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isLoading
                            ? const SizedBox(
                                height: 32,
                                width: 32,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3.5,
                                ),
                              )
                            : _isSuccess
                                ? const Icon(
                                    Iconsax.tick_circle5,
                                    color: Colors.white,
                                    size: 36,
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Iconsax.add_circle5,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Crear Cuenta Inteligente',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ).animate().slideY(
        begin: 2,
        end: 0,
        delay: 500.ms,
        duration: 700.ms,
        curve: Curves.easeOutCubic);
  }

  Widget _buildPremiumConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        numberOfParticles: 50,
        gravity: 0.25,
        emissionFrequency: 0.03,
        colors: const [
          Color(0xFF3498DB),
          Color(0xFF2ECC71),
          Color(0xFFF39C12),
          Color(0xFF9B59B6),
          Color(0xFFE74C3C),
        ],
        createParticlePath: _drawStar,
      ),
    );
  }

  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (math.pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * math.cos(step),
          halfWidth + externalRadius * math.sin(step));
      path.lineTo(
          halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * math.sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }
}

// =============================================================================
// 🎯 HERO MOTIVATIONAL CARD
// =============================================================================

class _HeroMotivationalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(
                  Iconsax.lamp_on5,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Momento de Potenciar',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tu libertad financiera',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Cada cuenta que creas es un paso hacia el control total de tu dinero. La IA te guiará para maximizar su impacto.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 🏦 ACCOUNT TYPE CARD
// =============================================================================

class _AccountTypeCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final String description;
  final String aiTip;
  final List<Color> gradient;
  final int riskLevel;
  final int liquidity;
  final double returns;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.label,
    required this.icon,
    required this.description,
    required this.aiTip,
    required this.gradient,
    required this.riskLevel,
    required this.liquidity,
    required this.returns,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AccountTypeCard> createState() => _AccountTypeCardState();
}

class _AccountTypeCardState extends State<_AccountTypeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: widget.isSelected
                    ? LinearGradient(
                        colors: [
                          widget.gradient[0].withOpacity(0.15),
                          widget.gradient[1].withOpacity(0.05),
                        ],
                      )
                    : null,
                color: widget.isSelected
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainer,
                border: Border.all(
                  color: widget.isSelected
                      ? widget.gradient[0].withOpacity(0.5)
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withOpacity(0.3),
                  width: widget.isSelected ? 2.5 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: widget.gradient[0].withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              widget.gradient[0].withOpacity(0.25),
                              widget.gradient[1].withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 28,
                          color: widget.gradient[0],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              widget.description,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isSelected)
                        Icon(
                          Iconsax.tick_circle5,
                          color: widget.gradient[0],
                          size: 24,
                        ),
                    ],
                  ),
                  if (widget.isSelected) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: widget.gradient[0].withOpacity(0.08),
                      ),
                      child: Row(
                        children: [
                          Icon(Iconsax.cpu_charge5,
                              size: 16, color: widget.gradient[0]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.aiTip,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.gradient[0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MetricPill(
                          label: 'Retorno',
                          value:
                              '${widget.returns > 0 ? "+" : ""}${widget.returns}%',
                          color:
                              widget.returns >= 0 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        _MetricPill(
                          label: 'Liquidez',
                          value: '${widget.liquidity}%',
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _MetricPill(
                          label: 'Riesgo',
                          value: widget.riskLevel < 20
                              ? 'Bajo'
                              : widget.riskLevel < 50
                                  ? 'Medio'
                                  : 'Alto',
                          color: widget.riskLevel < 20
                              ? Colors.green
                              : widget.riskLevel < 50
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 📝 PREMIUM TEXT FORM FIELD
// =============================================================================

class _PremiumTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _PremiumTextFormField({
    required this.controller,
    required this.labelText,
    required this.icon,
    required this.hintText,
    // ignore: unused_element_parameter
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.2),
                colorScheme.primary.withOpacity(0.05),
              ],
            ),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainer.withOpacity(0.5),
      ),
      validator: validator,
      onChanged: (_) => HapticFeedback.selectionClick(),
    );
  }
}

// =============================================================================
// 💰 BALANCE INPUT FIELD
// =============================================================================

class _BalanceInputField extends StatelessWidget {
  final TextEditingController controller;

  const _BalanceInputField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.3),
            colorScheme.surfaceContainer.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(Iconsax.wallet_35, size: 40, color: colorScheme.primary),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: -2,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
            ],
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '\$ 0',
              hintStyle: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withOpacity(0.15),
                letterSpacing: -2,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'El saldo es obligatorio';
              }
              if (double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ==
                  null) {
                return 'Introduce un saldo válido';
              }
              return null;
            },
            onChanged: (_) => HapticFeedback.selectionClick(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 🤖 AI INSIGHT MODULE
// =============================================================================

class _AIInsightModule extends StatelessWidget {
  final double balance;
  final String accountType;
  final Map<String, dynamic> accountData;
  final FinancialImpact impact;

  const _AIInsightModule({
    required this.balance,
    required this.accountType,
    required this.accountData,
    required this.impact,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = accountData['gradient'] as List<Color>;
    final returns = accountData['returns'] as double;
    final liquidity = accountData['liquidity'] as int;

    String impactMessage;
    IconData impactIcon;
    Color impactColor;

    switch (impact) {
      case FinancialImpact.excellent:
        impactMessage =
            '🚀 Impacto extraordinario: Este saldo representa una adición significativa a tu patrimonio. ¡Excelente decisión estratégica!';
        impactIcon = Iconsax.medal_star5;
        impactColor = Colors.green;
        break;
      case FinancialImpact.high:
        impactMessage =
            '💪 Muy buen movimiento: Estás fortaleciendo tu posición financiera. Este balance optimiza tu liquidez y control.';
        impactIcon = Iconsax.chart_success5;
        impactColor = Colors.blue;
        break;
      case FinancialImpact.medium:
        impactMessage =
            '👍 Paso sólido: Esta cuenta contribuye positivamente a tu ecosistema financiero. Mantén el momentum.';
        impactIcon = Iconsax.shield_tick5;
        impactColor = Colors.orange;
        break;
      case FinancialImpact.low:
        impactMessage =
            '💡 Buen comienzo: Considera incrementar el saldo para maximizar el potencial de esta cuenta.';
        impactIcon = Iconsax.lamp_on5;
        impactColor = Theme.of(context).colorScheme.primary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradient[0].withOpacity(0.1),
            gradient[1].withOpacity(0.05),
          ],
        ),
        border: Border.all(color: gradient[0].withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      impactColor.withOpacity(0.3),
                      impactColor.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(impactIcon, color: impactColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis Inteligente',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: gradient[0],
                      ),
                    ),
                    Text(
                      'Evaluación en tiempo real',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            impactMessage,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          _AIMetricsRow(
            returns: returns,
            liquidity: liquidity,
            balance: balance,
          ),
        ],
      ),
    );
  }
}

class _AIMetricsRow extends StatelessWidget {
  final double returns;
  final int liquidity;
  final double balance;

  const _AIMetricsRow({
    required this.returns,
    required this.liquidity,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final projectedReturns = balance * (returns / 100);

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Iconsax.chart5,
            label: 'Retorno Anual',
            value: returns >= 0
                ? '+${projectedReturns.toStringAsFixed(0)}'
                : '-${projectedReturns.abs().toStringAsFixed(0)}',
            color: returns >= 0 ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            icon: Iconsax.flash_15,
            label: 'Liquidez',
            value: '$liquidity%',
            color: liquidity > 80
                ? Colors.green
                : liquidity > 50
                    ? Colors.orange
                    : Colors.red,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 📊 PROJECTION CENTER
// =============================================================================

class _ProjectionCenter extends StatelessWidget {
  final double balance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final String accountType;
  final Map<String, dynamic> accountData;
  final AnimationController projectionController;
  final int days;
  final Function(int) onDaysChanged;

  const _ProjectionCenter({
    required this.balance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.accountType,
    required this.accountData,
    required this.projectionController,
    required this.days,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = accountData['gradient'] as List<Color>;
    final returns = accountData['returns'] as double;

    final dailyGrowth = (balance * (returns / 100)) / 365;
    final projectedBalance = balance + (dailyGrowth * days);
    final liquidityImpact = ((balance / monthlyExpenses) * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.chart_215, size: 24, color: gradient[0]),
              const SizedBox(width: 12),
              Text(
                'Centro de Proyecciones',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Simular a:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Row(
                children: [
                  _ProjectionButton(
                    label: '30d',
                    isSelected: days == 30,
                    onTap: () => onDaysChanged(30),
                  ),
                  const SizedBox(width: 8),
                  _ProjectionButton(
                    label: '90d',
                    isSelected: days == 90,
                    onTap: () => onDaysChanged(90),
                  ),
                  const SizedBox(width: 8),
                  _ProjectionButton(
                    label: '365d',
                    isSelected: days == 365,
                    onTap: () => onDaysChanged(365),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: projectionController,
            builder: (context, child) {
              return Column(
                children: [
                  _ProjectionMetric(
                    label: 'Balance Proyectado',
                    value: projectedBalance.toStringAsFixed(0),
                    change: projectedBalance - balance,
                    progress: projectionController.value,
                    color: gradient[0],
                  ),
                  const SizedBox(height: 16),
                  _ProjectionMetric(
                    label: 'Impacto en Liquidez Mensual',
                    value: '${liquidityImpact.toStringAsFixed(1)}%',
                    change:
                        (liquidityImpact > 0 ? liquidityImpact : 0).toDouble(),
                    progress: projectionController.value,
                    color: Colors.blue,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: gradient[0].withOpacity(0.08),
            ),
            child: Row(
              children: [
                Icon(Iconsax.info_circle5, size: 18, color: gradient[0]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    returns > 0
                        ? 'Si mantienes este saldo, tu cuenta crecerá aproximadamente \${(dailyGrowth * days).toStringAsFixed(0)} en $days días.'
                        : 'Esta cuenta genera costos de ${returns.abs()}% anual. Considera optimizar tu uso.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProjectionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainer,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ProjectionMetric extends StatelessWidget {
  final String label;
  final String value;
  final double change;
  final double progress;
  final Color color;

  const _ProjectionMetric({
    required this.label,
    required this.value,
    required this.change,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              children: [
                Icon(
                  change >= 0 ? Iconsax.arrow_up_35 : Iconsax.arrow_down5,
                  size: 16,
                  color: change >= 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 🎯 FINANCIAL HEALTH RADAR
// =============================================================================

class _FinancialHealthRadar extends StatelessWidget {
  final double balance;
  final double totalAssets;
  final Map<String, dynamic> accountData;
  final AnimationController glowController;

  const _FinancialHealthRadar({
    required this.balance,
    required this.totalAssets,
    required this.accountData,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = accountData['gradient'] as List<Color>;
    final percentage = ((balance / totalAssets) * 100).clamp(0, 100);
    final riskLevel = accountData['riskLevel'] as int;
    final liquidity = accountData['liquidity'] as int;
    final returns = accountData['returns'] as double;

    final healthScore = ((liquidity * 0.4) +
            ((100 - riskLevel) * 0.3) +
            ((returns > 0 ? returns * 5 : 50) * 0.3))
        .clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradient[0].withOpacity(0.08),
            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: gradient[0].withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.radar5, size: 24, color: gradient[0]),
              const SizedBox(width: 12),
              Text(
                'Radar de Salud Financiera',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: AnimatedBuilder(
              animation: glowController,
              builder: (context, child) {
                return Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            gradient[0].withOpacity(0.3 * glowController.value),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: healthScore / 100,
                          strokeWidth: 12,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainer,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            gradient[0],
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            healthScore.toStringAsFixed(0),
                            style: GoogleFonts.poppins(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: gradient[0],
                              height: 1,
                            ),
                          ),
                          Text(
                            'Score',
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
          ),
          const SizedBox(height: 24),
          _HealthIndicator(
            label: 'Distribución de Activos',
            value: percentage.toDouble(),
            color: gradient[0],
          ),
          const SizedBox(height: 12),
          _HealthIndicator(
            label: 'Nivel de Riesgo',
            value: riskLevel.toDouble(),
            color: riskLevel < 30 ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _HealthIndicator extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _HealthIndicator({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 6,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 💎 SUGGESTION CHIP
// =============================================================================

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label, style: GoogleFonts.inter(fontSize: 13)),
      avatar: Icon(
        Iconsax.flash_15,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      ),
      backgroundColor:
          Theme.of(context).colorScheme.primaryContainer.withOpacity(0.6),
      side: BorderSide(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
