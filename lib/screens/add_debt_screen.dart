// lib/screens/add_debt_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA — Apple iOS / Contacts + Wallet                                 │
// │                                                                             │
// │  Registrar una deuda o préstamo es un acto de confianza.                  │
// │  La pantalla debe sentirse tan natural como anotar algo en tu agenda.      │
// │                                                                             │
// │  JERARQUÍA:                                                                │
// │  1. Tipo (Yo Debo / Me Deben) — segmented control iOS. Primera decisión.  │
// │     El color del acento cambia con él: rojo para deudas, verde para       │
// │     préstamos. Es el ÚNICO cambio cromático de toda la pantalla.          │
// │  2. Persona — quién. Avatar + nombre o campo manual si no está en agenda. │
// │  3. Concepto — para qué. Texto libre.                                     │
// │  4. Monto — cuánto. Grande, protagonista.                                 │
// │  5. Cuenta y fecha — detalles en dos tiles compactos.                     │
// │  6. ¿Cómo afecta? — tres opciones de impacto. Claras, sin ambigüedad.    │
// │  7. Impact card — aparece solo cuando hay monto + cuenta. Cálculo real.   │
// │  8. Botón confirmar — único CTA.                                           │
// │                                                                             │
// │  BUG FIX — "Escribir manualmente" no hacía nada:                          │
// │  El widget _ContactSelectorPremium original mostraba el campo manual       │
// │  solo cuando selectedContact != null — exactamente el caso contrario.     │
// │  Solución: bool _isManualMode independiente del contacto.                  │
// │  Cuando _isManualMode = true, el campo de texto aparece en pantalla,       │
// │  enfocado automáticamente, sin necesidad de ningún contacto seleccionado. │
// │                                                                             │
// │  ELIMINADO vs original:                                                    │
// │  • Fondo con gradiente animado rojo/verde → distracción permanente        │
// │  • Header expandible 200px con ícono que escala en bucle → innecesario    │
// │  • BackdropFilter blur en hero card → coste de render sin propósito       │
// │  • Section labels en accentColor bold compitiendo en cada sección         │
// │  • .animate().fadeIn().slideY() encadenados en impactCard → exceso        │
// │  • .animate(target:).scale() en cada opción de impacto → 3 anim. a la vez│
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as contacts;
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

// ─── TOKENS ──────────────────────────────────────────────────────────────────
class _C {
  final BuildContext ctx;
  _C(this.ctx);

  bool get isDark => Theme.of(ctx).brightness == Brightness.dark;

  Color get bg      => isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get surface => isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get raised  => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get sep     => isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  Color get label  => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  Color get label2 => isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color get label3 => isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get label4 => isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  static const Color red    = Color(0xFFFF3B30);
  static const Color green  = Color(0xFF30D158);
  static const Color orange = Color(0xFFFF9F0A);
  static const Color blue   = Color(0xFF0A84FF);
  static const Color purple = Color(0xFFBF5AF2);

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double rSM  = 8.0;
  static const double rMD  = 12.0;
  static const double rLG  = 16.0;
  static const double rXL  = 22.0;
  static const double r2XL = 28.0;

  static const Duration fast   = Duration(milliseconds: 130);
  static const Duration mid    = Duration(milliseconds: 260);
  static const Duration slow   = Duration(milliseconds: 440);
  static const Curve   easeOut = Curves.easeOutCubic;
  static const Curve   spring  = Curves.easeOutBack;
}

