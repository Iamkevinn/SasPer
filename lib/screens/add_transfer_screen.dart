import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:developer' as developer;

import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// =============================================================================
// 🤖 IA FINANCIAL MODELS
// =============================================================================

enum RiskLevel { safe, moderate, warning, critical }

class AccountRecommendation {
  final Account account;
  final String reasoning;
  final double confidenceScore;

  AccountRecommendation({
    required this.account,
    required this.reasoning,
    required this.confidenceScore,
  });
}

class TransferProjection {
  final double balanceAt7Days;
  final double balanceAt30Days;
  final double balanceAt90Days;
  final RiskLevel riskLevel;
  final String riskMessage;
  final List<double> sparklineData;

  TransferProjection({
    required this.balanceAt7Days,
    required this.balanceAt30Days,
    required this.balanceAt90Days,
    required this.riskLevel,
    required this.riskMessage,
    required this.sparklineData,
  });
}

class OptimizationSuggestion {
  final double suggestedAmount;
  final double recommendedReserve;
  final String reasoning;
  final bool isOptimal;

  OptimizationSuggestion({
    required this.suggestedAmount,
    required this.recommendedReserve,
    required this.reasoning,
    required this.isOptimal,
  });
}

// =============================================================================
// 🧠 IA SERVICE (MOCK)
// =============================================================================

class TransferAIService {
  static final TransferAIService instance = TransferAIService._();
  TransferAIService._();

  Future<AccountRecommendation> recommendDestinationAccount(
    List<Account> accounts,
    double amount,
    Account? fromAccount,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));

    if (accounts.isEmpty) {
      throw Exception('No hay cuentas disponibles');
    }

    // Mock: Recomendar cuenta con menor balance (para balancear)
    final sorted = List<Account>.from(accounts)
      ..sort((a, b) => a.balance.compareTo(b.balance));

    final recommended = sorted.first;
    final reasoning = fromAccount != null && amount > fromAccount.balance * 0.7
        ? 'Transferir más del 70% puede reducir tu liquidez inmediata'
        : 'Recomendado para balancear tus activos y mejorar distribución';

    return AccountRecommendation(
      account: recommended,
      reasoning: reasoning,
      confidenceScore: 0.87,
    );
  }

  Stream<TransferProjection> streamTransferProjection(
    Account? fromAccount,
    Account? toAccount,
    double amount,
  ) async* {
    if (fromAccount == null || amount <= 0) {
      yield TransferProjection(
        balanceAt7Days: 0,
        balanceAt30Days: 0,
        balanceAt90Days: 0,
        riskLevel: RiskLevel.safe,
        riskMessage: 'Define un monto para ver proyecciones',
        sparklineData: [0, 0, 0, 0, 0, 0, 0],
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 300));

    final remainingBalance = fromAccount.balance - amount;
    final percentageUsed = (amount / fromAccount.balance) * 100;

    // Mock: Proyección con variación aleatoria
    final random = math.Random();
    final volatility = 0.05; // 5% variación
    
    final balance7d = remainingBalance * (1 + (random.nextDouble() - 0.5) * volatility);
    final balance30d = remainingBalance * (1 + (random.nextDouble() - 0.5) * volatility * 2);
    final balance90d = remainingBalance * (1 + (random.nextDouble() - 0.5) * volatility * 3);

    // Sparkline data (7 puntos)
    final sparkline = List.generate(7, (i) {
      return fromAccount.balance - (amount * (i / 6));
    });

    RiskLevel risk;
    String message;

    if (percentageUsed > 90) {
      risk = RiskLevel.critical;
      message = '⚠️ Alto riesgo: Dejarás solo el ${(100 - percentageUsed).toStringAsFixed(0)}% de saldo disponible';
    } else if (percentageUsed > 70) {
      risk = RiskLevel.warning;
      message = '💡 Atención: Considera mantener más saldo para imprevistos';
    } else if (percentageUsed > 40) {
      risk = RiskLevel.moderate;
      message = '👍 Transferencia moderada - Mantendrás liquidez saludable';
    } else {
      risk = RiskLevel.safe;
      message = '✅ Excelente: Esta transferencia no compromete tu liquidez';
    }

    yield TransferProjection(
      balanceAt7Days: balance7d,
      balanceAt30Days: balance30d,
      balanceAt90Days: balance90d,
      riskLevel: risk,
      riskMessage: message,
      sparklineData: sparkline,
    );
  }

  Future<OptimizationSuggestion> optimizeTransferAmount(
    Account fromAccount,
    double requestedAmount,
  ) async {
    await Future.delayed(const Duration(milliseconds: 350));

    final minimumReserve = fromAccount.balance * 0.20; // 20% como reserva
    final maxSafeTransfer = fromAccount.balance - minimumReserve;

    if (requestedAmount <= maxSafeTransfer) {
      return OptimizationSuggestion(
        suggestedAmount: requestedAmount,
        recommendedReserve: minimumReserve,
        reasoning: 'Monto óptimo - Mantienes una reserva saludable del 20%',
        isOptimal: true,
      );
    }

    return OptimizationSuggestion(
      suggestedAmount: maxSafeTransfer,
      recommendedReserve: minimumReserve,
      reasoning:
          'Sugerencia: deja ${NumberFormat.currency(locale: "es_CO", symbol: "\$", decimalDigits: 0).format(minimumReserve)} como reserva para imprevistos',
      isOptimal: false,
    );
  }
}

