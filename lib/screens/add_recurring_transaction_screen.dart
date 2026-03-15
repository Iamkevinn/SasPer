// lib/screens/add_recurring_transaction_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA DE DISEÑO — Apple iOS / Reminders + Wallet                      │
// │                                                                             │
// │  Esta es una pantalla de CREACIÓN. El usuario viene con una intención       │
// │  clara: registrar un compromiso financiero recurrente.                      │
// │                                                                             │
// │  El trabajo del diseño es NO interrumpir esa intención.                    │
// │                                                                             │
// │  PRINCIPIOS:                                                               │
// │  • Un campo a la vez en foco — el teclado no sorprende.                   │
// │  • El impacto aparece EN CONTEXTO, no en una tarjeta separada abajo.      │
// │  • La frecuencia es visual — chips que dicen lo que cuestan al mes.       │
// │  • El botón guardar es el único CTA. Grande, al fondo, siempre visible.   │
// │  • Cero gradientes decorativos — el color del tipo (gasto/ingreso)        │
// │    es el único acento cromático de toda la pantalla.                      │
// │                                                                             │
// │  FRECUENCIAS AÑADIDAS:                                                     │
// │  Diario / Semanal / Cada 2 semanas / Quincenal / Mensual / Bimestral /   │
// │  Trimestral / Semestral / Anual                                            │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide Account; 
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';

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

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double xl   = 32.0;
  static const double rSM  = 8.0;
  static const double rMD  = 12.0;
  static const double rLG  = 16.0;
  static const double rXL  = 22.0;

  static const Duration fast   = Duration(milliseconds: 140);
  static const Duration mid    = Duration(milliseconds: 260);
  static const Curve   easeOut = Curves.easeOutCubic;
}

// ─── MODELO DE FRECUENCIA ────────────────────────────────────────────────────
// Cada frecuencia sabe cuántas veces ocurre al mes y al año.
// Eso permite mostrar el coste mensual/anual EN EL CHIP, sin cálculo del usuario.
class _Freq {
  final String id;
  final String label;
  final String shortLabel;   // Para el chip
  final IconData icon;
  final double perMonth;     // Multiplicador a mensual
  final double perYear;      // Multiplicador a anual

  const _Freq({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.perMonth,
    required this.perYear,
  });
}

const List<_Freq> _frequencies = [
  _Freq(id: 'diario',        label: 'Diario',          shortLabel: 'Diario',     icon: Iconsax.sun_1,           perMonth: 30,   perYear: 365),
  _Freq(id: 'semanal',       label: 'Semanal',         shortLabel: 'Semanal',    icon: Iconsax.calendar_1,      perMonth: 4.33, perYear: 52),
  _Freq(id: 'cada_2_semanas',label: 'Cada 2 semanas',  shortLabel: '2 semanas',  icon: Iconsax.calendar_2,      perMonth: 2.17, perYear: 26),
  _Freq(id: 'quincenal',     label: 'Quincenal',       shortLabel: 'Quincenal',  icon: Iconsax.calendar,        perMonth: 2,    perYear: 24),
  _Freq(id: 'mensual',       label: 'Mensual',         shortLabel: 'Mensual',    icon: Iconsax.calendar_tick,   perMonth: 1,    perYear: 12),
  _Freq(id: 'bimestral',     label: 'Bimestral',       shortLabel: 'Bimestral',  icon: Iconsax.calendar_remove, perMonth: 0.5,  perYear: 6),
  _Freq(id: 'trimestral',    label: 'Trimestral',      shortLabel: 'Trimestral', icon: Iconsax.chart_1,         perMonth: 0.33, perYear: 4),
  _Freq(id: 'semestral',     label: 'Semestral',       shortLabel: 'Semestral',  icon: Iconsax.chart_21,        perMonth: 0.17, perYear: 2),
  _Freq(id: 'anual',         label: 'Anual',           shortLabel: 'Anual',      icon: Iconsax.star,            perMonth: 0.083,perYear: 1),
];

_Freq _freqById(String id) =>
    _frequencies.firstWhere((f) => f.id == id, orElse: () => _frequencies[4]);