// ─── PANTALLA ─────────────────────────────────────────────────────────────────
class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen>
    with TickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _manualCtrl    = TextEditingController();
  final _manualFocus   = FocusNode();

  final DebtRepository    _debtRepo    = DebtRepository.instance;
  final AccountRepository _accountRepo = AccountRepository.instance;

  late ConfettiController _confettiCtrl;
  late Future<List<Account>> _accountsFuture;

  // Estado del formulario
  DebtType       _debtType    = DebtType.debt;
  DebtImpactType _impactType  = DebtImpactType.liquid;
  Account?       _account;
  DateTime?      _dueDate;
  double         _amount      = 0.0;
  bool           _isLoading   = false;
  bool           _isSuccess   = false;

  // Estado del selector de persona — BUG FIX
  // _isManualMode y _selectedContact son mutuamente excluyentes.
  // Antes el campo manual dependía de selectedContact != null (bug).
  // Ahora _isManualMode es independiente — cuando es true el campo aparece.
  contacts.Contact? _selectedContact;
  bool   _isManualMode        = false;
  double? _contactBalance;
  bool   _isFetchingBalance   = false;

  // Animación del tipo — el acento cromático cambia suavemente
  late AnimationController _typeCtrl;
  late Animation<double>   _typeAnim;   // 0 = debt (red), 1 = loan (green)

  // Animación del impact card
  late AnimationController _impactCtrl;
  late Animation<double>   _impactAnim;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepo.getAccounts();

    _confettiCtrl = ConfettiController(
        duration: const Duration(milliseconds: 2500));

    _typeCtrl = AnimationController(duration: _C.slow, vsync: this);
    _typeAnim = CurvedAnimation(parent: _typeCtrl, curve: _C.easeOut);

    _impactCtrl = AnimationController(duration: _C.mid, vsync: this);
    _impactAnim = CurvedAnimation(parent: _impactCtrl, curve: _C.easeOut);

    _accountsFuture.then((accounts) {
      if (accounts.isNotEmpty && mounted) {
        setState(() => _account = accounts.first);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manualCtrl.dispose();
    _manualFocus.dispose();
    _confettiCtrl.dispose();
    _typeCtrl.dispose();
    _impactCtrl.dispose();
    super.dispose();
  }

  // ── Acento dinámico ───────────────────────────────────────────────────────
  // El color interpola entre rojo y verde según el tipo.
  // Es el único eje cromático de la pantalla.
  Color _accentAt(double t) =>
      Color.lerp(const Color(0xFFFF3B30), const Color(0xFF30D158), t)!;

  // ── Cambio de tipo ────────────────────────────────────────────────────────
  void _setDebtType(DebtType t) {
    if (t == _debtType) return;
    HapticFeedback.selectionClick();
    setState(() => _debtType = t);
    if (t == DebtType.loan) {
      _typeCtrl.forward();
    } else {
      _typeCtrl.reverse();
    }
  }

  // ── Contactos ─────────────────────────────────────────────────────────────
  Future<void> _pickContact() async {
    Navigator.pop(context); // Cierra el bottom sheet
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

  // BUG FIX: _useManualEntry activa _isManualMode = true y hace focus
  // automático en el campo de texto. El campo existe en el árbol de widgets
  // independientemente del contacto seleccionado.
  void _useManualEntry() {
    Navigator.pop(context); // Cierra el bottom sheet
    setState(() {
      _selectedContact = null;
      _contactBalance  = null;
      _isManualMode    = true;
    });
    // Autofocus al campo manual después del frame actual
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

  // ── Monto ─────────────────────────────────────────────────────────────────
  void _onAmountChanged(double v) {
    setState(() => _amount = v);
    if (v > 0 && _account != null) {
      _impactCtrl.forward();
    } else {
      _impactCtrl.reverse();
    }
  }

  // ── Nombre de la persona ──────────────────────────────────────────────────
  String get _personName {
    if (_selectedContact != null) return _selectedContact!.displayName;
    if (_isManualMode) return _manualCtrl.text.trim();
    return '';
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
void _requestConfirm() {
    // 1. Validar formulario (Concepto)
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }
    
    // 2. Validar Cuenta seleccionada
    if (_account == null) {
      HapticFeedback.vibrate();
      NotificationHelper.show(
          message: 'Selecciona una cuenta.',
          type: NotificationType.error);
      return;
    }

    // 3. VALIDACIÓN FALTANTE: Validar Persona seleccionada
    if (_personName.isEmpty) {
      HapticFeedback.vibrate();
      NotificationHelper.show(
          message: _debtType == DebtType.debt 
              ? '¿A quién le debes?' 
              : '¿Quién te debe?',
          type: NotificationType.error);
      return;
    }

    final accent = _accentAt(_typeCtrl.value);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(
        debtType:   _debtType,
        amount:     _amount,
        concept:    _nameCtrl.text.trim(),
        personName: _personName,
        account:    _account!,
        accentColor: accent,
        c:          _C(context),
        onConfirm:  _submit,
      ),
    );
  }

Future<void> _submit() async {
    if (_isLoading || _isSuccess) return;
    
    // Cerramos el BottomSheet de confirmación
    Navigator.pop(context); 
    
    setState(() => _isLoading = true);

    try {
      // Aseguramos que entity nunca sea null aquí porque ya validamos arriba
      final entity = _personName; 

      await _debtRepo.addDebtAndInitialTransaction(
        name:            _nameCtrl.text.trim(),
        type:            _debtType, // El repo debe manejar el enum o usar .name
        entityName:      entity,
        amount:          _amount,
        accountId:       _account!.id,
        dueDate:         _dueDate,
        transactionDate: DateTime.now(),
        impactType:      _impactType,
      );

      if (mounted) {
        setState(() { _isSuccess = true; _isLoading = false; });
        HapticFeedback.mediumImpact();
        _confettiCtrl.play();
        EventService.instance.fire(AppEvent.transactionsChanged); // Notificar cambios
        
        await Future.delayed(const Duration(milliseconds: 1800));
        
        if (mounted) {
          Navigator.of(context).pop(); // Cerrar pantalla
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationHelper.show(
                message: '¡Operación registrada!',
                type: NotificationType.success);
          });
        }
      }
    } catch (e) {
      developer.log('Error al guardar deuda: $e', name: 'AddDebtScreen');
      if (mounted) {
        setState(() => _isLoading = false);
        HapticFeedback.vibrate();
        NotificationHelper.show(
            message: 'Error al guardar: Verifique los datos.', // Mensaje amigable
            type: NotificationType.error);
      }
    }
  }
  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = _C(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:     c.isDark ? Brightness.dark  : Brightness.light,
      ),
      child: Stack(children: [
        Scaffold(
          backgroundColor: c.bg,
          body: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── AppBar con tipo selector integrado ────────────────
                _buildAppBar(c),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      _C.md, _C.sm, _C.md, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Hero card — monto + persona en tiempo real ─
                      AnimatedBuilder(
                        animation: _typeAnim,
                        builder: (_, __) => _HeroCard(
                          amount:     _amount,
                          personName: _personName,
                          debtType:   _debtType,
                          accent:     _accentAt(_typeAnim.value),
                          c:          c,
                        ),
                      ),
                      const SizedBox(height: _C.lg),

                      // ── Persona ────────────────────────────────────
                      _SectionLabel(text: _debtType == DebtType.debt
                          ? '¿A quién le debes?' : '¿Quién te debe?', c: c),
                      const SizedBox(height: _C.sm),
                      AnimatedBuilder(
                        animation: _typeAnim,
                        builder: (_, __) => _PersonField(
                          selectedContact:  _selectedContact,
                          isManualMode:     _isManualMode,
                          manualCtrl:       _manualCtrl,
                          manualFocus:      _manualFocus,
                          contactBalance:   _contactBalance,
                          isFetching:       _isFetchingBalance,
                          accent:           _accentAt(_typeAnim.value),
                          debtType:         _debtType,
                          c:                c,
                          onTapSelector:    _showPersonPicker,
                          onClear:          _clearPerson,
                          onManualChanged:  () => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: _C.lg),

                      // ── Concepto ───────────────────────────────────
                      _SectionLabel(text: '¿Para qué es?', c: c),
                      const SizedBox(height: _C.sm),
                      AnimatedBuilder(
                        animation: _typeAnim,
                        builder: (_, __) => _ConceptField(
                          ctrl:   _nameCtrl,
                          hint:   _debtType == DebtType.debt
                              ? 'Ej: Préstamo para el coche'
                              : 'Ej: Dinero del viaje',
                          accent: _accentAt(_typeAnim.value),
                          c:      c,
                        ),
                      ),
                      const SizedBox(height: _C.lg),

                      // ── Monto ─────────────────────────────────────
                      _SectionLabel(text: 'Monto', c: c),
                      const SizedBox(height: _C.sm),
                      AnimatedBuilder(
                        animation: _typeAnim,
                        builder: (_, __) => _AmountInput(
                          accent:    _accentAt(_typeAnim.value),
                          c:         c,
                          onChanged: _onAmountChanged,
                        ),
                      ),
                      const SizedBox(height: _C.lg),

                      // ── Cuenta y fecha ────────────────────────────
                      _SectionLabel(text: 'Detalles', c: c),
                      const SizedBox(height: _C.sm),
                      AnimatedBuilder(
                        animation: _typeAnim,
                        builder: (_, __) {
                          final accent = _accentAt(_typeAnim.value);
                          return Column(children: [
                            FutureBuilder<List<Account>>(
                              future: _accountsFuture,
                              builder: (_, snap) {
                                if (!snap.hasData) return _FieldSkeleton(c: c);
                                return _AccountTile(
                                  accounts: snap.data!,
                                  selected: _account,
                                  accent:   accent,
                                  c:        c,
                                  onSelect: (a) => setState(() {
                                    _account = a;
                                    if (_amount > 0) _impactCtrl.forward();
                                  }),
                                );
                              },
                            ),
                            const SizedBox(height: _C.sm),
                            _DateTile(
                              dueDate:    _dueDate,
                              accent:     accent,
                              c:          c,
                              onSelected: (d) => setState(() => _dueDate = d),
                            ),
                          ]);
                        },
                      ),
                      const SizedBox(height: _C.lg),

                      // ── ¿Cómo afecta tu cuenta? ───────────────────
                      _SectionLabel(text: '¿Cómo afecta tu cuenta?', c: c),
                      const SizedBox(height: _C.sm),
                      AnimatedBuilder(
                        animation: _typeAnim,
                        builder: (_, __) => _ImpactSelector(
                          selected:  _impactType,
                          debtType:  _debtType,
                          accent:    _accentAt(_typeAnim.value),
                          c:         c,
                          onChanged: (t) {
                            HapticFeedback.selectionClick();
                            setState(() => _impactType = t);
                          },
                        ),
                      ),

                      // ── Impact card — solo cuando hay datos ───────
                      AnimatedSize(
                        duration: _C.mid, curve: _C.easeOut,
                        child: (_amount > 0 && _account != null)
                            ? Padding(
                                padding: const EdgeInsets.only(top: _C.lg),
                                child: FadeTransition(
                                  opacity: _impactAnim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.05),
                                      end: Offset.zero,
                                    ).animate(_impactAnim),
                                    child: AnimatedBuilder(
                                      animation: _typeAnim,
                                      builder: (_, __) => _ImpactCard(
                                        debtType:   _debtType,
                                        impactType: _impactType,
                                        amount:     _amount,
                                        account:    _account!,
                                        accent:     _accentAt(_typeAnim.value),
                                        c:          c,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Botón flotante ────────────────────────────────────────────
        AnimatedBuilder(
          animation: _typeAnim,
          builder: (_, __) => _FloatBtn(
            isLoading:  _isLoading,
            isSuccess:  _isSuccess,
            debtType:   _debtType,
            accent:     _accentAt(_typeAnim.value),
            c:          _C(context),
            onTap:      _requestConfirm,
          ),
        ),

        // ── Confetti ──────────────────────────────────────────────────
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 40,
            gravity: 0.28,
            colors: const [_C.red, _C.green, _C.orange, _C.purple, _C.blue],
            createParticlePath: _starPath,
          ),
        ),
      ]),
    );
  }

  // ── AppBar con tipo selector ──────────────────────────────────────────────
  Widget _buildAppBar(_C c) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 56,
      // El tipo selector vive en el appbar — siempre visible
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        title: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _C.md),
            child: Row(children: [
              _BackBtn(c: c),
              const SizedBox(width: _C.sm),
              Expanded(
                child: AnimatedBuilder(
                  animation: _typeAnim,
                  builder: (_, __) => _TypeSelector(
                    debtType: _debtType,
                    accent:   _accentAt(_typeAnim.value),
                    c:        c,
                    onChanged: _setDebtType,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showPersonPicker() {
    final c = _C(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonPickerSheet(
        c: c,
        onPickContact:   _pickContact,
        onManualEntry:   _useManualEntry,
      ),
    );
  }
}

// ─── TYPE SELECTOR ────────────────────────────────────────────────────────────
// Segmented control iOS. Vive en el AppBar — siempre visible.
// El color del segmento activo ES el acento de toda la pantalla.
class _TypeSelector extends StatelessWidget {
  final DebtType debtType;
  final Color accent;
  final _C c;
  final ValueChanged<DebtType> onChanged;

  const _TypeSelector({
    required this.debtType, required this.accent,
    required this.c, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(_C.rLG),
        border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
      ),
      child: Row(children: [
        Expanded(child: _Seg(
          label: 'Yo debo',
          icon: Iconsax.arrow_down,
          selected: debtType == DebtType.debt,
          accent: accent,
          c: c,
          onTap: () => onChanged(DebtType.debt),
        )),
        const SizedBox(width: 3),
        Expanded(child: _Seg(
          label: 'Me deben',
          icon: Iconsax.arrow_up_3,
          selected: debtType == DebtType.loan,
          accent: accent,
          c: c,
          onTap: () => onChanged(DebtType.loan),
        )),
      ]),
    );
  }
}

class _Seg extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final _C c;
  final VoidCallback onTap;

  const _Seg({
    required this.label, required this.icon, required this.selected,
    required this.accent, required this.c, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _C.fast,
        decoration: BoxDecoration(
          color: selected ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(_C.rMD),
          boxShadow: selected ? [
            BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.18 : 0.06),
                blurRadius: 6, offset: const Offset(0, 1)),
          ] : null,
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 13,
              color: selected ? accent : c.label4),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : c.label3,
                letterSpacing: -0.1,
              )),
        ]),
      ),
    );
  }
}

