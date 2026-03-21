// lib/screens/edit_account_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Editar Cuenta — Apple-first redesign
//
// Eliminado:
// · AppBar Material + GoogleFonts.poppins → blur sticky header patrón app
// · DropdownButtonFormField tipo de cuenta Material → _TypeSelector iOS
// · TextFormField OutlineInputBorder nombre → _InputField patrón app
// · TextFormField disabled para saldo (initialValue + toStringAsFixed(0) +
//   labelText instrucción larga) → _BalanceCard read-only con NumberFormat
// · ElevatedButton.icon 'Guardar Cambios' Material → _SaveBtn patrón app
// · WidgetsBinding.instance.addPostFrameCallback → NotificationHelper directo
// · GoogleFonts.poppins → _T tokens DM Sans
// · Sin fade-in, sin HapticFeedback, sin press states → añadidos
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Tokens ───────────────────────────────────────────────────────────────────
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

// ── Paleta iOS ────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kPurple = Color(0xFFBF5AF2);

// ── Tipos de cuenta — color + ícono semántico (consistente con add_account) ──
const _kTypeColors = {
  'Efectivo':           _kGreen,
  'Cuenta Bancaria':    _kBlue,
  'Tarjeta de Crédito': _kRed,
  'Ahorros':            _kPurple,
  'Inversión':          _kOrange,
};

