// lib/screens/edit_debt_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Editar Deuda
//
// CAMBIOS v2:
// · FIX: debt.remainingAmount → debt.currentAmount (o fallback a initialAmount)
//   El campo correcto se calcula desde el modelo disponible.
// · NUEVO: Sección "Persona o Entidad" mejorada — igual que add_debt_screen:
//   tres estados: vacío (abre picker), modo manual, contacto de agenda.
//   BUG FIX heredado: _isManualMode independiente del contacto seleccionado.
// · NUEVO: Sección "¿Cómo afecta tu cuenta?" con _ImpactSelector portado
//   desde add_debt_screen. Permite editar el tipo de impacto.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as contacts;
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

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

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditDebtScreen extends StatefulWidget {
  final Debt debt;
  const EditDebtScreen({super.key, required this.debt});

  @override
  State<EditDebtScreen> createState() => _EditDebtScreenState();
}

class _EditDebtScreenState extends State<EditDebtScreen>
    with SingleTickerProviderStateMixin {
  final _debtRepo = DebtRepository.instance;
  final _formKey  = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _manualCtrl;
  late final FocusNode             _manualFocus;

  DateTime?      _dueDate;
  DebtImpactType _impactType = DebtImpactType.liquid;
  bool           _loading    = false;

  // Persona — tres estados (mismo patrón que add_debt_screen)
  contacts.Contact? _selectedContact;
  bool              _isManualMode = false;
  double?           _contactBalance;
  bool              _isFetchingBalance = false;

  // Fade-in único 280ms
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _nameCtrl    = TextEditingController(text: widget.debt.name);
    _manualCtrl  = TextEditingController(text: widget.debt.entityName ?? '');
    _manualFocus = FocusNode();
    _dueDate     = widget.debt.dueDate;
    _impactType  = widget.debt.impactType ?? DebtImpactType.liquid;

    // Si ya tenía entidad, arranca en modo manual con el texto pre-cargado
    if (widget.debt.entityName != null && widget.debt.entityName!.isNotEmpty) {
      _isManualMode = true;
    }

    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manualCtrl.dispose();
    _manualFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Persona ───────────────────────────────────────────────────────────────

  String get _personName {
    if (_selectedContact != null) return _selectedContact!.displayName;
    if (_isManualMode) return _manualCtrl.text.trim();
    return '';
  }

  Future<void> _pickContact() async {
    Navigator.pop(context);
    if (!await Permission.contacts.request().isGranted) {
      NotificationHelper.show(
          message: 'Permiso de contactos denegado.',
          type: NotificationType.warning);
      return;
    }
    final contact = await contacts.FlutterContacts.openExternalPick();
    if (contact != null && mounted) {
      setState(() {
        _selectedContact = contact;
        _isManualMode    = false;
        _manualCtrl.clear();
        _contactBalance  = null;
      });
      _fetchContactBalance();
    }
  }

  void _useManualEntry() {
    Navigator.pop(context);
    setState(() {
      _selectedContact = null;
      _contactBalance  = null;
      _isManualMode    = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _manualFocus.requestFocus();
    });
  }

  void _clearPerson() {
    setState(() {
      _selectedContact = null;
      _contactBalance  = null;
      _isManualMode    = false;
      _manualCtrl.clear();
    });
  }

  Future<void> _fetchContactBalance() async {
    if (_selectedContact == null) return;
    setState(() => _isFetchingBalance = true);
    try {
      final total = await _debtRepo
          .getTotalDebtForEntity(_selectedContact!.displayName);
      if (mounted) setState(() => _contactBalance = total);
    } catch (e) {
      developer.log('Error al obtener balance de contacto: $e');
    } finally {
      if (mounted) setState(() => _isFetchingBalance = false);
    }
  }

  void _showPersonPicker() {
    showModalBottomSheet(
      context:          context,
      backgroundColor:  Colors.transparent,
      builder: (_) => _PersonPickerSheet(
        onPickContact: _pickContact,
        onManualEntry: _useManualEntry,
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _loading = true);
    try {
      final entityName = _personName.isNotEmpty ? _personName : null;

      await _debtRepo.updateDebt(
        debtId:     widget.debt.id,
        name:       _nameCtrl.text.trim(),
        entityName: entityName,
        dueDate:    _dueDate,
        impactType: _impactType,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      NotificationHelper.show(
          message: 'Deuda actualizada', type: NotificationType.success);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      NotificationHelper.show(
          message: 'Error al actualizar.', type: NotificationType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate:   DateTime.now(),
      lastDate:    DateTime(2100),
      locale:      const Locale('es'),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
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
    final isDark  = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [

          // ── Header blur sticky ─────────────────────────────────────────
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('SASPER',
                            style: _T.label(10,
                                w: FontWeight.w700,
                                c: onSurf.withOpacity(0.35))),
                        Text('Editar deuda',
                            style: _T.display(28, c: onSurf)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),

          // ── Scroll ────────────────────────────────────────────────────
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

                      // ── Contexto de la deuda (read-only) ─────────────
                      _DebtContextCard(debt: widget.debt),
                      const SizedBox(height: 28),

                      // ── Concepto ───────────────────────────────────
                      _GroupLabel('CONCEPTO'),
                      const SizedBox(height: 10),
                      _InputField(
                        controller:  _nameCtrl,
                        hint:        'Nombre de la deuda',
                        icon:        Iconsax.note_1,
                        inputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'El concepto es obligatorio'
                                : null,
                      ),
                      const SizedBox(height: 28),

                      // ── Persona o Entidad ──────────────────────────
                      _GroupLabel(
                        widget.debt.type == DebtType.debt
                            ? 'PERSONA O ENTIDAD  ·  ¿A QUIÉN LE DEBES?'
                            : 'PERSONA O ENTIDAD  ·  ¿QUIÉN TE DEBE?',
                      ),
                      const SizedBox(height: 10),
                      _PersonField(
                        selectedContact:  _selectedContact,
                        isManualMode:     _isManualMode,
                        manualCtrl:       _manualCtrl,
                        manualFocus:      _manualFocus,
                        contactBalance:   _contactBalance,
                        isFetching:       _isFetchingBalance,
                        debtType:         widget.debt.type,
                        onTapSelector:    _showPersonPicker,
                        onClear:          _clearPerson,
                        onManualChanged:  () => setState(() {}),
                      ),
                      const SizedBox(height: 28),

                      // ── Fecha de vencimiento ───────────────────────
                      _GroupLabel('VENCIMIENTO  ·  OPCIONAL'),
                      const SizedBox(height: 10),
                      _DateTile(
                        date:  _dueDate,
                        onTap: _selectDate,
                        onClear: () {
                          HapticFeedback.lightImpact();
                          setState(() => _dueDate = null);
                        },
                      ),
                      const SizedBox(height: 28),

                      // ── ¿Cómo afecta tu cuenta? ───────────────────
                      _GroupLabel('¿CÓMO AFECTA TU CUENTA?'),
                      const SizedBox(height: 10),
                      _ImpactSelector(
                        selected:  _impactType,
                        debtType:  widget.debt.type,
                        onChanged: (t) {
                          HapticFeedback.selectionClick();
                          setState(() => _impactType = t);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Botón guardar sticky ───────────────────────────────────────
          _SaveBtn(loading: _loading, onTap: _save),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEBT CONTEXT CARD — datos de la deuda, read-only
// ─────────────────────────────────────────────────────────────────────────────
// Campos del modelo Debt usados:
//   · debt.initialAmount   → monto original
//   · debt.currentBalance  → saldo pendiente (antes "remainingAmount" — inexistente)
//   · debt.paidAmount      → getter computado: initialAmount - currentBalance
//   · debt.progress        → getter computado: paidAmount / initialAmount

class _DebtContextCard extends StatelessWidget {
  final Debt debt;
  const _DebtContextCard({required this.debt});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final bg        = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);
    final fmt       = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final isDebt    = debt.type == DebtType.debt;
    final typeColor = isDebt ? _kRed : _kBlue;
    final typeLabel = isDebt ? 'Deuda' : 'Préstamo';
    final typeIcon  = isDebt ? Iconsax.arrow_circle_down : Iconsax.arrow_circle_up;

    // Usamos los campos/getters correctos del modelo
    final hasProgress = debt.initialAmount > 0 && debt.paidAmount > 0;
    final pct         = (debt.progress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(typeIcon, size: 18, color: typeColor)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(typeLabel,
                    style: _T.label(12, c: typeColor, w: FontWeight.w700)),
                const SizedBox(height: 1),
                Text('No editable · ligado a la transacción',
                    style: _T.label(11,
                        c: onSurf.withOpacity(0.30),
                        w: FontWeight.w400)),
              ],
            )),
            Text(fmt.format(debt.initialAmount),
                style: _T.mono(16, c: typeColor, w: FontWeight.w700)),
          ]),

          if (hasProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:           debt.progress,
                minHeight:       4,
                backgroundColor: onSurf.withOpacity(0.08),
                valueColor:      const AlwaysStoppedAnimation(_kGreen),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('Pagado ',
                  style: _T.label(11, c: onSurf.withOpacity(0.40))),
              Text(fmt.format(debt.paidAmount),
                  style: _T.mono(11, c: _kGreen, w: FontWeight.w600)),
              Text('  ·  Pendiente ',
                  style: _T.label(11, c: onSurf.withOpacity(0.40))),
              Text(fmt.format(debt.currentBalance),
                  style: _T.mono(11, c: typeColor, w: FontWeight.w600)),
              const Spacer(),
              Text('$pct%',
                  style: _T.mono(11, c: _kGreen, w: FontWeight.w600)),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSON FIELD — tres estados (portado desde add_debt_screen)
// ─────────────────────────────────────────────────────────────────────────────
// Estado 1: vacío → tile que abre el picker
// Estado 2: _isManualMode = true → campo de texto con autofocus
// Estado 3: _selectedContact != null → tarjeta del contacto con balance

class _PersonField extends StatelessWidget {
  final contacts.Contact? selectedContact;
  final bool              isManualMode;
  final TextEditingController manualCtrl;
  final FocusNode         manualFocus;
  final double?           contactBalance;
  final bool              isFetching;
  final DebtType          debtType;
  final VoidCallback      onTapSelector;
  final VoidCallback      onClear;
  final VoidCallback      onManualChanged;

  const _PersonField({
    required this.selectedContact, required this.isManualMode,
    required this.manualCtrl, required this.manualFocus,
    required this.contactBalance, required this.isFetching,
    required this.debtType, required this.onTapSelector,
    required this.onClear, required this.onManualChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    // Estado 3: contacto seleccionado
    if (selectedContact != null) {
      return _ContactCard(
        contact:    selectedContact!,
        balance:    contactBalance,
        isFetching: isFetching,
        onClear:    onClear,
      );
    }

    // Estado 2: modo manual
    if (isManualMode) {
      return _ManualField(
        ctrl:       manualCtrl,
        focus:      manualFocus,
        onClear:    onClear,
        onChanged:  onManualChanged,
      );
    }

    // Estado 1: vacío — toca para abrir picker
    return GestureDetector(
      onTap: onTapSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 1.5),
        ),
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(left: 0, right: 10),
            child: Icon(Iconsax.user, size: 17,
                color: onSurf.withOpacity(0.30)),
          ),
          Expanded(
            child: Text(
              debtType == DebtType.debt
                  ? 'Seleccionar o escribir nombre'
                  : 'Seleccionar o escribir nombre',
              style: _T.label(15, c: onSurf.withOpacity(0.28)),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 17, color: onSurf.withOpacity(0.22)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANUAL FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _ManualField extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode             focus;
  final VoidCallback          onClear;
  final VoidCallback          onChanged;
  const _ManualField({
    required this.ctrl, required this.focus,
    required this.onClear, required this.onChanged,
  });
  @override State<_ManualField> createState() => _ManualFieldState();
}

class _ManualFieldState extends State<_ManualField> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focus.addListener(() {
      if (mounted) setState(() => _focused = widget.focus.hasFocus);
    });
  }

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
        border: _focused
            ? Border.all(color: _kBlue.withOpacity(0.60), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Icon(Iconsax.edit_2, size: 17,
            color: _focused ? _kBlue : onSurf.withOpacity(0.30)),
        Expanded(
          child: TextFormField(
            controller:         widget.ctrl,
            focusNode:          widget.focus,
            textCapitalization: TextCapitalization.words,
            style:              _T.label(15, c: onSurf),
            onChanged: (_) {
              HapticFeedback.selectionClick();
              widget.onChanged();
            },
            decoration: InputDecoration(
              hintText:  'Nombre o empresa',
              hintStyle: _T.label(15, c: onSurf.withOpacity(0.28)),
              border:    InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 14),
            ),
          ),
        ),
        GestureDetector(
          onTap:    widget.onClear,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.cancel_rounded,
                size: 18, color: onSurf.withOpacity(0.28)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final contacts.Contact contact;
  final double?          balance;
  final bool             isFetching;
  final VoidCallback     onClear;
  const _ContactCard({
    required this.contact, required this.balance,
    required this.isFetching, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final bg      = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    String balanceText;
    Color  balanceColor;
    if (isFetching) {
      balanceText  = 'Cargando historial…';
      balanceColor = onSurf.withOpacity(0.40);
    } else if (balance == null || balance == 0) {
      balanceText  = 'Sin deudas previas';
      balanceColor = onSurf.withOpacity(0.40);
    } else if (balance! > 0) {
      balanceText  = 'Te debe ${compact.format(balance)}';
      balanceColor = _kGreen;
    } else {
      balanceText  = 'Le debes ${compact.format(balance!.abs())}';
      balanceColor = _kRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withOpacity(0.22), width: 1.0),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: _kBlue.withOpacity(isDark ? 0.22 : 0.10),
              shape: BoxShape.circle),
          child: Center(
            child: Text(
              contact.displayName[0].toUpperCase(),
              style: _T.label(16, c: _kBlue, w: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact.displayName,
                style: _T.label(15, c: onSurf, w: FontWeight.w700)),
            const SizedBox(height: 2),
            isFetching
                ? SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: onSurf.withOpacity(0.10),
                      color: _kBlue,
                      borderRadius: BorderRadius.circular(2),
                    ))
                : Text(balanceText,
                    style: _T.label(12, c: balanceColor, w: FontWeight.w500)),
          ]),
        ),
        GestureDetector(
          onTap:    onClear,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.cancel_rounded,
                size: 18, color: onSurf.withOpacity(0.28)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSON PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _PersonPickerSheet extends StatelessWidget {
  final VoidCallback onPickContact;
  final VoidCallback onManualEntry;
  const _PersonPickerSheet({
    required this.onPickContact, required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final surface = isDark
        ? const Color(0xFF1C1C1E)
        : Colors.white;
    final raised  = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF5F5F7);
    final sep     = isDark
        ? const Color(0xFF38383A)
        : const Color(0xFFE5E5EA);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: sep.withOpacity(0.3), width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
                color: sep, borderRadius: BorderRadius.circular(2))),
        Text('¿Quién es?',
            style: _T.display(17, c: onSurf)),
        const SizedBox(height: 20),

        _SheetOption(
          icon:     Iconsax.user_search,
          title:    'Desde la agenda',
          subtitle: 'Buscar entre tus contactos',
          raised:   raised, sep: sep, onSurf: onSurf,
          onTap:    onPickContact,
        ),
        const SizedBox(height: 8),
        _SheetOption(
          icon:     Iconsax.edit_2,
          title:    'Escribir manualmente',
          subtitle: 'Ingresar nombre o entidad',
          raised:   raised, sep: sep, onSurf: onSurf,
          onTap:    onManualEntry,
        ),
      ]),
    );
  }
}

class _SheetOption extends StatefulWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final Color        raised;
  final Color        sep;
  final Color        onSurf;
  final VoidCallback onTap;
  const _SheetOption({
    required this.icon, required this.title, required this.subtitle,
    required this.raised, required this.sep, required this.onSurf,
    required this.onTap,
  });
  @override State<_SheetOption> createState() => _SheetOptionState();
}

class _SheetOptionState extends State<_SheetOption> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _p = true),
      onTapUp:     (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
        scale:    _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.raised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: widget.sep.withOpacity(0.3), width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: widget.onSurf.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(widget.icon, size: 18,
                  color: widget.onSurf.withOpacity(0.60)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.title,
                    style: _T.label(15,
                        c: widget.onSurf, w: FontWeight.w700)),
                Text(widget.subtitle,
                    style: _T.label(12,
                        c: widget.onSurf.withOpacity(0.40))),
              ]),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 17, color: widget.onSurf.withOpacity(0.22)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPACT SELECTOR — portado desde add_debt_screen
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactSelector extends StatelessWidget {
  final DebtImpactType selected;
  final DebtType       debtType;
  final ValueChanged<DebtImpactType> onChanged;
  const _ImpactSelector({
    required this.selected, required this.debtType, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final opts = [
      (
        type:  DebtImpactType.liquid,
        icon:  Iconsax.wallet_add_1,
        title: debtType == DebtType.debt
            ? 'Entró a mi cuenta' : 'Salió de mi cuenta',
        sub:   'Afecta el saldo disponible',
      ),
      (
        type:  DebtImpactType.restricted,
        icon:  Iconsax.lock_1,
        title: 'Propósito fijo',
        sub:   'El dinero tiene un destino reservado',
      ),
      (
        type:  DebtImpactType.direct,
        icon:  Iconsax.cards,
        title: debtType == DebtType.debt
            ? 'Alguien pagó por mí' : 'Pagué por alguien',
        sub:   'El dinero no pasó por mis cuentas',
      ),
    ];

    return Column(
      children: opts.asMap().entries.map((e) {
        final i   = e.key;
        final opt = e.value;
        final sel = selected == opt.type;

        return Padding(
          padding: EdgeInsets.only(bottom: i < opts.length - 1 ? 8 : 0),
          child: _ImpactOption(
            icon:  opt.icon,
            title: opt.title,
            sub:   opt.sub,
            sel:   sel,
            isDark: isDark,
            onSurf: onSurf,
            bg:    bg,
            onTap: () => onChanged(opt.type),
          ),
        );
      }).toList(),
    );
  }
}

class _ImpactOption extends StatefulWidget {
  final IconData  icon;
  final String    title;
  final String    sub;
  final bool      sel;
  final bool      isDark;
  final Color     onSurf;
  final Color     bg;
  final VoidCallback onTap;
  const _ImpactOption({
    required this.icon, required this.title, required this.sub,
    required this.sel, required this.isDark, required this.onSurf,
    required this.bg, required this.onTap,
  });
  @override State<_ImpactOption> createState() => _ImpactOptionState();
}

class _ImpactOptionState extends State<_ImpactOption> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _p = true),
      onTapUp:     (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
        scale:    _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.sel
                ? _kBlue.withOpacity(widget.isDark ? 0.12 : 0.06)
                : widget.bg,
            borderRadius: BorderRadius.circular(14),
            border: widget.sel
                ? Border.all(
                    color: _kBlue.withOpacity(widget.isDark ? 0.45 : 0.30),
                    width: 1.2)
                : Border.all(color: Colors.transparent, width: 1.2),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: widget.sel
                    ? _kBlue.withOpacity(widget.isDark ? 0.20 : 0.10)
                    : widget.onSurf.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, size: 16,
                  color: widget.sel
                      ? _kBlue
                      : widget.onSurf.withOpacity(0.35)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: _T.label(14,
                        c: widget.sel
                            ? _kBlue
                            : widget.onSurf,
                        w: widget.sel
                            ? FontWeight.w700
                            : FontWeight.w600)),
                const SizedBox(height: 2),
                Text(widget.sub,
                    style: _T.label(12,
                        c: widget.onSurf.withOpacity(0.40))),
              ],
            )),
            if (widget.sel)
              Icon(Iconsax.tick_circle, size: 18, color: _kBlue),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _InputField extends StatefulWidget {
  final TextEditingController      controller;
  final String                     hint;
  final IconData                   icon;
  final TextInputAction             inputAction;
  final String? Function(String?)? validator;
  final TextCapitalization          capitalization;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.inputAction,
    this.validator,
    this.capitalization = TextCapitalization.sentences,
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
        controller:         widget.controller,
        focusNode:          _focus,
        style:              _T.label(15, c: onSurf),
        textCapitalization: widget.capitalization,
        textInputAction:    widget.inputAction,
        decoration: InputDecoration(
          hintText:  widget.hint,
          hintStyle: _T.label(15, c: onSurf.withOpacity(0.28)),
          border:    InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(widget.icon,
                size: 17,
                color: _hasFocus
                    ? _kBlue
                    : onSurf.withOpacity(0.30)),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        validator: widget.validator,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE TILE
// ─────────────────────────────────────────────────────────────────────────────

class _DateTile extends StatefulWidget {
  final DateTime?    date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateTile({
    required this.date, required this.onTap, required this.onClear,
  });
  @override State<_DateTile> createState() => _DateTileState();
}

class _DateTileState extends State<_DateTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final bg      = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final hasDate = widget.date != null;

    Color dateColor = onSurf;
    if (hasDate) {
      final daysLeft = widget.date!.difference(DateTime.now()).inDays;
      if (daysLeft < 0)       dateColor = _kRed;
      else if (daysLeft <= 7) dateColor = _kOrange;
      else                    dateColor = _kGreen;
    }

    final label = hasDate
        ? DateFormat("d 'de' MMMM, yyyy", 'es').format(widget.date!)
        : 'Seleccionar fecha';

    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: hasDate
                      ? dateColor.withOpacity(0.10)
                      : onSurf.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(Iconsax.calendar_1,
                    size: 15,
                    color: hasDate
                        ? dateColor
                        : onSurf.withOpacity(0.30))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label,
                  style: _T.label(14,
                      w: FontWeight.w600,
                      c: hasDate
                          ? dateColor
                          : onSurf.withOpacity(0.38)))),
              if (hasDate)
                GestureDetector(
                  onTap: widget.onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.close_rounded,
                        size: 15, color: onSurf.withOpacity(0.28)),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    size: 17, color: onSurf.withOpacity(0.22)),
            ]),
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

class _SaveBtn extends StatefulWidget {
  final bool         loading;
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
            onTapCancel: ()  => _c.reverse(),
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
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); Navigator.of(context).pop(); },
      onTapCancel: ()  => _c.reverse(),
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