// ─── HERO CARD ────────────────────────────────────────────────────────────────
// Monto + persona en tiempo real. Compacto.
// Sin BackdropFilter, sin gradientes dobles, sin bordes decorativos.
class _HeroCard extends StatelessWidget {
  final double amount;
  final String personName;
  final DebtType debtType;
  final Color accent;
  final _C c;

  const _HeroCard({
    required this.amount, required this.personName, required this.debtType,
    required this.accent, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final hasData = amount > 0 || personName.isNotEmpty;

    return AnimatedContainer(
      duration: _C.mid,
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.r2XL),
        border: Border.all(
          color: hasData ? accent.withOpacity(0.22) : c.sep.withOpacity(0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(c.isDark ? 0.18 : 0.04),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(children: [
        // Avatar o ícono vacío
        AnimatedSwitcher(
          duration: _C.fast,
          child: personName.isNotEmpty
              ? Container(
                  key: const ValueKey('avatar'),
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color: accent.withOpacity(c.isDark ? 0.22 : 0.10),
                      shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      personName[0].toUpperCase(),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: accent),
                    ),
                  ),
                )
              : Container(
                  key: const ValueKey('empty'),
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                      color: c.raised, shape: BoxShape.circle),
                  child: Icon(Iconsax.user, size: 20, color: c.label4),
                ),
        ),
        const SizedBox(width: _C.md),

        // Persona y tipo
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              debtType == DebtType.debt ? 'Deuda con' : 'Préstamo a',
              style: TextStyle(fontSize: 11, color: c.label3),
            ),
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: _C.fast,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                personName.isEmpty ? '—' : personName,
                key: ValueKey(personName),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: personName.isEmpty ? c.label4 : c.label,
                    letterSpacing: -0.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),

