// lib/widgets/goals/contribute_to_goal_dialog.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

// ── Tokens de diseño ─────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.5, height: 1.1);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

const _kBlue = Color(0xFF0A84FF);
const _kGreen = Color(0xFF30D158);
const _kPurple = Color(0xFFBF5AF2);

// ─────────────────────────────────────────────────────────────────────────────

class ContributeToGoalDialog extends StatefulWidget {
  final Goal goal;
  final VoidCallback onSuccess;

  const ContributeToGoalDialog({
    super.key,
    required this.goal,
    required this.onSuccess,
  });

  @override
  State<ContributeToGoalDialog> createState() => _ContributeToGoalDialogState();
}

class _ContributeToGoalDialogState extends State<ContributeToGoalDialog> {
  final AccountRepository _accountRepo = AccountRepository.instance;
  final GoalRepository _goalRepo = GoalRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  Account? _selectedAccount;
  bool _isSubmitting = false;
  late Future<List<Account>> _accountsFuture;

  // Variables para la Máquina del Tiempo
  double _simulatedAmount = 0;
  late double _remainingAmount;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepo.getAccounts();
    _remainingAmount = (widget.goal.targetAmount - widget.goal.currentAmount).clamp(0, double.infinity);
    
    // Si la meta tiene una cuota guardada, empezamos la simulación ahí
    if (widget.goal.savingsAmount != null && widget.goal.savingsAmount! > 0) {
      _simulatedAmount = widget.goal.savingsAmount!;
      if (_simulatedAmount > _remainingAmount) _simulatedAmount = _remainingAmount;
      _amountController.text = _simulatedAmount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    HapticFeedback.selectionClick();
    setState(() {
      _simulatedAmount = value;
      if (value > 0) {
        _amountController.text = value.toStringAsFixed(0);
      } else {
        _amountController.text = '';
      }
    });
  }

