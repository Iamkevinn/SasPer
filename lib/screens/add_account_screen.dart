// lib/screens/add_account_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Nueva Cuenta — Apple-first redesign
//
// Eliminado:
// · SliverAppBar.large + FlexibleSpaceBar + LinearGradient → header blur sticky
// · _HeroMotivationalCard (copy motivacional sin info útil) → header tipográfico
// · _buildSectionHeader × 4 con subtítulos vacíos → _GroupLabel 11px uppercase
// · LinearGradient + Border.all + BoxShadow en _AccountTypeCard → opacity surface
// · BoxShape.circle + LinearGradient en ícono de cada card → borderRadius
// · _MetricPill con Border.all por cada métrica → texto inline con color
// · _glowController 2000ms repeat pulsando BoxShadow → eliminado
// · _confettiController + ConfettiWidget 50 estrellas → HapticFeedback + pop
// · _successAnimController + Transform.scale en botón → _SaveBtn limpio
// · AnimatedContainer morphing (width: 68 → infinity) en botón → _SaveBtn
// · LinearGradient dinámico en botón según tipo → _kBlue consistente
// · .animate().slideY(begin:2) 500ms en botón → visible inmediatamente
// · _AIInsightModule con emojis y datos simulados → _InsightCard con datos reales
// · _ProjectionCenter con datos hardcodeados → eliminado
// · _FinancialHealthRadar con glow pulsante → _ScoreRing limpio sin glow
// · Future.delayed(1200ms) artificial → eliminado
// · _isSuccess + 2000ms + addPostFrameCallback → HapticFeedback + pop inmediato
// · _PremiumTextFormField BoxShape.circle gradient en ícono → _InputField patrón app
// · _BalanceInputField LinearGradient + Border + Icon wallet decorativo → campo limpio
// · ActionChip Material en sugerencias → _SuggestionPill con press state
// · InkWell + ripple en _ProjectionButton → GestureDetector press state
// · LinearProgressIndicator minHeight:8/6 → _ProgressBar 4px unificado
// · GoogleFonts.poppins + .inter → _T tokens DM Sans
// · Colores hardcodeados por tipo → paleta iOS _kBlue/_kGreen/_kRed/_kOrange/_kPurple
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:sasper/data/account_repository.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Tokens ─────────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s, fontWeight: w, color: c,
          letterSpacing: -0.4, height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);

  static TextStyle mono(double s,
          {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kPurple = Color(0xFFBF5AF2);

// ── Color semántico por tipo de cuenta ─────────────────────────────────────────
// Un solo color por tipo — sin gradientes. Parte de la paleta iOS.
const _typeColors = <String, Color>{
  'Efectivo':           _kGreen,
  'Cuenta Bancaria':    _kBlue,
  'Tarjeta de Crédito': _kRed,
  'Ahorros':            _kPurple,
  'Inversión':          _kOrange,
};

const _typeIcons = <String, IconData>{
  'Efectivo':           Iconsax.money_3,
  'Cuenta Bancaria':    Iconsax.building_4,
  'Tarjeta de Crédito': Iconsax.card,
  'Ahorros':            Iconsax.safe_home,
  'Inversión':          Iconsax.chart_2,
};

// Datos de cada tipo — solo los que son informativos y reales
const _typeData = <String, ({String description, String tip})>{
  'Efectivo': (
    description: 'Liquidez inmediata para gastos diarios',
    tip:         'Ideal para emergencias y gastos cotidianos.',
  ),
  'Cuenta Bancaria': (
    description: 'Centro de operaciones financieras',
    tip:         'Perfecta como cuenta principal para recibir ingresos.',
  ),
  'Tarjeta de Crédito': (
    description: 'Compras a plazos con control de intereses',
    tip:         'Configura los días de corte y pago para evitar intereses.',
  ),
  'Ahorros': (
    description: 'Fondo de emergencia y metas a largo plazo',
    tip:         'Mantén 3-6 meses de gastos como reserva mínima.',
  ),
  'Inversión': (
    description: 'Crecimiento de patrimonio a mediano plazo',
    tip:         'Rendimiento potencial del 6.8% anual según el mercado.',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});
  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen>
    with SingleTickerProviderStateMixin {
  final _repo    = AccountRepository.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl            = TextEditingController();
  final _balanceCtrl         = TextEditingController(text: '0');
  final _creditLimitCtrl     = TextEditingController();
  final _closingDayCtrl      = TextEditingController();
  final _dueDayCtrl          = TextEditingController();
  final _interestRateCtrl    = TextEditingController();
  final _maintenanceFeeCtrl  = TextEditingController();

  String _selectedType = 'Cuenta Bancaria';
  bool   _loading      = false;

  // Fade-in único — sin delays escalonados
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();
    _balanceCtrl.addListener(() => setState(() {}));
    _interestRateCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _creditLimitCtrl.dispose();
    _closingDayCtrl.dispose();
    _dueDayCtrl.dispose();
    _interestRateCtrl.dispose();
    _maintenanceFeeCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  double get _currentBalance =>
      double.tryParse(
          _balanceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
      0.0;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _loading = true);

    try {
      final balance = double.tryParse(
              _balanceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;

      await _repo.addAccount(
        name:           _nameCtrl.text.trim(),
        type:           _selectedType,
        initialBalance: balance,
        creditLimit:    double.tryParse(_creditLimitCtrl.text),
        closingDay:     int.tryParse(_closingDayCtrl.text),
        dueDay:         int.tryParse(_dueDayCtrl.text),
        interestRate:   double.tryParse(_interestRateCtrl.text),
        maintenanceFee: double.tryParse(_maintenanceFeeCtrl.text),
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        EventService.instance.fire(AppEvent.accountCreated);
        Navigator.of(context).pop(true);
        NotificationHelper.show(
            message:
                'Cuenta "${_nameCtrl.text.trim()}" creada',
            type: NotificationType.success);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al crear la cuenta.',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySuggestion(String name, String type) {
    HapticFeedback.selectionClick();
    setState(() {
      _nameCtrl.text  = name;
      _selectedType   = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;
    final bottomP = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          // ── Header blur sticky ───────────────────────────────────────
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: theme.scaffoldBackgroundColor.withOpacity(0.93),
                padding: EdgeInsets.only(
                    top: statusH + 10, left: 8,
                    right: 20, bottom: 14),
                child: Row(children: [
                  _BackBtn(),
                  const SizedBox(width: 4),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SASPER',
                          style: _T.label(10,
                              w: FontWeight.w700,
                              c: onSurf.withOpacity(0.35))),
                      Text('Nueva cuenta',
                          style: _T.display(28, c: onSurf)),
                    ],
                  )),
                ]),
              ),
            ),
          ),

          // ── Scroll ──────────────────────────────────────────────────
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: bottomP > 0 ? bottomP + 100 : 120,
              ),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Tipo de cuenta ─────────────────────────────
                      _GroupLabel('TIPO DE CUENTA'),
                      const SizedBox(height: 10),
                      _TypeSelector(
                        selected: _selectedType,
                        onChanged: (t) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedType = t);
                        },
                      ),
                      const SizedBox(height: 28),

                      // ── Nombre ─────────────────────────────────────
                      _GroupLabel('NOMBRE'),
                      const SizedBox(height: 10),
                      _InputField(
                        controller:      _nameCtrl,
                        label:           'Nombre de la cuenta',
                        hint:            'Ej: Mi Banco Principal',
                        icon:            Iconsax.text,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'El nombre es obligatorio' : null,
                      ),
                      const SizedBox(height: 12),

                      // Sugerencias rápidas
                      _Suggestions(onTap: _applySuggestion),
                      const SizedBox(height: 28),

                      // ── Campos tarjeta de crédito ──────────────────
                      if (_selectedType == 'Tarjeta de Crédito') ...[
                        _GroupLabel('CONFIGURACIÓN DE TARJETA'),
                        const SizedBox(height: 10),
                        _FieldGroup(children: [
                          _InputField(
                            controller:   _maintenanceFeeCtrl,
                            label:        'Cuota de manejo',
                            hint:         'Ej: 25000',
                            icon:         Iconsax.money_send,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                          ),
                          _FieldDivider(),
                          Row(children: [
                            Expanded(child: _InputField(
                              controller:   _creditLimitCtrl,
                              label:        'Cupo total',
                              hint:         'Ej: 5000000',
                              icon:         Iconsax.card_send,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              noBg: true,
                            )),
                            _VDivider(),
                            Expanded(child: _InputField(
                              controller:   _interestRateCtrl,
                              label:        'Interés EA %',
                              hint:         'Ej: 25.5',
                              icon:         Iconsax.percentage_square,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              noBg: true,
                            )),
                          ]),
                          _FieldDivider(),
                          Row(children: [
                            Expanded(child: _InputField(
                              controller:   _closingDayCtrl,
                              label:        'Día de corte',
                              hint:         '1 al 31',
                              icon:         Iconsax.calendar_tick,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              noBg: true,
                            )),
                            _VDivider(),
                            Expanded(child: _InputField(
                              controller:   _dueDayCtrl,
                              label:        'Día de pago',
                              hint:         '1 al 31',
                              icon:         Iconsax.timer_1,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              noBg: true,
                            )),
                          ]),
                        ]),

                        // Alerta de interés — solo si hay tasa
                        if (_interestRateCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _AlertTile(
                            color:   _kOrange,
                            icon:    Iconsax.info_circle,
                            message:
                                'Con ${_interestRateCtrl.text}% E.A., pagar a cuotas genera interés mensual. Te avisaremos antes de tu fecha de corte.',
                          ),
                        ],
                        const SizedBox(height: 28),
                      ],

                      // ── Saldo inicial ──────────────────────────────
                      _GroupLabel('SALDO INICIAL'),
                      const SizedBox(height: 10),
                      _BalanceField(controller: _balanceCtrl),
                      const SizedBox(height: 28),

                      // ── Insight de cuenta — datos reales ──────────
                      // Solo aparece cuando hay saldo ingresado
                      if (_currentBalance > 0) ...[
                        _InsightCard(
                          balance:     _currentBalance,
                          accountType: _selectedType,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Botón guardar sticky ─────────────────────────────────────
          _SaveBtn(loading: _loading, onTap: _save),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE SELECTOR
// ─────────────────────────────────────────────────────────────────────────────
// Lista vertical de tiles — tap selecciona y expande el detalle.
// Sin gradientes, sin border per-card. Selected: color opacity bg + checkmark.

class _TypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final types = _typeData.keys.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: types.indexed.map((e) {
          final (i, type) = e;
          final isLast     = i == types.length - 1;
          final isSelected = type == selected;
          return _TypeTile(
            type:       type,
            isSelected: isSelected,
            showDivider: !isLast,
            onTap:      () => onChanged(type),
          );
        }).toList(),
      ),
    );
  }
}