        // Monto
        AnimatedSwitcher(
          duration: _C.mid,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            amount > 0 ? compact.format(amount) : '—',
            key: ValueKey(amount > 0),
            style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: amount > 0 ? accent : c.label4,
              letterSpacing: -0.8,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── PERSON FIELD ─────────────────────────────────────────────────────────────
// BUG FIX: Tres estados exclusivos:
// 1. Sin nadie → tile que abre el picker
// 2. _isManualMode = true → campo de texto con autofocus
// 3. _selectedContact != null → tarjeta del contacto con balance
//
// El bug original: el campo manual solo aparecía si selectedContact != null.
// Ahora depende de _isManualMode, que se activa independientemente.
class _PersonField extends StatelessWidget {
  final contacts.Contact? selectedContact;
  final bool isManualMode;
  final TextEditingController manualCtrl;
  final FocusNode manualFocus;
  final double? contactBalance;
  final bool isFetching;
  final Color accent;
  final DebtType debtType;
  final _C c;
  final VoidCallback onTapSelector;
  final VoidCallback onClear;
  final VoidCallback onManualChanged;

  const _PersonField({
    required this.selectedContact, required this.isManualMode,
    required this.manualCtrl, required this.manualFocus,
    required this.contactBalance, required this.isFetching,
    required this.accent, required this.debtType, required this.c,
    required this.onTapSelector, required this.onClear,
    required this.onManualChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Estado 3: contacto seleccionado
    if (selectedContact != null) {
      return _ContactCard(
        contact: selectedContact!,
        balance: contactBalance,
        isFetching: isFetching,
        accent: accent,
        c: c,
        onClear: onClear,
      );
    }

    // Estado 2: modo manual — BUG FIX
    if (isManualMode) {
      return _ManualField(
        ctrl:      manualCtrl,
        focus:     manualFocus,
        accent:    accent,
        c:         c,
        onClear:   onClear,
        onChanged: onManualChanged,
      );
    }

    // Estado 1: vacío — toca para abrir picker
    return _ScaleBtn(
      onTap: onTapSelector,
      child: Container(
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_C.rXL),
          border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
                blurRadius: 5, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: accent.withOpacity(c.isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(_C.rSM + 2)),
            child: Icon(Iconsax.user_search, size: 16, color: accent),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            child: Text('Seleccionar o escribir nombre',
                style: TextStyle(fontSize: 15, color: c.label3)),
          ),
          Icon(Iconsax.arrow_right_3, size: 16, color: c.label4),
        ]),
      ),
    );
  }
}

// ─── MANUAL FIELD ─────────────────────────────────────────────────────────────
// Campo de texto simple. Tiene autofocus.
// Botón "×" a la derecha para volver al estado vacío.
class _ManualField extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final Color accent;
  final _C c;
  final VoidCallback onClear;
  final VoidCallback onChanged;

  const _ManualField({
    required this.ctrl, required this.focus, required this.accent,
    required this.c, required this.onClear, required this.onChanged,
  });

  @override
  State<_ManualField> createState() => _ManualFieldState();
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
    final c = widget.c;
    return AnimatedContainer(
      duration: _C.fast,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(
          color: _focused
              ? widget.accent.withOpacity(0.55)
              : c.sep.withOpacity(0.40),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? widget.accent.withOpacity(c.isDark ? 0.10 : 0.06)
                : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
            blurRadius: _focused ? 12 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        const SizedBox(width: _C.md),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: widget.accent.withOpacity(c.isDark ? 0.18 : 0.09),
              shape: BoxShape.circle),
          child: Icon(Iconsax.edit_2, size: 15, color: widget.accent),
        ),
        Expanded(
          child: TextFormField(
            controller: widget.ctrl,
            focusNode:  widget.focus,
            textCapitalization: TextCapitalization.words,
            onChanged:  (_) {
              HapticFeedback.selectionClick();
              widget.onChanged();
            },
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '' : null,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: c.label),
            decoration: InputDecoration(
              hintText: 'Nombre o empresa',
              hintStyle: TextStyle(fontSize: 15, color: c.label4,
                  fontWeight: FontWeight.w400),
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: _C.md, vertical: 16),
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
          ),
        ),
        // Botón limpiar
        _ScaleBtn(
          onTap: widget.onClear,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: _C.md, vertical: _C.md),
            child: Icon(Icons.cancel_rounded,
                size: 20, color: c.label4),
          ),
        ),
      ]),
    );
  }
}

// ─── CONTACT CARD ─────────────────────────────────────────────────────────────
// Muestra el contacto seleccionado con su historial de deuda.
class _ContactCard extends StatelessWidget {
  final contacts.Contact contact;
  final double? balance;
  final bool isFetching;
  final Color accent;
  final _C c;
  final VoidCallback onClear;

