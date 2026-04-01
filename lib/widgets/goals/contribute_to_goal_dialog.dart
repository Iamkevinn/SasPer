// lib/widgets/goals/contribute_to_goal_dialog.dart

import 'dart:ui';
import 'dart:math' as math; // 👈 NECESARIO PARA EL CONFETI
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';

import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/services/event_service.dart';
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
const _kOrange = Color(0xFFFF9F0A);
const _kRed = Color(0xFFFF453A);
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

  late double _remainingAmount;
  double _simulatedAmount = 0; // 👈 VARIABLE PARA LA MÁQUINA DEL TIEMPO
  
  // 🎊 Controlador de Confeti
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepo.getAccounts();
    _remainingAmount = (widget.goal.targetAmount - widget.goal.currentAmount).clamp(0, double.infinity);
    
    // Sugerir la cuota oficial por defecto si existe y arrancar el simulador
    if (widget.goal.savingsAmount != null && widget.goal.savingsAmount! > 0) {
      double suggested = widget.goal.savingsAmount!;
      if (suggested > _remainingAmount) suggested = _remainingAmount;
      _simulatedAmount = suggested;
      _amountController.text = suggested.toStringAsFixed(0);
    }
    
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // 👈 CONEXIÓN DEL SLIDER CON EL TEXTFIELD
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
      final amount = double.parse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
      
      // 🚀 USAMOS LA FUNCIÓN GAMIFICADA DEL REPOSITORIO
      final gamificationData = await _goalRepo.addContributionWithGamification(
        goalId: widget.goal.id,
        accountId: _selectedAccount!.id,
        amount: amount,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        EventService.instance.fire(AppEvent.transactionCreated);
        
        final milestone = gamificationData['milestoneReached'] as int?;
        final streak = gamificationData['newStreak'] as int? ?? 1;

        if (milestone != null) {
          _confettiController.play();
          NotificationHelper.show(
            message: '¡Increíble! Has alcanzado el $milestone% de tu meta. 🎊', 
            type: NotificationType.success
          );
          await Future.delayed(const Duration(seconds: 2));
        } else if (streak > 2) {
          NotificationHelper.show(
            message: '¡Buena racha! Llevas $streak aportes seguidos 🔥', 
            type: NotificationType.info
          );
        } else {
          NotificationHelper.show(
            message: 'Aporte registrado correctamente ✨', 
            type: NotificationType.success
          );
        }

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess();
        }
      }
    } catch (error) {
      developer.log('🔥 FALLO AL APORTAR: $error', name: 'ContributeToGoalDialog');
      if (mounted) {
        NotificationHelper.show(message: 'Error al realizar la aportación.', type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children:[
        Container(
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
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(color: onSurf.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  Text('Aportar a tu meta', style: _T.label(14, c: onSurf.withOpacity(0.5))),
                  const SizedBox(height: 4),
                  Text(widget.goal.name, style: _T.display(24, c: onSurf)),
                  
                  const SizedBox(height: 24),

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
        ),
        
        // 🎊 CONFETI OVERLAY
        Positioned(
          top: -50,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const[_kBlue, _kGreen, _kOrange, _kPurple, _kRed],
            createParticlePath: _drawStar,
            numberOfParticles: 50,
            gravity: 0.2,
          ),
        ),
      ],
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
      path.lineTo(halfWidth + externalRadius * math.cos(step), halfWidth + externalRadius * math.sin(step));
      path.lineTo(halfWidth + internalRadius * math.cos(step + halfDegreesPerStep), halfWidth + internalRadius * math.sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  Widget _buildForm(List<Account> accounts, Color onSurf) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          // Input de Monto
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
              inputFormatters:[FilteringTextInputFormatter.digitsOnly, _MoneyFormatter()],
              onChanged: (val) {
                final parsed = double.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
                if (parsed != null) setState(() => _simulatedAmount = parsed);
              },
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa un monto';
                final amount = double.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 24),

          // 🚀 MÓDULO: LA MÁQUINA DEL TIEMPO 
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
// MÓDULO: LA MÁQUINA DEL TIEMPO (SIMULADOR DE IMPACTO)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// MÓDULO: LA MÁQUINA DEL TIEMPO (SIMULADOR MATEMÁTICO REAL)
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
    final fmtCurrency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    // ── 1. Calcular el ritmo diario oficial del usuario ──
    double currentPaceDaily = 0;
    if (goal.savingsAmount != null && goal.savingsAmount! > 0) {
      double amt = goal.savingsAmount!;
      if (goal.savingsFrequency == GoalSavingsFrequency.daily) {
        currentPaceDaily = amt;
      } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
        currentPaceDaily = amt / 7;
      } else {
        currentPaceDaily = amt / 30.437; // Promedio mensual
      }
    }

    String titleMessage = '🔮 Máquina del Tiempo';
    String bodyMessage = '';
    Color statusColor = _kPurple;

    // ── 2. Lógica Inteligente según el aporte ──
    if (simulatedAmount <= 0) {
      bodyMessage = 'Mueve el control para ver **cuánto tiempo te ahorras** con este aporte extra.';
      statusColor = onSurf.withOpacity(0.5);
    } else if (simulatedAmount >= remainingAmount) {
      bodyMessage = '¡Felicidades! Si aportas esto, completas tu meta **hoy mismo**. 🎉';
      statusColor = _kGreen;
    } else if (currentPaceDaily > 0) {
      // ── MATEMÁTICA REAL DE ACELERACIÓN ──
      // ¿En cuántos días terminaba antes del aporte?
      int daysCurrent = (remainingAmount / currentPaceDaily).ceil();
      
      // ¿En cuántos días terminará DESPUÉS del aporte?
      double newRemaining = remainingAmount - simulatedAmount;
      int daysNew = (newRemaining / currentPaceDaily).ceil();
      DateTime dateNew = DateTime.now().add(Duration(days: daysNew));

      // ¿Cuántos días se ahorró en total?
      int daysSaved = daysCurrent - daysNew;
      String dateStr = fmtDate.format(dateNew);

      if (daysSaved > 0) {
        // Formateo humano del tiempo ahorrado
        String timeSavedStr = '';
        if (daysSaved >= 30) {
          int months = daysSaved ~/ 30;
          timeSavedStr = '$months ${months == 1 ? 'mes' : 'meses'}';
        } else if (daysSaved >= 7) {
          int weeks = daysSaved ~/ 7;
          timeSavedStr = '$weeks ${weeks == 1 ? 'semana' : 'semanas'}';
        } else {
          timeSavedStr = '$daysSaved ${daysSaved == 1 ? 'día' : 'días'}';
        }

        bodyMessage = 'Llegarás a tu meta el **$dateStr**.\n¡Le estás adelantando **$timeSavedStr** al futuro! 🚀';
        statusColor = _kGreen;
      } else {
         bodyMessage = 'Llegarás a tu meta el **$dateStr**. ¡Todo suma!';
         statusColor = _kBlue;
      }
    } else {
      // Caso donde el usuario no tiene un plan fijo guardado, solo ahorra cuando quiere
      double newRemaining = remainingAmount - simulatedAmount;
      bodyMessage = 'Aportando esto, te faltarán solo **${fmtCurrency.format(newRemaining)}** para lograr tu meta. ¡Buen trabajo!';
      statusColor = _kBlue;
    }

    final parts = bodyMessage.split('**');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? statusColor.withOpacity(0.1) : statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.2)),
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
class _MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue nw) {
    if (nw.text.isEmpty) return nw.copyWith(text: '');
    final n = int.tryParse(nw.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final t = NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0).format(n);
    return nw.copyWith(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}