// ─── PANTALLA ─────────────────────────────────────────────────────────────────
class AddRecurringTransactionScreen extends StatefulWidget {
  const AddRecurringTransactionScreen({super.key});

  @override
  State<AddRecurringTransactionScreen> createState() =>
      _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState
    extends State<AddRecurringTransactionScreen>
    with SingleTickerProviderStateMixin {
  final RecurringRepository _repository = RecurringRepository.instance;
  final AccountRepository   _accountRepo = AccountRepository.instance;
  final CategoryRepository  _categoryRepo = CategoryRepository.instance;

  final _formKey              = GlobalKey<FormState>();
  final _descriptionCtrl      = TextEditingController();
  final _amountCtrl           = TextEditingController();
  final _descriptionFocus     = FocusNode();
  final _amountFocus          = FocusNode();

    // 👈 NUEVOS CONTROLADORES Y FOCOS
  final _payeeNameCtrl        = TextEditingController();
  final _payeeAccountCtrl     = TextEditingController();
  final _payeeNameFocus       = FocusNode();
  final _payeeAccountFocus    = FocusNode();
  
  bool       _isLoading       = false;
  String     _type            = 'Gasto';
  String     _frequencyId     = 'mensual';
  String?    _selectedAccId;
  Account?   _selectedAcc;
  Category?  _selectedCategory;
  DateTime   _startDate       = DateTime.now();
  TimeOfDay  _notifTime       = const TimeOfDay(hour: 9, minute: 0);

  late Future<List<Account>> _accountsFuture;
  late Future<List<Category>> _categoriesFuture;  

  // Controlador para la animación de cambio de tipo (Gasto ↔ Ingreso)
  late AnimationController _typeCtrl;
  late Animation<double>   _typeAnim;

  // Colores semánticos del tipo actual
  Color get _typeColor => _type == 'Gasto' ? _C.red : _C.green;

  // ── Cálculo de impacto ────────────────────────────────────────────────────
  double get _rawAmount =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

  double get _monthlyAmount {
    final freq = _freqById(_frequencyId);
    return _rawAmount * freq.perMonth;
  }

  double get _yearlyAmount {
    final freq = _freqById(_frequencyId);
    return _rawAmount * freq.perYear;
  }

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepo.getAccounts();
    _categoriesFuture = _categoryRepo.getCategories(); 
    _accountsFuture.then((accounts) {
      if (mounted && accounts.isNotEmpty) {
        setState(() {
          _selectedAccId = accounts.first.id;
          _selectedAcc   = accounts.first;
        });
      }
    });

    _typeCtrl = AnimationController(vsync: this, duration: _C.mid);
    _typeAnim = CurvedAnimation(parent: _typeCtrl, curve: _C.easeOut);

    _amountCtrl.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _descriptionFocus.dispose();
    _amountFocus.dispose();
    _typeCtrl.dispose();
    _payeeNameCtrl.dispose();    // 👈 NUEVO
    _payeeAccountCtrl.dispose(); // 👈 NUEVO
    _payeeNameFocus.dispose();   // 👈 NUEVO
    _payeeAccountFocus.dispose(); // 👈 NUEVO
    super.dispose();
  }