  const _ContactCard({
    required this.contact, required this.balance, required this.isFetching,
    required this.accent, required this.c, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    String balanceText;
    Color balanceColor;
    if (isFetching) {
      balanceText  = 'Cargando historial…';
      balanceColor = c.label3;
    } else if (balance == null || balance == 0) {
      balanceText  = 'Sin deudas previas';
      balanceColor = c.label3;
    } else if (balance! > 0) {
      balanceText  = 'Te debe ${compact.format(balance)}';
      balanceColor = _C.green;
    } else {
      balanceText  = 'Le debes ${compact.format(balance!.abs())}';
      balanceColor = _C.red;
    }

    return Container(
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: accent.withOpacity(0.22), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 6, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(children: [
        // Avatar
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: accent.withOpacity(c.isDark ? 0.22 : 0.10),
              shape: BoxShape.circle),
          child: Center(
            child: Text(
              contact.displayName[0].toUpperCase(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: accent),
            ),
          ),
        ),
        const SizedBox(width: _C.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.displayName,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: c.label, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              isFetching
                  ? SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        backgroundColor: c.sep,
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ))
                  : Text(balanceText,
                      style: TextStyle(fontSize: 12, color: balanceColor,
                          fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        _ScaleBtn(
          onTap: onClear,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle),
            child: Icon(Icons.close_rounded, size: 15, color: c.label3),
          ),
        ),
      ]),
    );
  }
}

// ─── CONCEPT FIELD ────────────────────────────────────────────────────────────
class _ConceptField extends StatefulWidget {
  final TextEditingController ctrl;
  final String hint;
  final Color accent;
  final _C c;

  const _ConceptField({
    required this.ctrl, required this.hint,
    required this.accent, required this.c,
  });

  @override
  State<_ConceptField> createState() => _ConceptFieldState();
}

class _ConceptFieldState extends State<_ConceptField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedContainer(
      duration: _C.fast,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(
          color: _focused
              ? widget.accent.withOpacity(0.55) : c.sep.withOpacity(0.40),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? widget.accent.withOpacity(c.isDark ? 0.10 : 0.06)
                : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
            blurRadius: _focused ? 12 : 5, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.ctrl,
        focusNode:  _focus,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => HapticFeedback.selectionClick(),
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
            color: c.label),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? '' : null,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 14, color: c.label4),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Iconsax.note_text, size: 18,
                color: _focused ? widget.accent : c.label4),
          ),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: _C.md, vertical: 16),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

// ─── AMOUNT INPUT ─────────────────────────────────────────────────────────────
// El monto es el protagonista — 42px w800.
// Formateador de moneda integrado. Sin widget envolvente decorativo.
class _AmountInput extends StatefulWidget {
  final Color accent;
  final _C c;
  final ValueChanged<double> onChanged;

  const _AmountInput({
    required this.accent, required this.c, required this.onChanged,
  });

  @override
  State<_AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<_AmountInput> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  double get _value =>
      double.tryParse(_ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

  bool get _hasValue => _value > 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedContainer(
      duration: _C.fast,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.r2XL),
        border: Border.all(
          color: _focused
              ? widget.accent.withOpacity(0.50) : c.sep.withOpacity(0.40),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? widget.accent.withOpacity(c.isDark ? 0.10 : 0.06)
                : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
            blurRadius: _focused ? 16 : 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: _C.lg),
      child: TextFormField(
        controller:  _ctrl,
        focusNode:   _focus,
        textAlign:   TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _MoneyFormatter(),
        ],
        onChanged: (_) {
          HapticFeedback.selectionClick();
          widget.onChanged(_value);
          setState(() {});
        },
        validator: (v) {
          if (v == null || v.isEmpty) return '';
          if (_value <= 0) return '';
          return null;
        },
        style: TextStyle(
          fontSize: 42, fontWeight: FontWeight.w800,
          color: _hasValue ? widget.accent : c.label4,
          letterSpacing: -1.5, height: 1.0,
        ),
        decoration: InputDecoration(
          border:         InputBorder.none,
          hintText:       '\$ 0',
          hintStyle: TextStyle(
            fontSize: 42, fontWeight: FontWeight.w800,
            color: c.label4, letterSpacing: -1.5,
          ),
          contentPadding: EdgeInsets.zero,
          errorStyle:     const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

class _MoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next.copyWith(text: '');
    final n = int.tryParse(next.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final s = fmt.format(n);
    return next.copyWith(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

// ─── ACCOUNT TILE ─────────────────────────────────────────────────────────────
class _AccountTile extends StatelessWidget {
  final List<Account> accounts;
  final Account? selected;
  final Color accent;
  final _C c;
  final ValueChanged<Account> onSelect;

  const _AccountTile({
    required this.accounts, required this.selected,
    required this.accent, required this.c, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleBtn(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_C.rXL),
          border: Border.all(
            color: selected != null
                ? accent.withOpacity(0.22) : c.sep.withOpacity(0.40),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
                blurRadius: 5, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: accent.withOpacity(c.isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(_C.rSM)),
            child: Icon(Iconsax.wallet_3, size: 16, color: accent),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cuenta afectada',
                  style: TextStyle(fontSize: 10, color: c.label3,
                      fontWeight: FontWeight.w600, letterSpacing: 0.1)),
              const SizedBox(height: 2),
              Text(selected?.name ?? 'Seleccionar cuenta',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: selected != null ? c.label : c.label4,
                      letterSpacing: -0.2)),
            ]),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: c.label3),
        ]),
      ),
    );
  }

  void _pick(BuildContext context) {
    final c = _C(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountSheet(
          accounts: accounts, accent: accent, c: c, onSelect: onSelect),
    );
  }
}

// ─── DATE TILE ────────────────────────────────────────────────────────────────
class _DateTile extends StatelessWidget {
  final DateTime? dueDate;
  final Color accent;
  final _C c;
  final ValueChanged<DateTime> onSelected;