  Future<void> _submitContribution() async {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) return;

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      
      await _goalRepo.addContribution(
        goalId: widget.goal.id,
        accountId: _selectedAccount!.id,
        amount: amount,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Aportación realizada con éxito ✨',
            type: NotificationType.success,
          );
        });
      }
    } catch (error) {
      developer.log('🔥 FALLO AL APORTAR: $error', name: 'ContributeToGoalDialog');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al realizar la aportación.',
            type: NotificationType.error,
          );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white; // iOS Modal color

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:[
              // Grabber de iOS
              Center(
                child: Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: onSurf.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              Text('Aportar a tu meta', style: _T.label(14, c: onSurf.withOpacity(0.5))),
              const SizedBox(height: 4),
              Text(widget.goal.name, style: _T.display(24, c: onSurf)),
              
              const SizedBox(height: 24),

              // Formulario Principal
              FutureBuilder<List<Account>>(
                future: _accountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: _kBlue)));
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('No tienes cuentas disponibles.', style: _T.label(14, c: onSurf)),
                    );
                  }
                  
                  final accounts = snapshot.data!;
                  if (_selectedAccount == null && accounts.isNotEmpty) {
                    _selectedAccount = accounts.first;
                  }

                  return _buildForm(accounts, onSurf);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(List<Account> accounts, Color onSurf) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          // Input de Monto Estilizado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: onSurf.withOpacity(0.08)),
            ),
            child: TextFormField(
              controller: _amountController,
              style: _T.display(32, c: _kBlue),
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixText: '\$ ',
                prefixStyle: _T.display(32, c: _kBlue.withOpacity(0.5)),
                hintText: '0',
                hintStyle: _T.display(32, c: onSurf.withOpacity(0.2)),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (val) {
                final parsed = double.tryParse(val.replaceAll(',', '.'));
                if (parsed != null) setState(() => _simulatedAmount = parsed);
              },
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa un monto';
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) return 'Monto inválido';
                if (_selectedAccount != null && amount > _selectedAccount!.balance) {
                  return 'No tienes saldo suficiente en esta cuenta';
                }
                if (amount > _remainingAmount) return 'No puedes aportar más de lo que falta';
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 16),

          // Selector de Cuenta
          DropdownButtonFormField<Account>(
            value: _selectedAccount,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: onSurf.withOpacity(0.5)),
            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            style: _T.label(15, c: onSurf),
            onChanged: (Account? newValue) => setState(() => _selectedAccount = newValue),
            items: accounts.map((account) {
              return DropdownMenuItem<Account>(
                value: account,
                child: Text('${account.name} · ${fmt.format(account.balance)}'),
              );
            }).toList(),
            decoration: InputDecoration(
              filled: true,
              fillColor: onSurf.withOpacity(0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 🚀 MÓDULO C: LA MÁQUINA DEL TIEMPO
          if (_remainingAmount > 0)
            _TimeMachineCard(
              goal: widget.goal,
              simulatedAmount: _simulatedAmount,
              remainingAmount: _remainingAmount,
              onSliderChanged: _onSliderChanged,
            ),

          const SizedBox(height: 32),

          // Botón Submit
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (!_isSubmitting) _submitContribution();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _isSubmitting ? _kBlue.withOpacity(0.5) : _kBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Confirmar Aportación', style: _T.label(16, c: Colors.white, w: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO C: LA MÁQUINA DEL TIEMPO (SIMULADOR DE IMPACTO)
// ─────────────────────────────────────────────────────────────────────────────

class _TimeMachineCard extends StatelessWidget {
  final Goal goal;
  final double simulatedAmount;
  final double remainingAmount;
  final ValueChanged<double> onSliderChanged;

  const _TimeMachineCard({
    required this.goal,
    required this.simulatedAmount,
    required this.remainingAmount,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmtDate = DateFormat.yMMMMd('es_CO');

    // -- 1. Matemática del Ritmo Actual (Si no lo haces...) --
    double currentPaceDaily = 0;
    if (goal.savingsAmount != null && goal.savingsAmount! > 0) {
      double amt = goal.savingsAmount!;
      if (goal.savingsFrequency == GoalSavingsFrequency.daily) currentPaceDaily = amt;
      else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) currentPaceDaily = amt / 7;
      else currentPaceDaily = amt / 30.4; // Monthly by default
    }

    DateTime? dateCurrentPace;
    if (currentPaceDaily > 0) {
      int daysToFinishCurrent = (remainingAmount / currentPaceDaily).ceil();
      dateCurrentPace = DateTime.now().add(Duration(days: daysToFinishCurrent));
    }

    // -- 2. Matemática del Ritmo Simulado (Ahorrando esto...) --
    double simPaceDaily = 0;
    if (simulatedAmount > 0) {
      if (goal.savingsFrequency == GoalSavingsFrequency.daily) simPaceDaily = simulatedAmount;
      else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) simPaceDaily = simulatedAmount / 7;
      else simPaceDaily = simulatedAmount / 30.4; // Asumimos mensual si no hay frecuencia
    }

    DateTime? dateSimulated;
    if (simPaceDaily > 0) {
      int daysToFinishSim = (remainingAmount / simPaceDaily).ceil();
      dateSimulated = DateTime.now().add(Duration(days: daysToFinishSim));
    }

    // -- 3. Construcción del Mensaje --
    String freqText = 'al mes';
    if (goal.savingsFrequency == GoalSavingsFrequency.daily) freqText = 'al día';
    if (goal.savingsFrequency == GoalSavingsFrequency.weekly) freqText = 'a la semana';

    String titleMessage = '🔮 Simulador del Tiempo';
    String bodyMessage = '';
    Color statusColor = _kPurple;

    if (simulatedAmount <= 0) {
      bodyMessage = 'Mueve el control para ver cuándo llegarás a tu meta si cambias tu aporte.';
      statusColor = onSurf.withOpacity(0.5);
    } else if (simulatedAmount >= remainingAmount) {
      bodyMessage = '¡Felicidades! Si aportas esto, completas tu meta **hoy mismo**. 🎉';
      statusColor = _kGreen;
    } else {
      String dateA = fmtDate.format(dateSimulated!);
      bodyMessage = 'Aportando esto $freqText, llegas el **$dateA**.\n';

      if (dateCurrentPace != null) {
        String dateB = fmtDate.format(dateCurrentPace);
        // Verificar si está adelantando o retrasando
        if (dateSimulated.isBefore(dateCurrentPace)) {
          bodyMessage += 'Si no lo haces (con tu cuota actual), te vas hasta **$dateB**. ¡Adelantas tiempo!';
          statusColor = _kGreen;
        } else if (dateSimulated.isAfter(dateCurrentPace)) {
          bodyMessage += 'Si sigues con tu cuota actual, llegas el **$dateB**. Te estarías atrasando.';
          statusColor = const Color(0xFFFF9F0A); // Orange
        } else {
          bodyMessage += 'Mantienes tu ritmo actual (llegando en $dateB).';
          statusColor = _kBlue;
        }
      } else {
        bodyMessage += 'Actualmente no tienes un ritmo fijo guardado.';
      }
    }

    // Dividimos el mensaje para pintar en negrita las fechas
    final parts = bodyMessage.split('**');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? _kPurple.withOpacity(0.1) : _kPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children:[
                Icon(Iconsax.magic_star5, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(titleMessage, style: _T.label(14, w: FontWeight.w700, c: statusColor)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RichText(
              text: TextSpan(
                style: _T.label(13, c: onSurf.withOpacity(0.7), w: FontWeight.w400).copyWith(height: 1.4),
                children: parts.asMap().entries.map((entry) {
                  // Los índices impares son los que estaban entre '**'
                  final isBold = entry.key % 2 != 0;
                  return TextSpan(
                    text: entry.value,
                    style: isBold ? TextStyle(fontWeight: FontWeight.w800, color: onSurf) : null,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: statusColor,
              inactiveTrackColor: statusColor.withOpacity(0.2),
              thumbColor: Colors.white,
              overlayColor: statusColor.withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            ),
            child: Slider(
              value: simulatedAmount.clamp(0, remainingAmount),
              min: 0,
              max: remainingAmount,
              divisions: 100,
              onChanged: onSliderChanged,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}