// =============================================================================
// 🎯 MAIN SCREEN
// =============================================================================

class AddTransferScreen extends StatefulWidget {
  const AddTransferScreen({super.key});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen>
    with TickerProviderStateMixin {
  final AccountRepository _accountRepository = AccountRepository.instance;
  final TransferAIService _aiService = TransferAIService.instance;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  late ConfettiController _confettiController;
  late AnimationController _successAnimController;
  late AnimationController _pulseController;

  Account? _fromAccount;
  Account? _toAccount;

  bool _isLoading = false;
  bool _isSuccess = false;

  Timer? _debounceTimer;
  final _projectionStreamController =
      StreamController<TransferProjection>.broadcast();

  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 2000));
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _confettiController.dispose();
    _successAnimController.dispose();
    _pulseController.dispose();
    _debounceTimer?.cancel();
    _projectionStreamController.close();
    super.dispose();
  }

  void _onAmountChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateProjections();
      _formKey.currentState?.validate();
    });
  }

  void _updateProjections() {
    final amount = double.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;

    _aiService
        .streamTransferProjection(_fromAccount, _toAccount, amount)
        .listen((projection) {
      _projectionStreamController.add(projection);
    });
  }

  double get _currentAmount {
    return double.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
  }

  Future<void> _submitForm() async {
    HapticFeedback.mediumImpact();

    if (_isLoading || _isSuccess) return;

    if (_fromAccount == null || _toAccount == null) {
      _showErrorBanner('Debes seleccionar ambas cuentas para continuar');
      HapticFeedback.heavyImpact();
      return;
    }

    if (_fromAccount!.id == _toAccount!.id) {
      _showErrorBanner('No puedes transferir a la misma cuenta');
      HapticFeedback.heavyImpact();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    // Confirmación si es transferencia grande
    if (_currentAmount > _fromAccount!.balance * 0.7) {
      final confirm = await _showHighRiskConfirmation();
      if (!confirm) return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      await _accountRepository.createTransfer(
        fromAccountId: _fromAccount!.id,
        toAccountId: _toAccount!.id,
        amount: _currentAmount,
        description: _descriptionController.text.trim().isEmpty
            ? 'Transferencia interna'
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSuccess = true);
        HapticFeedback.heavyImpact();
        _successAnimController.forward();
        _confettiController.play();
        EventService.instance.fire(AppEvent.transactionsChanged);

        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: '¡Transferencia realizada con éxito! 🎉',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL CREAR TRANSFERENCIA: $e',
          name: 'AddTransferScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showErrorBanner(
            'Error: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showHighRiskConfirmation() async {
    HapticFeedback.mediumImpact();
    
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => _HighRiskConfirmationSheet(
            amount: _currentAmount,
            remainingBalance: _fromAccount!.balance - _currentAmount,
            fromAccount: _fromAccount!,
          ),
        ) ??
        false;
  }

  void _showErrorBanner(String message) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(
          message,
          style: GoogleFonts.manrope(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        leading: const Icon(Iconsax.warning_25, color: Colors.red),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Account>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              (snapshot.data?.length ?? 0) < 2) {
            return _buildErrorState();
          }

          final accounts = snapshot.data!;
          return Stack(
            children: [
              _buildFormUI(accounts),
              _buildIntelligentSubmitButton(),
              _buildPremiumConfetti(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormUI(List<Account> accounts) {
    return CustomScrollView(
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

                  // ACCOUNT SELECTOR - FROM
                  _AccountSelectorCard(
                    label: 'Cuenta Origen',
                    account: _fromAccount,
                    accounts: accounts,
                    onTap: () => _showAccountPicker(accounts, true),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),

                  const SizedBox(height: 20),

                  // TRANSFER SUMMARY HERO CARD
                  _TransferSummaryHeroCard(
                    fromAccount: _fromAccount,
                    toAccount: _toAccount,
                    amount: _currentAmount,
                    pulseController: _pulseController,
                  ).animate().fadeIn(delay: 200.ms).scale(begin: Offset(0.9, 0.9)),

                  const SizedBox(height: 20),

                  // ACCOUNT SELECTOR - TO
                  _AccountSelectorCard(
                    label: 'Cuenta Destino',
                    account: _toAccount,
                    accounts: accounts,
                    onTap: () => _showAccountPicker(accounts, false),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.2),

                  const SizedBox(height: 32),

                  _buildSectionHeader(
                    '¿Cuánto quieres transferir?',
                    'Usa el teclado o selecciona una sugerencia rápida',
                  ),

                  const SizedBox(height: 20),

                  // AMOUNT INPUT
                  _AmountInputField(
                    controller: _amountController,
                    fromAccount: _fromAccount,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El monto es obligatorio';
                      }
                      final amount = double.tryParse(
                          value.replaceAll(RegExp(r'[^0-9.]'), ''));
                      if (amount == null || amount <= 0) {
                        return 'Introduce un monto válido mayor a 0';
                      }
                      if (_fromAccount != null && amount > _fromAccount!.balance) {
                        return 'Saldo insuficiente - máximo ${NumberFormat.currency(locale: "es_CO", symbol: "\$", decimalDigits: 0).format(_fromAccount!.balance)}';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // AMOUNT SUGGESTIONS
                  if (_fromAccount != null)
                    _AmountSuggestionsRow(
                      fromAccount: _fromAccount!,
                      onSuggestionTap: (amount) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _amountController.text = amount.toStringAsFixed(0);
                        });
                      },
                    ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 32),

                  // AI PROJECTIONS MODULE
                  StreamBuilder<TransferProjection>(
                    stream: _projectionStreamController.stream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || _currentAmount == 0) {
                        return const SizedBox.shrink();
                      }

                      return _AIProjectionModule(
                        projection: snapshot.data!,
                        fromAccount: _fromAccount,
                        amount: _currentAmount,
                      ).animate().fadeIn(delay: 500.ms);
                    },
                  ),

                  const SizedBox(height: 24),

                  // DESCRIPTION
                  _DescriptionInputField(
                    controller: _descriptionController,
                  ),

                  const SizedBox(height: 24),

                  // SECURITY INFO
                  _SecurityInfoBox().animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

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
                'Nueva Transferencia',
                style: GoogleFonts.manrope(
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
      actions: [
        IconButton(
          icon: const Icon(Iconsax.info_circle),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showInfoDialog();
          },
          tooltip: '¿Cómo funcionan las proyecciones?',
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '💡 Transferencias Inteligentes',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Nuestra IA analiza tus patrones financieros y proyecta el impacto de cada transferencia '
          'en tu liquidez futura. Te ayudamos a tomar decisiones informadas y mantener tu salud financiera óptima.',
          style: GoogleFonts.inter(height: 1.6),
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

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
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

  void _showAccountPicker(List<Account> accounts, bool isFromAccount) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          snap: true,
          snapSizes: const [0.6, 0.9],
          builder: (context, scrollController) {
            return _AccountPickerSheet(
              accounts: accounts,
              scrollController: scrollController,
              excludeAccount: isFromAccount ? _toAccount : _fromAccount,
              onAccountSelected: (selectedAccount) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isFromAccount) {
                    _fromAccount = selectedAccount;
                  } else {
                    _toAccount = selectedAccount;
                  }
                });
                _updateProjections();
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildIntelligentSubmitButton() {
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
                        : [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.8),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSuccess
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary)
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
                    onTap: (_isLoading || _isSuccess) ? null : _submitForm,
                    borderRadius:
                        BorderRadius.circular(_isLoading ? 34 : 24),
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
                                        Iconsax.send_25,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Confirmar Transferencia',
                                        style: GoogleFonts.manrope(
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
        delay: 600.ms,
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
        numberOfParticles: 40,
        gravity: 0.25,
        emissionFrequency: 0.02,
        colors: const [
          Color(0xFF2ECC71),
          Color(0xFF3498DB),
          Color(0xFFF39C12),
          Color(0xFF9B59B6),
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

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 24),
              Text(
                'Cuentas Insuficientes',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Necesitas al menos dos cuentas para realizar transferencias internas.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Iconsax.add_circle),
                label: const Text('Crear Nueva Cuenta'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 🏦 ACCOUNT SELECTOR CARD
// =============================================================================

class _AccountSelectorCard extends StatefulWidget {
  final String label;
  final Account? account;
  final List<Account> accounts;
  final VoidCallback onTap;

  const _AccountSelectorCard({
    required this.label,
    this.account,
    required this.accounts,
    required this.onTap,
  });

  @override
  State<_AccountSelectorCard> createState() => _AccountSelectorCardState();
}

class _AccountSelectorCardState extends State<_AccountSelectorCard>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

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
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: widget.account != null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primaryContainer.withOpacity(0.4),
                          colorScheme.surfaceContainer.withOpacity(0.6),
                        ],
                      )
                    : null,
                color: widget.account == null
                    ? colorScheme.surfaceContainer
                    : null,
                border: Border.all(
                  color: widget.account != null
                      ? colorScheme.primary.withOpacity(0.3)
                      : colorScheme.outlineVariant.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: widget.account != null
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          (widget.account != null
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant)
                              .withOpacity(0.2),
                          (widget.account != null
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant)
                              .withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: Icon(
                      widget.account?.icon ?? Iconsax.wallet_add_1,
                      color: widget.account != null
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.account?.name ?? 'Seleccionar cuenta',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.account != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.account != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.account!.type,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Disponible: ${currencyFormat.format(widget.account!.balance)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_down_1,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// 🎯 TRANSFER SUMMARY HERO CARD
// =============================================================================

class _TransferSummaryHeroCard extends StatelessWidget {
  final Account? fromAccount;
  final Account? toAccount;
  final double amount;
  final AnimationController pulseController;

  const _TransferSummaryHeroCard({
    this.fromAccount,
    this.toAccount,
    required this.amount,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
    );

    final percentageUsed = fromAccount != null && amount > 0
        ? (amount / fromAccount!.balance) * 100
        : 0.0;

    Color borderColor;
    Color backgroundColor;
    IconData warningIcon = Iconsax.info_circle;

    if (percentageUsed > 90) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.1);
      warningIcon = Iconsax.danger;
    } else if (percentageUsed > 70) {
      borderColor = Colors.orange;
      backgroundColor = Colors.orange.withOpacity(0.1);
      warningIcon = Iconsax.warning_2;
    } else {
      borderColor = colorScheme.primary;
      backgroundColor = colorScheme.primaryContainer.withOpacity(0.3);
    }

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    backgroundColor,
                    colorScheme.surface.withOpacity(0.6),
                  ],
                ),
                border: Border.all(
                  color: borderColor
                      .withOpacity(0.3 + (pulseController.value * 0.2)),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: borderColor.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              fromAccount?.icon ?? Iconsax.wallet,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              fromAccount?.name ?? 'Origen',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Icon(
                              Iconsax.arrow_right_3,
                              color: borderColor,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFormat.format(amount),
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: borderColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              toAccount?.icon ?? Iconsax.wallet,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              toAccount?.name ?? 'Destino',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (percentageUsed > 70 && fromAccount != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(warningIcon, color: borderColor, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              percentageUsed > 90
                                  ? 'Esta transferencia dejará la cuenta con solo ${currencyFormat.format(fromAccount!.balance - amount)}'
                                  : 'Transferirás el ${percentageUsed.toStringAsFixed(0)}% del saldo disponible',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: borderColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 💰 AMOUNT INPUT FIELD
// =============================================================================

class _AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  final Account? fromAccount;
  final String? Function(String?)? validator;

  const _AmountInputField({
    required this.controller,
    this.fromAccount,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Estilo de texto compartido para el símbolo de '$' y el campo de texto.
    final textStyle = GoogleFonts.manrope(
      fontSize: 52,
      fontWeight: FontWeight.bold,
      color: colorScheme.primary,
      letterSpacing: -2,
    );

    // Estilo para el hint.
    final hintStyle = GoogleFonts.manrope(
      fontSize: 52,
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface.withOpacity(0.15),
      letterSpacing: -2,
    );

    return FormField<String>(
      // 1. Mueve el validador al widget FormField exterior.
      validator: validator,
      // Sincroniza el estado inicial del campo.
      initialValue: controller.text,
      builder: (FormFieldState<String> state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                colorScheme.primaryContainer.withOpacity(0.2),
                colorScheme.surfaceContainer.withOpacity(0.5),
              ],
            ),
            border: Border.all(
              // Cambia el color del borde si hay un error.
              color: state.hasError
                  ? colorScheme.error
                  : colorScheme.primary.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(Iconsax.wallet_money, size: 36, color: colorScheme.primary),
              const SizedBox(height: 12),

              // 2. Usa una Fila (Row) para centrar el '$' y el campo de texto como un grupo.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('\$', style: textStyle),
                  const SizedBox(width: 4), // Espacio pequeño
                  IntrinsicWidth(
                    child: TextFormField(
                      controller: controller,
                      // El validador ya no es necesario aquí.
                      textAlign: TextAlign.start, // Alineación al inicio dentro de su contenedor.
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      style: textStyle,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        // Ya no se necesita prefixText.
                        hintText: '0',
                        hintStyle: hintStyle,
                        // Oculta el mensaje de error por defecto para mostrar el nuestro.
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                      ),
                      onChanged: (value) {
                        // Sincroniza el estado del FormField para que la validación se active.
                        state.didChange(value);
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ),
                ],
              ),
              // 3. Muestra nuestro propio mensaje de error centrado.
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    state.errorText!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ),

              if (fromAccount != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Disponible: ${NumberFormat.currency(locale: "es_CO", symbol: "\$", decimalDigits: 0).format(fromAccount!.balance)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// 💡 AMOUNT SUGGESTIONS ROW
// =============================================================================

class _AmountSuggestionsRow extends StatelessWidget {
  final Account fromAccount;
  final Function(double) onSuggestionTap;

  const _AmountSuggestionsRow({
    required this.fromAccount,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      {'label': '25%', 'value': fromAccount.balance * 0.25},
      {'label': '50%', 'value': fromAccount.balance * 0.50},
      {'label': '75%', 'value': fromAccount.balance * 0.75},
      {'label': 'Todo', 'value': fromAccount.balance},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.flash_15,
                size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Sugerencias rápidas',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: suggestions.map((suggestion) {
            return _AmountSuggestionChip(
              label: suggestion['label'] as String,
              amount: suggestion['value'] as double,
              onTap: () => onSuggestionTap(suggestion['value'] as double),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AmountSuggestionChip extends StatelessWidget {
  final String label;
  final double amount;
  final VoidCallback onTap;

  const _AmountSuggestionChip({
    required this.label,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return ActionChip(
      onPressed: onTap,
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            currencyFormat.format(amount),
            style: GoogleFonts.inter(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      avatar: Icon(
        Iconsax.flash_15,
        size: 16,
        color: colorScheme.primary,
      ),
      backgroundColor: colorScheme.primaryContainer.withOpacity(0.6),
      side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}

// =============================================================================
// 🤖 AI PROJECTION MODULE
// =============================================================================

class _AIProjectionModule extends StatelessWidget {
  final TransferProjection projection;
  final Account? fromAccount;
  final double amount;

  const _AIProjectionModule({
    required this.projection,
    this.fromAccount,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color riskColor;
    IconData riskIcon;

    switch (projection.riskLevel) {
      case RiskLevel.critical:
        riskColor = Colors.red;
        riskIcon = Iconsax.danger;
        break;
      case RiskLevel.warning:
        riskColor = Colors.orange;
        riskIcon = Iconsax.warning_2;
        break;
      case RiskLevel.moderate:
        riskColor = Colors.blue;
        riskIcon = Iconsax.shield_tick;
        break;
      case RiskLevel.safe:
        riskColor = Colors.green;
        riskIcon = Iconsax.shield_tick;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            riskColor.withOpacity(0.08),
            colorScheme.surfaceContainer.withOpacity(0.5),
          ],
        ),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      riskColor.withOpacity(0.3),
                      riskColor.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(Iconsax.cpu_charge, color: riskColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis Predictivo',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Proyección basada en tus patrones',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: riskColor.withOpacity(0.1),
              border: Border.all(color: riskColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(riskIcon, color: riskColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    projection.riskMessage,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ProjectionTimeline(projection: projection, riskColor: riskColor),
          const SizedBox(height: 20),
          if (fromAccount != null)
            _SparklineChart(
              data: projection.sparklineData,
              color: riskColor,
            ),
        ],
      ),
    );
  }
}

class _ProjectionTimeline extends StatelessWidget {
  final TransferProjection projection;
  final Color riskColor;

  const _ProjectionTimeline({
    required this.projection,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Row(
      children: [
        Expanded(
          child: _ProjectionPoint(
            label: '7 días',
            value: currencyFormat.format(projection.balanceAt7Days),
            color: riskColor,
          ),
        ),
        Expanded(
          child: _ProjectionPoint(
            label: '30 días',
            value: currencyFormat.format(projection.balanceAt30Days),
            color: riskColor,
          ),
        ),
        Expanded(
          child: _ProjectionPoint(
            label: '90 días',
            value: currencyFormat.format(projection.balanceAt90Days),
            color: riskColor,
          ),
        ),
      ],
    );
  }
}

class _ProjectionPoint extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ProjectionPoint({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SparklineChart extends StatelessWidget {
  final List<double> data;
  final Color color;

  const _SparklineChart({
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.05),
      ),
      child: CustomPaint(
        painter: _SparklinePainter(data: data, color: color),
        child: Container(),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [color.withOpacity(0.3), color.withOpacity(0.0)],
      )
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final max = data.reduce(math.max);
    final min = data.reduce(math.min);
    final range = max - min;

    final xStep = size.width / (data.length - 1);

    fillPath.moveTo(0, size.height);

    for (var i = 0; i < data.length; i++) {
      final x = i * xStep;
      final normalizedValue = range > 0 ? (data[i] - min) / range : 0.5;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =============================================================================
// 📝 DESCRIPTION INPUT
// =============================================================================

class _DescriptionInputField extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionInputField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      maxLength: 100,
      style: GoogleFonts.inter(fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Descripción (Opcional)',
        hintText: 'Ej: Pago de servicios, Ahorro mensual...',
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
          child: Icon(Iconsax.note_text, color: colorScheme.primary, size: 20),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainer.withOpacity(0.5),
      ),
      onChanged: (_) => HapticFeedback.selectionClick(),
    );
  }
}

// =============================================================================
// 🔒 SECURITY INFO BOX
// =============================================================================

class _SecurityInfoBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.08),
            colorScheme.surfaceContainer.withOpacity(0.5),
          ],
        ),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.1),
            ),
            child: const Icon(Iconsax.shield_tick5, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transferencia Segura',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cifrada de extremo a extremo • Instantánea',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
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

// =============================================================================
// 🏦 ACCOUNT PICKER SHEET
// =============================================================================

class _AccountPickerSheet extends StatefulWidget {
  final List<Account> accounts;
  final ScrollController scrollController;
  final Account? excludeAccount;
  final Function(Account) onAccountSelected;

  const _AccountPickerSheet({
    required this.accounts,
    required this.scrollController,
    this.excludeAccount,
    required this.onAccountSelected,
  });

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    final filteredAccounts = widget.accounts.where((account) {
      if (widget.excludeAccount?.id == account.id) return false;
      if (_searchQuery.isEmpty) return true;
      return account.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort: highest balance first
    filteredAccounts.sort((a, b) => b.balance.compareTo(a.balance));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Iconsax.wallet_check, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Selecciona una Cuenta',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Search bar
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Buscar cuenta...',
                  prefixIcon: const Icon(Iconsax.search_normal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainer,
                ),
              ),
              
              const SizedBox(height: 20),
              
              Expanded(
                child: filteredAccounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.search_status_1,
                              size: 60,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron cuentas',
                              style: GoogleFonts.inter(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: widget.scrollController,
                        itemCount: filteredAccounts.length,
                        itemBuilder: (context, index) {
                          final account = filteredAccounts[index];
                          final isRecommended = index == 0 && _searchQuery.isEmpty;
                          
                          return _AccountPickerTile(
                            account: account,
                            isRecommended: isRecommended,
                            onTap: () => widget.onAccountSelected(account),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPickerTile extends StatefulWidget {
  final Account account;
  final bool isRecommended;
  final VoidCallback onTap;

  const _AccountPickerTile({
    required this.account,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  State<_AccountPickerTile> createState() => _AccountPickerTileState();
}

class _AccountPickerTileState extends State<_AccountPickerTile>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
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
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: widget.isRecommended
                      ? colorScheme.primaryContainer.withOpacity(0.5)
                      : colorScheme.surfaceContainer,
                  border: Border.all(
                    color: widget.isRecommended
                        ? colorScheme.primary.withOpacity(0.5)
                        : colorScheme.outlineVariant.withOpacity(0.3),
                    width: widget.isRecommended ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withOpacity(0.2),
                            colorScheme.primary.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Icon(
                        widget.account.icon,
                        color: colorScheme.primary,
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
                                  widget.account.name,
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (widget.isRecommended)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Iconsax.star5,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Recomendada',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.account.type,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                currencyFormat.format(widget.account.balance),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Iconsax.arrow_right_3,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// ⚠️ HIGH RISK CONFIRMATION SHEET
// =============================================================================

class _HighRiskConfirmationSheet extends StatelessWidget {
  final double amount;
  final double remainingBalance;
  final Account fromAccount;

  const _HighRiskConfirmationSheet({
    required this.amount,
    required this.remainingBalance,
    required this.fromAccount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
    );
    final percentage = (amount / fromAccount.balance) * 100;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.orange.withOpacity(0.3),
                      Colors.orange.withOpacity(0.1),
                    ],
                  ),
                ),
                child: const Icon(
                  Iconsax.warning_25,
                  color: Colors.orange,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¿Estás seguro?',
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Estás a punto de transferir el ${percentage.toStringAsFixed(0)}% del saldo de esta cuenta',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    _ConfirmationRow(
                      label: 'Monto a transferir',
                      value: currencyFormat.format(amount),
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    _ConfirmationRow(
                      label: 'Saldo restante',
                      value: currencyFormat.format(remainingBalance),
                      color: remainingBalance < fromAccount.balance * 0.2
                          ? Colors.red
                          : colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: colorScheme.outline),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context, true);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange,
                      ),
                      child: Text(
                        'Continuar',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

class _ConfirmationRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ConfirmationRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}