  const _DateTile({
    required this.dueDate, required this.accent,
    required this.c, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleBtn(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime(2100),
        );
        if (picked != null) onSelected(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_C.rXL),
          border: Border.all(
            color: dueDate != null
                ? accent.withOpacity(0.22) : c.sep.withOpacity(0.40),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
                blurRadius: 5, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: dueDate != null
                    ? accent.withOpacity(c.isDark ? 0.18 : 0.09)
                    : c.raised,
                borderRadius: BorderRadius.circular(_C.rSM)),
            child: Icon(Iconsax.calendar_1, size: 16,
                color: dueDate != null ? accent : c.label4),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vencimiento',
                  style: TextStyle(fontSize: 10, color: c.label3,
                      fontWeight: FontWeight.w600, letterSpacing: 0.1)),
              const SizedBox(height: 2),
              Text(
                dueDate == null
                    ? 'Sin fecha límite'
                    : DateFormat('d MMM yyyy', 'es_CO').format(dueDate!),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: dueDate != null ? c.label : c.label4,
                    letterSpacing: -0.2),
              ),
            ]),
          ),
          if (dueDate != null)
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: c.label3)
          else
            Icon(Icons.add_rounded, size: 20, color: c.label4),
        ]),
      ),
    );
  }
}

// ─── IMPACT SELECTOR ─────────────────────────────────────────────────────────
// Tres opciones. Cada una es una fila compacta.
// La seleccionada muestra el borde del acento — sin escala, sin shadow extra.
// Información suficiente para decidir. Sin texto redundante.
class _ImpactSelector extends StatelessWidget {
  final DebtImpactType selected;
  final DebtType debtType;
  final Color accent;
  final _C c;
  final ValueChanged<DebtImpactType> onChanged;