class _TypeTile extends StatefulWidget {
  final String type;
  final bool isSelected, showDivider;
  final VoidCallback onTap;
  const _TypeTile({
    required this.type,
    required this.isSelected,
    required this.showDivider,
    required this.onTap,
  });
  @override
  State<_TypeTile> createState() => _TypeTileState();
}

class _TypeTileState extends State<_TypeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color  = _typeColors[widget.type]!;
    final icon   = _typeIcons[widget.type]!;
    final data   = _typeData[widget.type]!;

    return GestureDetector(
      onTapDown: (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              // Selected: fondo del color del tipo, muy sutil
              color: widget.isSelected
                  ? color.withOpacity(0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(children: [
                  // Ícono en container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? color.withOpacity(0.14)
                          : color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(child: Icon(icon, size: 17, color: color)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.type,
                          style: _T.label(15,
                              w: FontWeight.w700,
                              c: widget.isSelected
                                  ? onSurf
                                  : onSurf)),
                      const SizedBox(height: 1),
                      Text(data.description,
                          style: _T.label(11,
                              c: onSurf.withOpacity(0.42),
                              w: FontWeight.w400)),
                    ],
                  )),
                  // Checkmark al seleccionar
                  AnimatedOpacity(
                    opacity: widget.isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.check_rounded,
                        size: 18, color: color),
                  ),
                ]),
              ),

              // Detalle expandible — solo en selected
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: widget.isSelected
                    ? _TypeDetail(type: widget.type, color: color)
                    : const SizedBox.shrink(),
              ),

              // Separador entre items (no después del último)
              if (widget.showDivider && !widget.isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 16 + 38 + 14),
                  child: Container(
                      height: 0.5,
                      color: onSurf.withOpacity(0.07)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// Detalle del tipo seleccionado: tip + 3 métricas en línea
class _TypeDetail extends StatelessWidget {
  final String type;
  final Color color;
  const _TypeDetail({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final data   = _typeData[type]!;


    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tip — una línea útil
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Iconsax.info_circle, size: 13, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(data.tip,
                  style: _T.label(12,
                      c: onSurf.withOpacity(0.65),
                      w: FontWeight.w400))),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _InlineMetric({
    required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _T.label(10, c: onSurf.withOpacity(0.38))),
        const SizedBox(height: 2),
        Text(value,
            style: _T.mono(12, c: color)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
          width: 3, height: 3,
          decoration: BoxDecoration(
            color: onSurf.withOpacity(0.15),
            shape: BoxShape.circle)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BALANCE FIELD
// ─────────────────────────────────────────────────────────────────────────────
// El número es el protagonista. Sin ícono decorativo, sin gradiente.
// El campo de 48px comunica importancia por sí solo.

class _BalanceField extends StatelessWidget {
  final TextEditingController controller;
  const _BalanceField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('\$',
              style: _T.display(28,
                  c: onSurf.withOpacity(0.35))),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.left,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}'))
              ],
              style: _T.display(40, c: onSurf),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: _T.display(40,
                    c: onSurf.withOpacity(0.15)),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'El saldo es obligatorio';
                }
                if (double.tryParse(
                        v.replaceAll(RegExp(r'[^0-9.]'), '')) ==
                    null) {
                  return 'Saldo inválido';
                }
                return null;
              },
            ),
          ),
          // Unidad de moneda
          Text('COP',
              style: _T.label(12,
                  c: onSurf.withOpacity(0.30),
                  w: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSIGHT CARD — datos reales del formulario
// ─────────────────────────────────────────────────────────────────────────────
// Aparece solo cuando _currentBalance > 0.
// Muestra: retorno proyectado anual (en pesos) + riesgo del tipo.
// Sin emojis. Sin copy motivacional. Solo los dos números que importan.

class _InsightCard extends StatelessWidget {
  final double balance;
  final String accountType;
  const _InsightCard({required this.balance, required this.accountType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final data     = _typeData[accountType]!;
    final color    = _typeColors[accountType]!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Icon(Iconsax.chart_2, size: 15, color: color)),
            ),
            const SizedBox(width: 10),
            Text('Proyección de esta cuenta',
                style: _T.label(13, w: FontWeight.w700, c: onSurf)),
          ]),
          const SizedBox(height: 16),

          // Dos métricas lado a lado
          Row(children: [
            Container(
                width: 0.5, height: 40,
                color: onSurf.withOpacity(0.08)),
          ]),

          // Tip del tipo — una línea concisa
          const SizedBox(height: 14),
          Text(data.tip,
              style: _T.label(12,
                  c: onSurf.withOpacity(0.45),
                  w: FontWeight.w400)),
        ],
      ),
    );
  }

  String _formatCOP(double value) {
    if (value >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(0)}K';
    }
    return '\$${value.toStringAsFixed(0)}';
  }
}