  // ── Cambio de tipo ────────────────────────────────────────────────────────
  void _setType(String t) {
    if (t == _type) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = t;
      _selectedCategory = null; // 👈 Limpiamos categoría al cambiar de Gasto a Ingreso
    });
    t == 'Gasto' ? _typeCtrl.forward() : _typeCtrl.reverse();
  }

  // ── Fecha y hora ──────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: _typeColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
            primary: _typeColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _notifTime = picked);
  }

  // ── Contactos ─────────────────────────────────────────────────────────────
  Future<void> _pickContact() async {
    HapticFeedback.lightImpact();
    try {
      // Abre el selector nativo de contactos de iOS/Android
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          setState(() {
            _payeeNameCtrl.text = contact.displayName;
          });
          HapticFeedback.selectionClick();
          // Pasamos el foco al siguiente campo automáticamente
          _payeeAccountFocus.requestFocus(); 
        }
      } else {
        NotificationHelper.show(
          message: 'Permiso de contactos denegado.', 
          type: NotificationType.warning
        );
      }
    } catch (e) {
      developer.log('Error abriendo contactos: $e', name: 'AddRecurringScreen');
    }
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedAccId == null || _selectedCategory == null) {
      HapticFeedback.vibrate();
      NotificationHelper.show(
        message: 'Completa todos los campos requeridos.',
        type: NotificationType.error,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final startDT = DateTime(
        _startDate.year, _startDate.month, _startDate.day,
        _notifTime.hour, _notifTime.minute,
      );

      // Mapear frequencyId a la string que espera el repositorio
      final repoFrequency = _mapFrequencyToRepo(_frequencyId);

      final newTx = await _repository.addRecurringTransaction(
        description: _descriptionCtrl.text.trim(),
        amount:      double.parse(_amountCtrl.text.replaceAll(',', '.')),
        type:        _type,
        category:    _selectedCategory!.name,
        accountId:   _selectedAccId!,
        frequency:   repoFrequency,
        interval:    1,
        startDate:   startDT,
        payeeName:   _payeeNameCtrl.text.trim().isNotEmpty ? _payeeNameCtrl.text.trim() : null,
        payeeAccount: _payeeAccountCtrl.text.trim().isNotEmpty ? _payeeAccountCtrl.text.trim() : null,
      );

      await NotificationService.instance.scheduleRecurringReminders(newTx);
      developer.log('✅ Notificaciones programadas: ${newTx.description}',
          name: 'AddRecurringScreen');

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: '${_type == 'Gasto' ? 'Gasto' : 'Ingreso'} fijo activado.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 Error al guardar: $e', name: 'AddRecurringScreen');
      if (mounted) {
        HapticFeedback.vibrate();
        NotificationHelper.show(
          message: 'Error: ${e.toString().replaceFirst("Exception: ", "")}',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Algunas frecuencias personalizadas deben mapearse si el repo las espera distintas
  String _mapFrequencyToRepo(String id) {
    // Ajusta este mapa según lo que acepte tu RecurringRepository
    const map = {
      'diario':         'diario',
      'semanal':        'semanal',
      'cada_2_semanas': 'semanal',    // fallback si no soporta
      'quincenal':      'quincenal',
      'mensual':        'mensual',
      'bimestral':      'bimestral',    // fallback
      'trimestral':     'trimestral',    // fallback
      'semestral':      'semestral',    // fallback
      'anual':          'anual',    // fallback
    };
    return id;
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = _C(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:     c.isDark ? Brightness.dark  : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ──────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                leading: _BackButton(c: c),
                title: Text(
                  'Nuevo ${_type == 'Gasto' ? 'gasto' : 'ingreso'} fijo',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600,
                    color: c.label, letterSpacing: -0.2,
                  ),
                ),
              ),

              // ── Selector de tipo ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      _C.md, 0, _C.md, 0),
                  child: _TypeSelector(
                    type: _type,
                    onChanged: _setType,
                    c: c,
                  ),
                ),
              ),

              // ── Formulario ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    _C.md, _C.md, _C.md, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // Campo de descripción
                    _FormSection(
                      label: 'Descripción',
                      c: c,
                      child: _FormField(
                        controller: _descriptionCtrl,
                        focusNode: _descriptionFocus,
                        hint: _type == 'Gasto'
                            ? 'Netflix, Alquiler, Gimnasio…'
                            : 'Salario, Freelance, Dividendos…',
                        icon: Iconsax.document_text,
                        accentColor: _typeColor,
                        c: c,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _amountFocus.requestFocus(),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Requerido' : null,
                      ),
                    ),

                    const SizedBox(height: _C.md),
                    // 👈 NUEVO: Selector de Categorías ───────────────────────────
                    _FormSection(
                      label: _selectedCategory != null
                          ? 'Categoría  ·  ${_selectedCategory!.name}'
                          : 'Categoría',
                      c: c,
                      child: FutureBuilder<List<Category>>(
                        future: _categoriesFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return _FieldSkeleton(c: c);
                          }
                          
                          final allCategories = snap.data ?? [];
                          final targetType = _type == 'Gasto' ? CategoryType.expense : CategoryType.income;
                          final filtered = allCategories.where((cat) => cat.type == targetType).toList();

                          if (filtered.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(_C.md),
                              decoration: BoxDecoration(
                                color: c.surface,
                                borderRadius: BorderRadius.circular(_C.rXL),
                                border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
                              ),
                              child: Text('No tienes categorías creadas para este tipo.',
                                style: TextStyle(color: c.label3, fontSize: 13)),
                            );
                          }

                          // Componente tipo Wrap estilo "Píldoras" (Chips)
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(_C.sm),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(_C.rXL),
                              border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
                            ),
                            child: Wrap(
                              spacing: _C.xs,
                              runSpacing: _C.xs,
                              children: filtered.map((cat) {
                                final isSelected = _selectedCategory?.id == cat.id;
                                final catColor = cat.colorAsObject;

                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedCategory = isSelected ? null : cat;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: _C.fast,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? catColor.withOpacity(0.15) : c.raised,
                                      borderRadius: BorderRadius.circular(_C.rSM + 4),
                                      border: Border.all(
                                        color: isSelected ? catColor.withOpacity(0.6) : c.sep.withOpacity(0.4),
                                        width: isSelected ? 1.5 : 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          Icon(cat.icon ?? Iconsax.category, size: 14, color: catColor),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          cat.name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected ? catColor : c.label2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: _C.md),
                    // Campo de monto — con proyección contextual en tiempo real
                    _FormSection(
                      label: 'Monto',
                      c: c,
                      trailing: _rawAmount > 0
                          ? _ProjectionBadge(
                              monthly: _monthlyAmount,
                              yearly: _yearlyAmount,
                              type: _type,
                              c: c,
                              color: _typeColor,
                            )
                          : null,
                      child: _AmountField(
                        controller: _amountCtrl,
                        focusNode: _amountFocus,
                        accentColor: _typeColor,
                        c: c,
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    // Selector de cuenta
                    _FormSection(
                      label: 'Cuenta',
                      c: c,
                      child: FutureBuilder<List<Account>>(
                        future: _accountsFuture,
                        builder: (_, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return _FieldSkeleton(c: c);
                          }
                          if (!snap.hasData || snap.data!.isEmpty) {
                            return _NoAccountsWarning(c: c);
                          }
                          return _AccountPicker(
                            accounts: snap.data!,
                            selectedId: _selectedAccId,
                            accentColor: _typeColor,
                            c: c,
                            onChanged: (id) => setState(() {
                              _selectedAccId = id;
                              _selectedAcc   = snap.data!
                                  .firstWhere((a) => a.id == id);
                            }),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: _C.md),
// 👈 NUEVO: A quién pagar (Nombre / Entidad)
                    _FormSection(
                      label: 'A quién se paga (Opcional)',
                      c: c,
                      child: _FormField(
                        controller: _payeeNameCtrl,
                        focusNode: _payeeNameFocus,
                        hint: 'Persona, empresa o entidad...',
                        icon: Iconsax.user,
                        accentColor: _typeColor,
                        c: c,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _payeeAccountFocus.requestFocus(),
                        // Botón para agenda de contactos integrado elegantemente
                        suffixIcon: IconButton(
                          icon: Icon(Iconsax.book_saved, color: _typeColor, size: 20),
                          onPressed: _pickContact,
                          tooltip: 'Buscar en contactos',
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    // 👈 NUEVO: A dónde pagar (Número de cuenta)
                    _FormSection(
                      label: 'Cuenta destino / Referencia (Opcional)',
                      c: c,
                      child: _FormField(
                        controller: _payeeAccountCtrl,
                        focusNode: _payeeAccountFocus,
                        hint: 'Nº de cuenta, teléfono, alias...',
                        icon: Iconsax.bank,
                        accentColor: _typeColor,
                        c: c,
                        textCapitalization: TextCapitalization.none,
                      ),
                    ),

                    const SizedBox(height: _C.md),
                    // Selector de frecuencia — el más visual de la pantalla
                    _FormSection(
                      label: 'Frecuencia',
                      c: c,
                      child: _FrequencyPicker(
                        selectedId: _frequencyId,
                        rawAmount: _rawAmount,
                        accentColor: _typeColor,
                        c: c,
                        onChanged: (id) => setState(() => _frequencyId = id),
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    // Fecha y hora — dos campos en una fila
                    _FormSection(
                      label: 'Inicio y recordatorio',
                      c: c,
                      child: Row(
                        children: [
                          Expanded(
                            child: _DateTimeTile(
                              icon: Iconsax.calendar_1,
                              title: DateFormat('d MMM yyyy', 'es_CO')
                                  .format(_startDate),
                              subtitle: 'Primera ejecución',
                              accentColor: _typeColor,
                              c: c,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: _C.sm),
                          Expanded(
                            child: _DateTimeTile(
                              icon: Iconsax.clock,
                              title: MaterialLocalizations.of(context)
                                  .formatTimeOfDay(_notifTime),
                              subtitle: 'Recordatorio',
                              accentColor: _typeColor,
                              c: c,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    // Tarjeta de impacto — aparece solo cuando hay monto
                    AnimatedSize(
                      duration: _C.mid,
                      curve: _C.easeOut,
                      child: _rawAmount > 0 && _selectedAcc != null
                          ? _ImpactCard(
                              type: _type,
                              monthly: _monthlyAmount,
                              yearly: _yearlyAmount,
                              account: _selectedAcc!,
                              freqId: _frequencyId,
                              rawAmount: _rawAmount,
                              accentColor: _typeColor,
                              c: c,
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: _C.xl),

                    // Botón guardar
                    _SaveButton(
                      isLoading: _isLoading,
                      type: _type,
                      color: _typeColor,
                      c: c,
                      onTap: _save,
                    ),

                    // Espacio para el teclado
                    SizedBox(
                        height: _C.xl +
                            MediaQuery.of(context).padding.bottom),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SELECTOR DE TIPO ────────────────────────────────────────────────────────
// Segmented control iOS. El color cambia con animación.
// Es la primera decisión del usuario — grande, clara.
class _TypeSelector extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;
  final _C c;

  const _TypeSelector({
    required this.type, required this.onChanged, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: _C.md),
      decoration: BoxDecoration(
        color: c.sep.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _TypeTab(
            label: 'Gasto',
            icon: Iconsax.card_remove,
            isSelected: type == 'Gasto',
            color: _C.red,
            c: c,
            onTap: () => onChanged('Gasto'),
          ),
          _TypeTab(
            label: 'Ingreso',
            icon: Iconsax.card_tick,
            isSelected: type == 'Ingreso',
            color: _C.green,
            c: c,
            onTap: () => onChanged('Ingreso'),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final _C c;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label, required this.icon, required this.isSelected,
    required this.color, required this.c, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _C.mid,
          curve: _C.easeOut,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withOpacity(c.isDark ? 0.28 : 0.06),
                blurRadius: 6, offset: const Offset(0, 1),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: _C.fast,
                child: Icon(
                  icon,
                  key: ValueKey(isSelected),
                  size: 17,
                  color: isSelected ? color : c.label3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? color : c.label3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SECCIÓN DE FORMULARIO ────────────────────────────────────────────────────
// Label encima, campo abajo. El trailing es para el badge de proyección.
class _FormSection extends StatelessWidget {
  final String label;
  final Widget child;
  final _C c;
  final Widget? trailing;

  const _FormSection({
    required this.label, required this.child, required this.c, this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: _C.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: c.label3, letterSpacing: 0.1,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

// ─── CAMPO DE FORMULARIO ─────────────────────────────────────────────────────
class _FormField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final _C c;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final Widget? suffixIcon; // 👈 NUEVO PARÁMETRO

  const _FormField({
    required this.controller, required this.focusNode, required this.hint,
    required this.icon, required this.accentColor, required this.c,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted, this.validator,
    this.suffixIcon,
  });

  @override
  State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
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
              ? widget.accentColor.withOpacity(0.5)
              : c.sep.withOpacity(0.4),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: _focused ? [
          BoxShadow(
            color: widget.accentColor.withOpacity(c.isDark ? 0.12 : 0.08),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ] : [
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
            blurRadius: 5, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        textCapitalization: widget.textCapitalization,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
        style: TextStyle(fontSize: 16, color: c.label, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: c.label4, fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Icon(widget.icon,
                color: _focused ? widget.accentColor : c.label4, size: 20),
          ),
          suffixIcon: widget.suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: _C.md, vertical: 15),
          errorStyle: const TextStyle(height: 0),
        ),
      ),
    );
  }
}

// ─── CAMPO DE MONTO ───────────────────────────────────────────────────────────
// El monto es grande. Es el número más importante del formulario.
// Sin prefijo de texto extra — el símbolo en el ícono es suficiente.
class _AmountField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accentColor;
  final _C c;

  const _AmountField({
    required this.controller, required this.focusNode,
    required this.accentColor, required this.c,
  });

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
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
              ? widget.accentColor.withOpacity(0.5)
              : c.sep.withOpacity(0.4),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? widget.accentColor.withOpacity(c.isDark ? 0.10 : 0.06)
                : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
            blurRadius: _focused ? 12 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w800,
          color: c.label, letterSpacing: -0.5,
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return '';
          final n = double.tryParse(v.replaceAll(',', '.'));
          if (n == null) return '';
          if (n <= 0) return '';
          return null;
        },
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: c.label4, letterSpacing: -0.5),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4, right: 2),
            child: Icon(Iconsax.money_4,
                color: _focused ? widget.accentColor : c.label4, size: 20),
          ),
          prefixText: '\$ ',
          prefixStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: _focused ? widget.accentColor : c.label3,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: _C.md, vertical: 16),
          errorStyle: const TextStyle(height: 0),
        ),
      ),
    );
  }
}

// ─── BADGE DE PROYECCIÓN ──────────────────────────────────────────────────────
// Aparece al lado del label "Monto" cuando hay un valor.
// Muestra /mes y /año sin que el usuario tenga que calcular.
class _ProjectionBadge extends StatelessWidget {
  final double monthly;
  final double yearly;
  final String type;
  final _C c;
  final Color color;

  const _ProjectionBadge({
    required this.monthly, required this.yearly, required this.type,
    required this.c, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(c.isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(_C.rSM),
      ),
      child: Text(
        '${compact.format(monthly)}/mes · ${compact.format(yearly)}/año',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─── SELECTOR DE CUENTA ───────────────────────────────────────────────────────
class _AccountPicker extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedId;
  final Color accentColor;
  final _C c;
  final ValueChanged<String> onChanged;

  const _AccountPicker({
    required this.accounts, required this.selectedId, required this.accentColor,
    required this.c, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final balanceFmt = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 5, offset: const Offset(0, 1)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: selectedId ?? accounts.first.id,
            isExpanded: true,
            borderRadius: BorderRadius.circular(_C.rXL),
            dropdownColor: c.surface,
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: c.label3, size: 20),
            padding: const EdgeInsets.symmetric(
                horizontal: _C.md, vertical: _C.sm),
            items: accounts.map((acc) => DropdownMenuItem(
              value: acc.id,
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: accentColor.withOpacity(c.isDark ? 0.18 : 0.09),
                      borderRadius: BorderRadius.circular(_C.rSM)),
                  child: Icon(Iconsax.wallet_3, size: 17, color: accentColor),
                ),
                const SizedBox(width: _C.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(acc.name,
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w600, color: c.label)),
                      Text(
                        'Saldo: ${balanceFmt.format(acc.balance)}',
                        style: TextStyle(fontSize: 12, color: c.label3),
                      ),
                    ],
                  ),
                ),
              ]),
            )).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    );
  }
}

// ─── SELECTOR DE FRECUENCIA ───────────────────────────────────────────────────
// La decisión más visual. Cada chip muestra:
//   • Nombre de la frecuencia
//   • Coste mensual equivalente (cuando hay monto)
// Así el usuario ve el impacto real SIN calcular.
class _FrequencyPicker extends StatelessWidget {
  final String selectedId;
  final double rawAmount;
  final Color accentColor;
  final _C c;
  final ValueChanged<String> onChanged;

  const _FrequencyPicker({
    required this.selectedId, required this.rawAmount, required this.accentColor,
    required this.c, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 5, offset: const Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(_C.md),
      child: Wrap(
        spacing: _C.sm,
        runSpacing: _C.sm,
        children: _frequencies.map((freq) {
          final isSelected = freq.id == selectedId;
          final monthly    = rawAmount > 0 ? rawAmount * freq.perMonth : 0.0;
          final compact    = NumberFormat.compactCurrency(
              locale: 'es_CO', symbol: '\$', decimalDigits: 0);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(freq.id);
            },
            child: AnimatedContainer(
              duration: _C.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withOpacity(c.isDark ? 0.22 : 0.12)
                    : c.raised,
                borderRadius: BorderRadius.circular(_C.rMD),
                border: Border.all(
                  color: isSelected
                      ? accentColor.withOpacity(c.isDark ? 0.45 : 0.30)
                      : c.sep.withOpacity(0.3),
                  width: isSelected ? 1.0 : 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        freq.icon,
                        size: 13,
                        color: isSelected ? accentColor : c.label3,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        freq.shortLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? accentColor : c.label2,
                        ),
                      ),
                    ],
                  ),
                  // Coste mensual equivalente — la info que cambia la decisión
                  if (rawAmount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${compact.format(monthly)}/mes',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: isSelected
                            ? accentColor.withOpacity(0.8) : c.label4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── TILE DE FECHA/HORA ───────────────────────────────────────────────────────
// Compacto. Dos en una fila. Sin padding excesivo.
class _DateTimeTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final _C c;
  final VoidCallback onTap;

  const _DateTimeTile({
    required this.icon, required this.title, required this.subtitle,
    required this.accentColor, required this.c, required this.onTap,
  });

  @override
  State<_DateTimeTile> createState() => _DateTimeTileState();
}

class _DateTimeTileState extends State<_DateTimeTile> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) { setState(() => _pressing = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: _pressing ? c.raised : c.surface,
          borderRadius: BorderRadius.circular(_C.rLG),
          border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
                blurRadius: 5, offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(widget.icon, size: 15, color: widget.accentColor),
              const SizedBox(width: 5),
              Text(widget.subtitle,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                      color: c.label3, letterSpacing: 0.1)),
            ]),
            const SizedBox(height: 4),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: c.label, letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TARJETA DE IMPACTO ───────────────────────────────────────────────────────
// Sin gradiente. Sin borde doble. Sin "Análisis Inteligente" con ícono estrella.
// Solo la información que el usuario necesita en ese momento.
class _ImpactCard extends StatelessWidget {
  final String type;
  final double monthly;
  final double yearly;
  final Account account;
  final String freqId;
  final double rawAmount;
  final Color accentColor;
  final _C c;

  const _ImpactCard({
    required this.type, required this.monthly, required this.yearly,
    required this.account, required this.freqId, required this.rawAmount,
    required this.accentColor, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final compact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final isGasto = type == 'Gasto';

    // Balance proyectado a 3 meses
    final projected3m = isGasto
        ? account.balance - (monthly * 3)
        : account.balance + (monthly * 3);

    final impactPct = account.balance > 0
        ? (monthly / account.balance * 100).clamp(0.0, 100.0)
        : 0.0;
    final isHighImpact = impactPct > 10;

    final freq = _freqById(freqId);

    return Container(
      padding: const EdgeInsets.all(_C.md + 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(
            color: accentColor.withOpacity(0.12), width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la tarjeta
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: accentColor.withOpacity(c.isDark ? 0.18 : 0.09),
                  borderRadius: BorderRadius.circular(_C.rSM + 2)),
              child: Icon(Iconsax.chart_21, size: 16, color: accentColor),
            ),
            const SizedBox(width: _C.sm + 2),
            Text(
              'Impacto en tus finanzas',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: c.label, letterSpacing: -0.2),
            ),
          ]),

          const SizedBox(height: _C.md),
          Container(height: 0.5, color: c.sep),
          const SizedBox(height: _C.md),

          // Alerta de alto impacto — solo cuando corresponde
          if (isHighImpact) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: _C.md, vertical: 10),
              margin: const EdgeInsets.only(bottom: _C.md),
              decoration: BoxDecoration(
                color: _C.orange.withOpacity(c.isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(_C.rMD),
                border: Border.all(
                    color: _C.orange.withOpacity(0.25), width: 0.5),
              ),
              child: Row(children: [
                const Icon(Iconsax.warning_2,
                    color: _C.orange, size: 16),
                const SizedBox(width: _C.sm),
                Expanded(
                  child: Text(
                    'Representa el ${impactPct.toStringAsFixed(1)}% del saldo de tu cuenta',
                    style: TextStyle(fontSize: 12, color: c.label2,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ],

          // Tres métricas en filas limpias
          _ImpactRow(
            icon: Iconsax.repeat,
            label: 'Por cada ${freq.label.toLowerCase()}',
            value: compact.format(rawAmount),
            color: accentColor, c: c,
          ),
          _ImpactDivider(c: c),
          _ImpactRow(
            icon: Iconsax.calendar_tick,
            label: 'Proyección anual',
            value: compact.format(yearly),
            color: accentColor, c: c,
          ),
          _ImpactDivider(c: c),
          _ImpactRow(
            icon: Iconsax.wallet_money,
            label: 'Saldo proyectado en 3 meses',
            value: fmt.format(projected3m),
            color: projected3m >= 0 ? _C.green : _C.red,
            c: c,
            subtitle: account.name,
          ),

          const SizedBox(height: _C.md),

          // Barra de impacto en cuenta — visual rápido
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Impacto mensual',
                          style: TextStyle(fontSize: 11, color: c.label3)),
                      Text('${impactPct.toStringAsFixed(1)}% del saldo',
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w600, color: accentColor)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: impactPct / 100,
                      minHeight: 5,
                      backgroundColor:
                          accentColor.withOpacity(c.isDark ? 0.18 : 0.09),
                      valueColor: AlwaysStoppedAnimation(accentColor),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final _C c;
  final String? subtitle;

  const _ImpactRow({
    required this.icon, required this.label, required this.value,
    required this.color, required this.c, this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: _C.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 13, color: c.label3)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(fontSize: 11, color: c.label4)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: color, letterSpacing: -0.3),
        ),
      ]),
    );
  }
}

class _ImpactDivider extends StatelessWidget {
  final _C c;
  const _ImpactDivider({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: c.sep.withOpacity(0.5));
  }
}

// ─── BOTÓN GUARDAR ────────────────────────────────────────────────────────────
// El único CTA primario. Grande, sólido, sin gradiente.
// La sombra es del color — igual que los botones de iOS App Store.
class _SaveButton extends StatefulWidget {
  final bool isLoading;
  final String type;
  final Color color;
  final _C c;
  final VoidCallback onTap;

  const _SaveButton({
    required this.isLoading, required this.type, required this.color,
    required this.c, required this.onTap,
  });

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressing = true),
      onTapUp: disabled ? null : (_) {
        setState(() => _pressing = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: _C.fast,
          height: 56,
          decoration: BoxDecoration(
            color: disabled ? widget.c.label4 : widget.color,
            borderRadius: BorderRadius.circular(_C.rXL),
            boxShadow: disabled ? null : [
              BoxShadow(
                color: widget.color.withOpacity(_pressing ? 0.2 : 0.35),
                blurRadius: _pressing ? 8 : 18,
                offset: Offset(0, _pressing ? 2 : 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: disabled
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.tick_circle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: _C.sm + 2),
                    Text(
                      'Confirmar y activar',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w700, letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── BOTÓN ATRÁS ─────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final _C c;
  const _BackButton({required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.raised,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            size: 16, color: c.label),
      ),
    );
  }
}

// ─── ESTADOS AUXILIARES ───────────────────────────────────────────────────────
class _FieldSkeleton extends StatelessWidget {
  final _C c;
  const _FieldSkeleton({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
          color: c.surface, borderRadius: BorderRadius.circular(_C.rXL)),
      alignment: Alignment.center,
      child: SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.label4),
      ),
    );
  }
}

class _NoAccountsWarning extends StatelessWidget {
  final _C c;
  const _NoAccountsWarning({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: _C.orange.withOpacity(c.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(_C.rLG),
        border: Border.all(color: _C.orange.withOpacity(0.25), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Iconsax.warning_2, color: _C.orange, size: 18),
        const SizedBox(width: _C.sm),
        Expanded(
          child: Text(
            'Crea una cuenta primero para continuar',
            style: TextStyle(fontSize: 13, color: c.label2,
                fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }
}