  const _ImpactSelector({
    required this.selected, required this.debtType, required this.accent,
    required this.c, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final opts = [
      (
        type: DebtImpactType.liquid,
        icon: Iconsax.wallet_add_1,
        title: debtType == DebtType.debt
            ? 'Entró a mi cuenta' : 'Salió de mi cuenta',
        sub: 'Afecta el saldo disponible',
      ),
      (
        type: DebtImpactType.restricted,
        icon: Iconsax.lock_1,
        title: 'Propósito fijo',
        sub: 'El dinero tiene un destino reservado',
      ),
      (
        type: DebtImpactType.direct,
        icon: Iconsax.cards,
        title: debtType == DebtType.debt
            ? 'Alguien pagó por mí' : 'Pagué por alguien',
        sub: 'El dinero no pasó por mis cuentas',
      ),
    ];

    return Column(
      children: opts.asMap().entries.map((e) {
        final i   = e.key;
        final opt = e.value;
        final sel = selected == opt.type;

        return Padding(
          padding: EdgeInsets.only(bottom: i < opts.length - 1 ? _C.sm : 0),
          child: _ScaleBtn(
            onTap: () => onChanged(opt.type),
            child: AnimatedContainer(
              duration: _C.fast,
              padding: const EdgeInsets.all(_C.md),
              decoration: BoxDecoration(
                color: sel
                    ? accent.withOpacity(c.isDark ? 0.12 : 0.06)
                    : c.surface,
                borderRadius: BorderRadius.circular(_C.rXL),
                border: Border.all(
                  color: sel
                      ? accent.withOpacity(c.isDark ? 0.45 : 0.30)
                      : c.sep.withOpacity(0.40),
                  width: sel ? 1.2 : 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
                      blurRadius: 5, offset: const Offset(0, 1)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: sel
                        ? accent.withOpacity(c.isDark ? 0.20 : 0.10)
                        : c.raised,
                    borderRadius: BorderRadius.circular(_C.rSM + 2),
                  ),
                  child: Icon(opt.icon, size: 16,
                      color: sel ? accent : c.label3),
                ),
                const SizedBox(width: _C.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opt.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                            color: sel ? accent : c.label,
                            letterSpacing: -0.1,
                          )),
                      const SizedBox(height: 2),
                      Text(opt.sub,
                          style: TextStyle(fontSize: 12, color: c.label3)),
                    ],
                  ),
                ),
                if (sel)
                  Icon(Iconsax.tick_circle, size: 18, color: accent),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── IMPACT CARD ─────────────────────────────────────────────────────────────
// Aparece solo cuando hay monto + cuenta.
// Sin gradiente decorativo, sin border doble, sin header "Impacto Financiero"
// con gradiente de ícono. Los datos hablan solos.
class _ImpactCard extends StatelessWidget {
  final DebtType debtType;
  final DebtImpactType impactType;
  final double amount;
  final Account account;
  final Color accent;
  final _C c;

  const _ImpactCard({
    required this.debtType, required this.impactType, required this.amount,
    required this.account, required this.accent, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    final isDirect = impactType == DebtImpactType.direct;
    final projected = isDirect
        ? account.balance
        : (debtType == DebtType.debt
            ? account.balance + amount
            : account.balance - amount);
    final impactPct = account.balance > 0
        ? (amount / account.balance * 100).clamp(0.0, 100.0) : 0.0;
    final isHighImpact = impactPct > 15 && !isDirect;

    return Container(
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: accent.withOpacity(0.18), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: accent.withOpacity(c.isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(_C.rSM)),
            child: Icon(Iconsax.chart_success, size: 16, color: accent),
          ),
          const SizedBox(width: _C.md),
          Text('Impacto en ${account.name}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: c.label, letterSpacing: -0.1)),
        ]),

        const SizedBox(height: _C.md),
        Container(height: 0.5, color: c.sep.withOpacity(0.5)),
        const SizedBox(height: _C.md),

        // Saldo actual
        _ImpactRow(
          label: 'Saldo actual',
          value: compact.format(account.balance),
          color: c.label3,
          valueColor: c.label,
          c: c,
        ),

        if (!isDirect) ...[
          const SizedBox(height: _C.sm),
          _ImpactRow(
            label: debtType == DebtType.debt ? 'Entrará' : 'Saldrá',
            value: compact.format(amount),
            color: c.label3,
            valueColor: accent,
            c: c,
          ),
          const SizedBox(height: _C.sm),
          Container(height: 0.5, color: c.sep.withOpacity(0.5)),
          const SizedBox(height: _C.sm),
          _ImpactRow(
            label: 'Saldo proyectado',
            value: compact.format(projected),
            color: c.label3,
            valueColor: projected >= 0 ? _C.green : _C.red,
            bold: true,
            c: c,
          ),
        ] else ...[
          const SizedBox(height: _C.sm),
          Row(children: [
            Icon(Iconsax.info_circle, size: 14, color: c.label3),
            const SizedBox(width: _C.sm),
            Expanded(
              child: Text('El saldo de esta cuenta no cambiará.',
                  style: TextStyle(fontSize: 12, color: c.label3)),
            ),
          ]),
        ],

        // Advertencia de alto impacto
        if (isHighImpact) ...[
          const SizedBox(height: _C.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: _C.md, vertical: _C.sm),
            decoration: BoxDecoration(
              color: _C.orange.withOpacity(c.isDark ? 0.14 : 0.07),
              borderRadius: BorderRadius.circular(_C.rMD),
              border: Border.all(
                  color: _C.orange.withOpacity(0.25), width: 0.5),
            ),
            child: Row(children: [
              Icon(Iconsax.warning_2, size: 14, color: _C.orange),
              const SizedBox(width: _C.sm),
              Expanded(
                child: Text(
                  'Esta operación representa el '
                  '${impactPct.toStringAsFixed(1)}% de tu saldo disponible.',
                  style: TextStyle(fontSize: 12, color: _C.orange,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color valueColor;
  final bool bold;
  final _C c;

  const _ImpactRow({
    required this.label, required this.value,
    required this.color, required this.valueColor,
    this.bold = false, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: color)),
        Text(value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
              letterSpacing: -0.2,
            )),
      ],
    );
  }
}

// ─── FLOATING BUTTON ─────────────────────────────────────────────────────────
// ─── FLOATING BUTTON (CORREGIDO) ─────────────────────────────────────────────
class _FloatBtn extends StatefulWidget {
  final bool isLoading;
  final bool isSuccess;
  final DebtType debtType;
  final Color accent;
  final _C c;
  final VoidCallback onTap;

  const _FloatBtn({
    required this.isLoading, required this.isSuccess, required this.debtType,
    required this.accent, required this.c, required this.onTap,
  });

  @override
  State<_FloatBtn> createState() => _FloatBtnState();
}

class _FloatBtnState extends State<_FloatBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final color = widget.isSuccess ? _C.green : widget.accent;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            _C.md, _C.md, _C.md,
            _C.lg + MediaQuery.of(context).padding.bottom),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // FIX: Usamos el ancho real disponible (constraints.maxWidth)
            // en lugar de double.infinity para que la animación funcione.
            final fullWidth = constraints.maxWidth;

            return GestureDetector(
              onTapDown:   (widget.isLoading || widget.isSuccess)
                  ? null : (_) => setState(() => _p = true),
              onTapUp:     (widget.isLoading || widget.isSuccess)
                  ? null : (_) { setState(() => _p = false); widget.onTap(); },
              onTapCancel: () => setState(() => _p = false),
              child: AnimatedScale(
                scale: _p ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 80),
                child: AnimatedContainer(
                  duration: _C.mid,
                  curve:  _C.easeOut,
                  // AQUÍ ESTABA EL ERROR: Cambiamos double.infinity por fullWidth
                  width:  widget.isLoading ? 60 : fullWidth,
                  height: 60,
                  decoration: BoxDecoration(
                    color: widget.isLoading ? c.label4 : color,
                    borderRadius: BorderRadius.circular(
                        widget.isLoading ? 30 : _C.rXL),
                    boxShadow: widget.isLoading ? null : [
                      BoxShadow(
                        color: color.withOpacity(_p ? 0.18 : 0.38),
                        blurRadius: _p ? 8 : 20,
                        offset: Offset(0, _p ? 2 : 7),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: _C.fast,
                    child: widget.isLoading
                        ? const SizedBox(
                            key: ValueKey('load'),
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : widget.isSuccess
                            ? const Icon(Iconsax.tick_circle,
                                key: ValueKey('ok'),
                                color: Colors.white, size: 26)
                            : Row(
                                key: const ValueKey('idle'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.debtType == DebtType.debt
                                        ? Iconsax.money_recive
                                        : Iconsax.money_send,
                                    color: Colors.white, size: 20,
                                  ),
                                  const SizedBox(width: _C.sm + 2),
                                  const Text('Confirmar operación',
                                      style: TextStyle(
                                        color: Colors.white, fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      )),
                                ],
                              ),
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}
// ─── PERSON PICKER SHEET ──────────────────────────────────────────────────────
class _PersonPickerSheet extends StatelessWidget {
  final _C c;
  final VoidCallback onPickContact;
  final VoidCallback onManualEntry;

  const _PersonPickerSheet({
    required this.c, required this.onPickContact, required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          _C.md, _C.md, _C.md,
          _C.lg + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_C.r2XL)),
        border: Border(top: BorderSide(color: c.sep.withOpacity(0.3), width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: _C.lg),
            decoration: BoxDecoration(
                color: c.sep, borderRadius: BorderRadius.circular(2))),

        Text('¿Quién es?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: c.label, letterSpacing: -0.3)),
        const SizedBox(height: _C.lg),

        _SheetOption(
          icon: Iconsax.user_search,
          title: 'Desde la agenda',
          subtitle: 'Buscar entre tus contactos',
          c: c,
          onTap: onPickContact,
        ),
        const SizedBox(height: _C.sm),
        _SheetOption(
          icon: Iconsax.edit_2,
          title: 'Escribir manualmente',
          subtitle: 'Ingresar nombre o entidad',
          c: c,
          onTap: onManualEntry,
        ),
      ]),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final _C c;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon, required this.title, required this.subtitle,
    required this.c, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ScaleBtn(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(_C.rXL),
          border: Border.all(color: c.sep.withOpacity(0.3), width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(_C.rMD)),
            child: Icon(icon, size: 18, color: c.label2),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: c.label, letterSpacing: -0.2)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: c.label3)),
            ]),
          ),
          Icon(Iconsax.arrow_right_3, size: 16, color: c.label4),
        ]),
      ),
    );
  }
}