class _InsightMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  final TextAlign align;
  const _InsightMetric({
    required this.label,
    required this.value,
    required this.color,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: align == TextAlign.left
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Text(label,
              textAlign: align,
              style: _T.label(10,
                  c: onSurf.withOpacity(0.38))),
          const SizedBox(height: 4),
          Text(value,
              textAlign: align,
              style: _T.mono(16, c: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUGERENCIAS — chips rápidos
// ─────────────────────────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  final void Function(String name, String type) onTap;
  const _Suggestions({required this.onTap});

  static const _items = <(String, String)>[
    ('Billetera Digital', 'Efectivo'),
    ('Banco Principal',   'Cuenta Bancaria'),
    ('Tarjeta Platino',   'Tarjeta de Crédito'),
    ('Fondo Emergencia',  'Ahorros'),
    ('Portafolio Growth', 'Inversión'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _items.map((item) => _SuggestionPill(
        label: item.$1,
        onTap: () => onTap(item.$1, item.$2),
      )).toList(),
    );
  }
}

class _SuggestionPill extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionPill({required this.label, required this.onTap});
  @override State<_SuggestionPill> createState() => _SuggestionPillState();
}

class _SuggestionPillState extends State<_SuggestionPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);

    return GestureDetector(
      onTapDown: (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.94, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Iconsax.flash_1, size: 12,
                  color: _kBlue),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: _T.label(12,
                      c: onSurf, w: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT TILE — alerta de interés de tarjeta
// ─────────────────────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;
  const _AlertTile({
    required this.color, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: _T.label(12,
                c: onSurf.withOpacity(0.70),
                w: FontWeight.w400))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE BUTTON — sticky bottom
// ─────────────────────────────────────────────────────────────────────────────

class _SaveBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SaveBtn({required this.loading, required this.onTap});
  @override State<_SaveBtn> createState() => _SaveBtnState();
}

class _SaveBtnState extends State<_SaveBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: theme.scaffoldBackgroundColor.withOpacity(0.93),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          child: GestureDetector(
            onTapDown: (_) {
              if (!widget.loading) {
                _c.forward(); HapticFeedback.mediumImpact();
              }
            },
            onTapUp: (_) {
              _c.reverse();
              if (!widget.loading) widget.onTap();
            },
            onTapCancel: () => _c.reverse(),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Transform.scale(
                scale: lerpDouble(1.0, 0.97, _c.value)!,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    color: widget.loading
                        ? _kBlue.withOpacity(0.55) : _kBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : Text('Crear cuenta',
                            style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT FIELD — mismo patrón que el resto de la app
// ─────────────────────────────────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool noBg;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.noBg = false,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  final _focus = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() =>
        setState(() => _hasFocus = _focus.hasFocus));
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final field = TextFormField(
      controller:      widget.controller,
      focusNode:       _focus,
      keyboardType:    widget.keyboardType,
      textInputAction: widget.textInputAction,
      style: GoogleFonts.dmSans(
          fontSize: 15, fontWeight: FontWeight.w500, color: onSurf),
      decoration: InputDecoration(
        labelText:  widget.label,
        hintText:   widget.hint,
        labelStyle: GoogleFonts.dmSans(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: _hasFocus ? _kBlue : onSurf.withOpacity(0.42)),
        hintStyle: GoogleFonts.dmSans(
            fontSize: 14, color: onSurf.withOpacity(0.25)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(widget.icon, size: 17,
              color: _hasFocus
                  ? _kBlue.withOpacity(0.80)
                  : onSurf.withOpacity(0.35)),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
        border:              InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        errorStyle: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kRed),
        errorBorder:        InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      validator: widget.validator,
    );

    if (widget.noBg) return field;

    // Con fondo propio (fuera de _FieldGroup)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: _hasFocus
            ? Border.all(color: _kBlue.withOpacity(0.60), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: field,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD GROUP — patrón iOS Settings (campos agrupados, sin borde individual)
// ─────────────────────────────────────────────────────────────────────────────

class _FieldGroup extends StatelessWidget {
  final List<Widget> children;
  const _FieldGroup({required this.children});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    return Container(
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _FieldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 44 + 28),
      child: Container(height: 0.5, color: onSurf.withOpacity(0.08)),
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Container(
        width: 0.5, height: 56,
        color: onSurf.withOpacity(0.08));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: _T.label(11,
            w: FontWeight.w700, c: onSurf.withOpacity(0.35)));
  }
}

class _BackBtn extends StatefulWidget {
  @override State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); Navigator.of(context).pop(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _kBlue),
          ),
        ),
      ),
    );
  }
}