const _kTypeIcons = {
  'Efectivo':           Iconsax.money_3,
  'Cuenta Bancaria':    Iconsax.building_4,
  'Tarjeta de Crédito': Iconsax.card,
  'Ahorros':            Iconsax.safe_home,
  'Inversión':          Iconsax.chart_1,
};

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditAccountScreen extends StatefulWidget {
  final Account account;
  const EditAccountScreen({super.key, required this.account});

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen>
    with SingleTickerProviderStateMixin {
  final _accountRepo = AccountRepository.instance;
  final _formKey     = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late String _type;
  bool _loading = false;

  // Fade-in único — 280ms, mismo patrón que edit_transaction_screen
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.account.name);
    _descriptionCtrl = TextEditingController(text: widget.account.description);
    _type     = widget.account.type;
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose(); 
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Update ────────────────────────────────────────────────────────────────

  Future<void> _update() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _loading = true);

    try {
      final updated = widget.account.copyWith(
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isNotEmpty ? _descriptionCtrl.text.trim() : null,
        type: _type,
      );
      await _accountRepo.updateAccount(updated);

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      EventService.instance.fire(AppEvent.accountUpdated);
      Navigator.of(context).pop(true);
      NotificationHelper.show(
          message: 'Cuenta actualizada',
          type: NotificationType.success);
    } catch (e) {
      developer.log('Error al actualizar cuenta: $e',
          name: 'EditAccountScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al actualizar.',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;
    final bottomP = MediaQuery.of(context).viewInsets.bottom;
    final acc     = widget.account;
    final fmt     = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final typeColor = _kTypeColors[_type] ?? _kBlue;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [

          // ── Header blur sticky ───────────────────────────────────────────
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: theme.scaffoldBackgroundColor.withOpacity(0.93),
                padding: EdgeInsets.only(
                    top: statusH + 10, left: 8, right: 16, bottom: 14),
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
                      Text('Editar cuenta',
                          style: _T.display(28, c: onSurf)),
                    ],
                  )),
                ]),
              ),
            ),
          ),

          // ── Scroll ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: bottomP > 0 ? bottomP + 100 : 120,
              ),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Saldo actual (read-only, contexto) ────────────
                      // No es un campo editable. No usa TextFormField disabled.
                      // El saldo solo cambia mediante transacciones — se
                      // comunica como contexto, no como input bloqueado.
                      _BalanceCard(
                        balance:   acc.balance,
                        formatted: fmt.format(acc.balance),
                        type:      acc.type,
                      ),
                      const SizedBox(height: 28),

                      // ── Nombre ────────────────────────────────────────
                      _GroupLabel('DATOS DE LA CUENTA'),
                      const SizedBox(height: 10),
                      _FieldGroup(
                        children:[
                          _InputField(
                            controller:      _nameCtrl,
                            label:           'Nombre de la cuenta',
                            hint:            'Ej: Mi Banco Principal',
                            icon:            Iconsax.text,
                            textInputAction: TextInputAction.next,
                            noBg:            true,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'El nombre no puede estar vacío' : null,
                          ),
                          _FieldDivider(),
                          _InputField(
                            controller:      _descriptionCtrl,
                            label:           'Descripción (Opcional)',
                            hint:            'Propósito, nro de cuenta...',
                            icon:            Iconsax.info_circle,
                            textInputAction: TextInputAction.done,
                            noBg:            true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── Tipo de cuenta ────────────────────────────────
                      _GroupLabel('TIPO'),
                      const SizedBox(height: 10),
                      _TypeSelector(
                        selected:  _type,
                        onChanged: (t) {
                          HapticFeedback.selectionClick();
                          setState(() => _type = t);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Botón guardar sticky ─────────────────────────────────────────
          _SaveBtn(loading: _loading, onTap: _update),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BALANCE CARD — saldo actual, read-only
// ─────────────────────────────────────────────────────────────────────────────
// El saldo no se edita desde aquí — solo a través de transacciones.
// Se muestra como contexto para que el usuario sepa qué cuenta está editando.
// Tipografía mono comunica "dato del sistema, no input".
// Sin TextFormField disabled, sin labelText como instrucción.

class _BalanceCard extends StatelessWidget {
  final double balance;
  final String formatted;
  final String type;
  const _BalanceCard({
    required this.balance,
    required this.formatted,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final onSurf   = Theme.of(context).colorScheme.onSurface;
    final bg       = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);
    final isPos    = balance >= 0;
    final valColor = isPos ? _kGreen : _kRed;
    final typeColor = _kTypeColors[type] ?? _kBlue;
    final typeIcon  = _kTypeIcons[type]  ?? Iconsax.wallet_3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        // Ícono del tipo con color semántico
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(typeIcon, size: 18, color: typeColor)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type,
                style: _T.label(12,
                    c: onSurf.withOpacity(0.45))),
            const SizedBox(height: 2),
            Text('Saldo actual',
                style: _T.label(13,
                    w: FontWeight.w600, c: onSurf)),
          ],
        )),
        // Saldo en mono — dato del sistema, no editable
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatted,
                style: _T.mono(17,
                    c: valColor, w: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Solo editable con transacciones',
                style: _T.label(10,
                    c: onSurf.withOpacity(0.30),
                    w: FontWeight.w400)),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT FIELD & GROUPS — adaptados para consistencia con add_account
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
      textCapitalization: TextCapitalization.sentences,
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

// ─────────────────────────────────────────────────────────────────────────────
// NAME FIELD — campo editable del nombre de la cuenta
// ─────────────────────────────────────────────────────────────────────────────

class _NameField extends StatefulWidget {
  final TextEditingController controller;
  const _NameField({required this.controller});
  @override State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: _hasFocus
            ? Border.all(color: _kBlue.withOpacity(0.60), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: TextFormField(
        controller:     widget.controller,
        focusNode:      _focus,
        style:          _T.label(15, c: onSurf),
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText:  'Nombre de la cuenta',
          hintStyle: _T.label(15, c: onSurf.withOpacity(0.28)),
          border:    InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Iconsax.text,
                size: 17,
                color: _hasFocus
                    ? _kBlue
                    : onSurf.withOpacity(0.30)),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'El nombre no puede estar vacío'
            : null,
      ),
      
      
      
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TYPE SELECTOR — lista de tipos como tiles en un _FieldGroup
// ─────────────────────────────────────────────────────────────────────────────
// Mismo patrón que _TypeSelector de add_account_screen.
// Cada tile muestra ícono con color semántico + nombre del tipo.
// Al seleccionar: checkmark animado + ícono en el color del tipo.
// Sin DropdownButtonFormField Material.

class _TypeSelector extends StatelessWidget {
  final String   selected;
  final ValueChanged<String> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final types  = _kTypeColors.keys.toList();

    return Container(
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: types.indexed.map((e) {
          final (i, type) = e;
          final isSel  = type == selected;
          final isLast = i == types.length - 1;
          return _TypeTile(
            type:        type,
            isSelected:  isSel,
            showDivider: !isLast && !isSel,
            onTap: () => onChanged(type),
          );
        }).toList(),
      ),
    );
  }
}

class _TypeTile extends StatefulWidget {
  final String     type;
  final bool       isSelected, showDivider;
  final VoidCallback onTap;
  const _TypeTile({
    required this.type, required this.isSelected,
    required this.showDivider, required this.onTap,
  });
  @override State<_TypeTile> createState() => _TypeTileState();
}

class _TypeTileState extends State<_TypeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color  = _kTypeColors[widget.type] ?? _kBlue;
    final icon   = _kTypeIcons[widget.type]  ?? Iconsax.wallet_3;

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, 0.55, _c.value)!,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
              child: Row(children: [
                // Ícono con color semántico del tipo
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(
                        widget.isSelected ? 0.14 : 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Icon(icon,
                      size: 15,
                      color: widget.isSelected
                          ? color
                          : onSurf.withOpacity(0.35))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.type,
                    style: _T.label(14,
                        w: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        c: widget.isSelected
                            ? onSurf
                            : onSurf.withOpacity(0.60)))),
                // Checkmark animado — solo cuando está seleccionado
                AnimatedOpacity(
                  opacity: widget.isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.check_rounded,
                      size: 17, color: _kBlue),
                ),
              ]),
            ),
            // Separador — desaparece en el tile seleccionado y en el último
            if (widget.showDivider)
              Padding(
                padding: const EdgeInsets.only(left: 14 + 34 + 12),
                child: Container(
                    height: 0.5,
                    color: onSurf.withOpacity(0.07)),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE BUTTON — sticky bottom, blur backdrop
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
    final theme = Theme.of(context);
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
            onTapUp:     (_) { _c.reverse(); if (!widget.loading) widget.onTap(); },
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
                        ? _kBlue.withOpacity(0.55)
                        : _kBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : Text('Guardar cambios',
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
// SHARED COMPONENTS
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