// ─── ACCOUNT SHEET ────────────────────────────────────────────────────────────
class _AccountSheet extends StatelessWidget {
  final List<Account> accounts;
  final Color accent;
  final _C c;
  final ValueChanged<Account> onSelect;

  const _AccountSheet({
    required this.accounts, required this.accent,
    required this.c, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    return Container(
      padding: EdgeInsets.fromLTRB(
          _C.md, _C.md, _C.md,
          _C.lg + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_C.r2XL)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: _C.lg),
            decoration: BoxDecoration(
                color: c.sep, borderRadius: BorderRadius.circular(2))),
        Text('Selecciona una cuenta',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: c.label, letterSpacing: -0.3)),
        const SizedBox(height: _C.lg),
        ...accounts.map((acc) => Padding(
          padding: const EdgeInsets.only(bottom: _C.sm),
          child: _ScaleBtn(
            onTap: () { HapticFeedback.selectionClick(); onSelect(acc); },
            child: Container(
              padding: const EdgeInsets.all(_C.md),
              decoration: BoxDecoration(
                color: c.raised,
                borderRadius: BorderRadius.circular(_C.rXL),
                border: Border.all(color: c.sep.withOpacity(0.3), width: 0.5),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: accent.withOpacity(c.isDark ? 0.18 : 0.09),
                      borderRadius: BorderRadius.circular(_C.rSM)),
                  child: Icon(acc.icon, size: 16, color: accent),
                ),
                const SizedBox(width: _C.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acc.name,
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w700, color: c.label,
                              letterSpacing: -0.2)),
                      Text(compact.format(acc.balance),
                          style: TextStyle(fontSize: 12, color: c.label3)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        )),
      ]),
    );
  }
}

// ─── CONFIRMATION SHEET ───────────────────────────────────────────────────────
// Resumen de la operación antes de confirmar.
// Lista de filas label/valor. Sin decoración que compita.
class _ConfirmSheet extends StatelessWidget {
  final DebtType debtType;
  final double amount;
  final String concept;
  final String personName;
  final Account account;
  final Color accentColor;
  final _C c;
  final VoidCallback onConfirm;

  const _ConfirmSheet({
    required this.debtType, required this.amount, required this.concept,
    required this.personName, required this.account, required this.accentColor,
    required this.c, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    return Container(
      padding: EdgeInsets.fromLTRB(
          _C.md, _C.md, _C.md,
          _C.lg + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_C.r2XL)),
        border: Border(top: BorderSide(color: c.sep.withOpacity(0.3), width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: _C.lg),
            decoration: BoxDecoration(
                color: c.sep, borderRadius: BorderRadius.circular(2))),

        // Ícono y título
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: accentColor.withOpacity(c.isDark ? 0.18 : 0.10),
              shape: BoxShape.circle),
          child: Icon(
            debtType == DebtType.debt
                ? Iconsax.money_recive : Iconsax.money_send,
            size: 24, color: accentColor,
          ),
        ),
        const SizedBox(height: _C.md),
        Text('¿Confirmar operación?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: c.label, letterSpacing: -0.3)),
        const SizedBox(height: _C.lg),

        // Resumen
        Container(
          padding: const EdgeInsets.all(_C.md),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(_C.rXL),
            border: Border.all(color: c.sep.withOpacity(0.3), width: 0.5),
          ),
          child: Column(children: [
            _Row('Tipo', debtType == DebtType.debt ? 'Yo debo' : 'Me deben', c),
            _Divider(c: c),
            _Row('Monto', compact.format(amount), c),
            _Divider(c: c),
            _Row('Concepto', concept, c),
            if (personName.isNotEmpty) ...[
              _Divider(c: c),
              _Row('Persona', personName, c),
            ],
            _Divider(c: c),
            _Row('Cuenta', account.name, c),
          ]),
        ),

        const SizedBox(height: _C.lg),

        // Botones
        Row(children: [
          Expanded(
            child: _ScaleBtn(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(_C.rXL),
                    border: Border.all(
                        color: c.sep.withOpacity(0.4), width: 0.5)),
                alignment: Alignment.center,
                child: Text('Cancelar',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: c.label2)),
              ),
            ),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            flex: 2,
            child: _ScaleBtn(
              onTap: onConfirm,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(_C.rXL),
                    boxShadow: [
                      BoxShadow(
                          color: accentColor.withOpacity(0.35),
                          blurRadius: 14, offset: const Offset(0, 5)),
                    ]),
                alignment: Alignment.center,
                child: const Text('Confirmar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.1)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final _C c;
  const _Row(this.label, this.value, this.c);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _C.sm + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: c.label3)),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: c.label, letterSpacing: -0.1)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final _C c;
  const _Divider({required this.c});

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: c.sep.withOpacity(0.5));
}

// ─── UTILS ────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final _C c;
  const _SectionLabel({required this.text, required this.c});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: c.label3, letterSpacing: 0.1));
}

class _BackBtn extends StatelessWidget {
  final _C c;
  const _BackBtn({required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); },
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: c.label),
      ),
    );
  }
}

class _FieldSkeleton extends StatelessWidget {
  final _C c;
  const _FieldSkeleton({required this.c});

  @override
  Widget build(BuildContext context) => Container(
      height: 56,
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(_C.rXL)),
      alignment: Alignment.center,
      child: SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.label4)));
}

class _ScaleBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleBtn({required this.child, required this.onTap});

  @override
  State<_ScaleBtn> createState() => _ScaleBtnState();
}

class _ScaleBtnState extends State<_ScaleBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _p = true),
      onTapUp:     (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
          scale: _p ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: widget.child),
    );
  }
}

Path _starPath(Size size) {
  double r(double deg) => deg * (math.pi / 180);
  final hw = size.width / 2;
  final path = Path();
  path.moveTo(size.width, hw);
  for (double s = 0; s < r(360); s += r(72)) {
    path.lineTo(hw + hw * math.cos(s), hw + hw * math.sin(s));
    path.lineTo(hw + (hw / 2.5) * math.cos(s + r(36)),
        hw + (hw / 2.5) * math.sin(s + r(36)));
  }
  path.close();
  return path;
}