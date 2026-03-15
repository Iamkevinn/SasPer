// lib/screens/edit_recurring_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;
import 'package:flutter_contacts/flutter_contacts.dart' hide Account;


// ─── TOKENS DE DISEÑO ────────────────────────────────────────────────────────
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
class _Freq {
  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final double perMonth;
  final double perYear;

  const _Freq({
    required this.id, required this.label, required this.shortLabel,
    required this.icon, required this.perMonth, required this.perYear,
  });
}

const List<_Freq> _frequencies =[
  _Freq(id: 'diario',        label: 'Diario',          shortLabel: 'Diario',     icon: Iconsax.sun_1,           perMonth: 30.41, perYear: 365),
  _Freq(id: 'semanal',       label: 'Semanal',         shortLabel: 'Semanal',    icon: Iconsax.calendar_1,      perMonth: 4.33,  perYear: 52),
  _Freq(id: 'cada_2_semanas',label: 'Cada 2 semanas',  shortLabel: '2 semanas',  icon: Iconsax.calendar_2,      perMonth: 2.17,  perYear: 26),
  _Freq(id: 'quincenal',     label: 'Quincenal',       shortLabel: 'Quincenal',  icon: Iconsax.calendar,        perMonth: 2,     perYear: 24),
  _Freq(id: 'mensual',       label: 'Mensual',         shortLabel: 'Mensual',    icon: Iconsax.calendar_tick,   perMonth: 1,     perYear: 12),
  _Freq(id: 'bimestral',     label: 'Bimestral',       shortLabel: 'Bimestral',  icon: Iconsax.calendar_remove, perMonth: 0.5,   perYear: 6),
  _Freq(id: 'trimestral',    label: 'Trimestral',      shortLabel: 'Trimestral', icon: Iconsax.chart_1,         perMonth: 0.33,  perYear: 4),
  _Freq(id: 'semestral',     label: 'Semestral',       shortLabel: 'Semestral',  icon: Iconsax.chart_21,        perMonth: 0.17,  perYear: 2),
  _Freq(id: 'anual',         label: 'Anual',           shortLabel: 'Anual',      icon: Iconsax.star,            perMonth: 0.083, perYear: 1),
];

_Freq _freqById(String id) =>
    _frequencies.firstWhere((f) => f.id == id, orElse: () => _frequencies[4]);

// ─── PANTALLA PRINCIPAL ──────────────────────────────────────────────────────
class EditRecurringTransactionScreen extends StatefulWidget {
  final RecurringTransaction transaction;

  const EditRecurringTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditRecurringTransactionScreen> createState() => _EditRecurringTransactionScreenState();
}

class _EditRecurringTransactionScreenState extends State<EditRecurringTransactionScreen>
    with SingleTickerProviderStateMixin {
  final RecurringRepository _repository = RecurringRepository.instance;
  final AccountRepository _accountRepo = AccountRepository.instance;
  final CategoryRepository _categoryRepo = CategoryRepository.instance;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _amountCtrl;
  final _descriptionFocus = FocusNode();
  final _amountFocus = FocusNode();
  
  late String _type;
  late String _frequencyId;
  String? _selectedAccId;
  Account? _selectedAcc;
  Category? _selectedCategory;
  
  late DateTime _nextDueDate;
  late TimeOfDay _notifTime;
  
  bool _isLoading = false;
  bool _hasChanges = false;
  late Future<List<Account>> _accountsFuture;
  late Future<List<Category>> _categoriesFuture;

  late AnimationController _typeCtrl;
  late Animation<double> _typeAnim;

  late final TextEditingController _payeeNameCtrl;
  late final TextEditingController _payeeAccountCtrl;
  final _payeeNameFocus = FocusNode();
  final _payeeAccountFocus = FocusNode();

  Color get _typeColor => _type == 'Gasto' ? _C.red : _C.green;

  double get _rawAmount => double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _monthlyAmount => _rawAmount * _freqById(_frequencyId).perMonth;
  double get _yearlyAmount => _rawAmount * _freqById(_frequencyId).perYear;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    
    _descriptionCtrl = TextEditingController(text: t.description);
    _amountCtrl = TextEditingController(text: t.amount.toStringAsFixed(2).replaceAll('.00', ''));
    // 👈 NUEVO: Inicializar con los datos existentes
    _payeeNameCtrl = TextEditingController(text: t.payeeName ?? '');
    _payeeAccountCtrl = TextEditingController(text: t.payeeAccount ?? '');
    _type = t.type;
    _frequencyId = t.frequency;
    _selectedAccId = t.accountId;
    _nextDueDate = t.nextDueDate;
    
    _notifTime = TimeOfDay(hour: t.nextDueDate.hour, minute: t.nextDueDate.minute);

    _accountsFuture = _accountRepo.getAccounts();
    _categoriesFuture = _categoryRepo.getCategories();

    // Auto-seleccionar cuenta actual
    _accountsFuture.then((accounts) {
      if (mounted) {
        setState(() {
          _selectedAcc = accounts.cast<Account?>().firstWhere(
            (a) => a?.id == _selectedAccId, orElse: () => null
          );
        });
      }
    });

    // Auto-seleccionar categoría actual
    _categoriesFuture.then((categories) {
      if (mounted) {
        setState(() {
          _selectedCategory = categories.cast<Category?>().firstWhere(
            (c) => c?.name == t.category && c?.type.name == (_type == 'Gasto' ? 'expense' : 'income'), 
            orElse: () => null
          );
        });
      }
    });

    _typeCtrl = AnimationController(
      vsync: this, 
      duration: _C.mid,
      value: _type == 'Gasto' ? 1.0 : 0.0,
    );
    _typeAnim = CurvedAnimation(parent: _typeCtrl, curve: _C.easeOut);

    _descriptionCtrl.addListener(_markAsChanged);
    _amountCtrl.addListener(_markAsChanged);
    // 👈 NUEVO: Escuchar cambios para habilitar el botón de guardar
    _payeeNameCtrl.addListener(_markAsChanged);
    _payeeAccountCtrl.addListener(_markAsChanged);
  }

  void _markAsChanged() {
    if (!_hasChanges && mounted) setState(() => _hasChanges = true);
    // Para actualizar la proyección
    setState(() {});
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _payeeNameCtrl.dispose(); // 👈 NUEVO
    _payeeAccountCtrl.dispose(); // 👈 NUEVO
    _descriptionFocus.dispose();
    _amountFocus.dispose();
    _payeeNameFocus.dispose(); // 👈 NUEVO
    _payeeAccountFocus.dispose(); // 👈 NUEVO
    _typeCtrl.dispose();
    super.dispose();
  }

  // 👈 NUEVO: Método para elegir de la agenda
  Future<void> _pickContact() async {
    HapticFeedback.lightImpact();
    try {
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          setState(() {
            _payeeNameCtrl.text = contact.displayName;
            _hasChanges = true;
          });
          HapticFeedback.selectionClick();
          _payeeAccountFocus.requestFocus();
        }
      } else {
        NotificationHelper.show(
          message: 'Permiso de contactos denegado.', 
          type: NotificationType.warning
        );
      }
    } catch (e) {
      developer.log('Error abriendo contactos: $e', name: 'EditRecurringScreen');
    }
  }

  void _setType(String t) {
    if (t == _type) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = t;
      _selectedCategory = null;
      _hasChanges = true;
    });
    t == 'Gasto' ? _typeCtrl.forward() : _typeCtrl.reverse();
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _typeColor),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _nextDueDate) {
      setState(() {
        _nextDueDate = DateTime(picked.year, picked.month, picked.day, _notifTime.hour, _notifTime.minute);
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _typeColor),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _notifTime) {
      setState(() {
        _notifTime = picked;
        _nextDueDate = DateTime(_nextDueDate.year, _nextDueDate.month, _nextDueDate.day, picked.hour, picked.minute);
        _hasChanges = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedAccId == null || _selectedCategory == null) {
      HapticFeedback.vibrate();
      NotificationHelper.show(
        message: 'Completa todos los campos y selecciona una categoría.',
        type: NotificationType.error,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final updatedTransaction = widget.transaction.copyWith(
        description: _descriptionCtrl.text.trim(),
        amount: double.parse(_amountCtrl.text.replaceAll(',', '.')),
        type: _type,
        category: _selectedCategory!.name,
        accountId: _selectedAccId,
        frequency: _frequencyId,
        nextDueDate: _nextDueDate,
        // 👈 NUEVO: Guardar los cambios (o borrarlos si los dejó vacíos)
        payeeName: _payeeNameCtrl.text.trim().isEmpty ? "" : _payeeNameCtrl.text.trim(),
        payeeAccount: _payeeAccountCtrl.text.trim().isEmpty ? "" : _payeeAccountCtrl.text.trim(),
      );

      await _repository.updateRecurringTransaction(updatedTransaction);
      await NotificationService.instance.cancelRecurringReminders(widget.transaction.id);
      await NotificationService.instance.scheduleRecurringReminders(updatedTransaction);
      
      developer.log('✅ Notificaciones reprogramadas: ${updatedTransaction.description}', name: 'EditRecurringScreen');

      if (mounted) {
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Gasto fijo actualizado.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 Error: $e', name: 'EditRecurringScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al actualizar.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _C(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers:[
              // ── App Bar ──────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: c.bg,
                surfaceTintColor: Colors.transparent,
                leading: _BackButton(c: c),
                title: Text(
                  'Editar ${_type == 'Gasto' ? 'gasto' : 'ingreso'} fijo',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600,
                    color: c.label, letterSpacing: -0.2,
                  ),
                ),
              ),

              // ── Selector de tipo ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_C.md, 0, _C.md, 0),
                  child: _TypeSelector(
                    type: _type,
                    onChanged: _setType,
                    c: c,
                  ),
                ),
              ),

              // ── Formulario ────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_C.md, _C.md, _C.md, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    _FormSection(
                      label: 'Descripción', c: c,
                      child: _FormField(
                        controller: _descriptionCtrl,
                        focusNode: _descriptionFocus,
                        hint: 'Ej: Netflix, Gimnasio...',
                        icon: Iconsax.document_text,
                        accentColor: _typeColor, c: c,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _amountFocus.requestFocus(),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    // Selector de Categorías (Igual que en Add)
                    _FormSection(
                      label: _selectedCategory != null ? 'Categoría  ·  ${_selectedCategory!.name}' : 'Categoría',
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
                                      _hasChanges = true;
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

                    _FormSection(
                      label: 'Monto', c: c,
                      trailing: _rawAmount > 0 ? _ProjectionBadge(
                        monthly: _monthlyAmount, yearly: _yearlyAmount,
                        color: _typeColor, c: c) : null,
                      child: _AmountField(
                        controller: _amountCtrl,
                        focusNode: _amountFocus,
                        accentColor: _typeColor, c: c,
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    _FormSection(
                      label: 'Cuenta', c: c,
                      child: FutureBuilder<List<Account>>(
                        future: _accountsFuture,
                        builder: (_, snap) {
                          if (!snap.hasData) return _FieldSkeleton(c: c);
                          return _AccountPicker(
                            accounts: snap.data!,
                            selectedId: _selectedAccId,
                            accentColor: _typeColor, c: c,
                            onChanged: (id) => setState(() {
                              _selectedAccId = id;
                              _selectedAcc = snap.data!.firstWhere((a) => a.id == id);
                              _hasChanges = true;
                            }),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    // 👈 NUEVO: A quién pagar (Edición)
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

                    // 👈 NUEVO: Cuenta destino (Edición)
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
                    
                    _FormSection(
                      label: 'Frecuencia', c: c,
                      child: _FrequencyPicker(
                        selectedId: _frequencyId,
                        rawAmount: _rawAmount,
                        accentColor: _typeColor, c: c,
                        onChanged: (id) => setState(() {
                          _frequencyId = id;
                          _hasChanges = true;
                        }),
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    _FormSection(
                      label: 'Próxima ejecución y aviso', c: c,
                      child: Row(
                        children:[
                          Expanded(
                            child: _DateTimeTile(
                              icon: Iconsax.calendar_1,
                              title: DateFormat('d MMM yyyy', 'es_CO').format(_nextDueDate),
                              subtitle: 'Siguiente cobro',
                              accentColor: _typeColor, c: c,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: _C.sm),
                          Expanded(
                            child: _DateTimeTile(
                              icon: Iconsax.clock,
                              title: _notifTime.format(context),
                              subtitle: 'Recordatorio',
                              accentColor: _typeColor, c: c,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: _C.md),

                    AnimatedSize(
                      duration: _C.mid, curve: _C.easeOut,
                      child: _rawAmount > 0 && _selectedAcc != null
                          ? _ImpactCard(
                              type: _type, monthly: _monthlyAmount, yearly: _yearlyAmount,
                              account: _selectedAcc!, freqId: _frequencyId, rawAmount: _rawAmount,
                              accentColor: _typeColor, c: c,
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: _C.xl),

                    _SaveButton(
                      isLoading: _isLoading,
                      hasChanges: _hasChanges,
                      color: _typeColor, c: c,
                      onTap: _save, type: '${_type == 'Gasto' ? 'gasto' : 'ingreso'} fijo',
                    ),

                    SizedBox(height: _C.xl + MediaQuery.of(context).padding.bottom),
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

// ─── COMPONENTES COMPARTIDOS iOS ─────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final String type;
  final ValueChanged<String> onChanged;
  final _C c;

  const _TypeSelector({required this.type, required this.onChanged, required this.c});

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
        children:[
          _TypeTab(
            label: 'Gasto', icon: Iconsax.card_remove,
            isSelected: type == 'Gasto', color: _C.red, c: c,
            onTap: () => onChanged('Gasto'),
          ),
          _TypeTab(
            label: 'Ingreso', icon: Iconsax.card_tick,
            isSelected: type == 'Ingreso', color: _C.green, c: c,
            onTap: () => onChanged('Ingreso'),
          ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label; final IconData icon; final bool isSelected;
  final Color color; final _C c; final VoidCallback onTap;

  const _TypeTab({required this.label, required this.icon, required this.isSelected, required this.color, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _C.mid, curve: _C.easeOut, margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected ?[BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.28 : 0.06), blurRadius: 6, offset: const Offset(0, 1))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              AnimatedSwitcher(duration: _C.fast, child: Icon(icon, key: ValueKey(isSelected), size: 17, color: isSelected ? color : c.label3)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? color : c.label3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String label; final Widget child; final _C c; final Widget? trailing;

  const _FormSection({required this.label, required this.child, required this.c, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: _C.sm),
          child: Row(
            children:[
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.label3, letterSpacing: 0.1))),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _FormField extends StatefulWidget {
  final TextEditingController controller; final FocusNode focusNode; final String hint;
  final IconData icon; final Color accentColor; final _C c; final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted; final String? Function(String?)? validator;
  final Widget? suffixIcon; 
  const _FormField({required this.controller, required this.focusNode, required this.hint, required this.icon, required this.accentColor, required this.c, this.textCapitalization = TextCapitalization.none, this.onSubmitted, this.validator,this.suffixIcon});
  @override State<_FormField> createState() => _FormFieldState();
}

class _FormFieldState extends State<_FormField> {
  bool _focused = false;
  @override void initState() { super.initState(); widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); }); }
  @override Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedContainer(
      duration: _C.fast,
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: _focused ? widget.accentColor.withOpacity(0.5) : c.sep.withOpacity(0.4), width: _focused ? 1.5 : 0.5),
        boxShadow: _focused ?[BoxShadow(color: widget.accentColor.withOpacity(c.isDark ? 0.12 : 0.08), blurRadius: 10, offset: const Offset(0, 2))] :[BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03), blurRadius: 5, offset: const Offset(0, 1))],
      ),
      child: TextFormField(
        controller: widget.controller, focusNode: widget.focusNode, textCapitalization: widget.textCapitalization, onFieldSubmitted: widget.onSubmitted, validator: widget.validator,
        style: TextStyle(fontSize: 16, color: c.label, fontWeight: FontWeight.w500),
        decoration: InputDecoration(hintText: widget.hint, hintStyle: TextStyle(color: c.label4, fontSize: 15), prefixIcon: Padding(padding: const EdgeInsets.only(left: 2), child: Icon(widget.icon, color: _focused ? widget.accentColor : c.label4, size: 20)), suffixIcon: widget.suffixIcon, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: _C.md, vertical: 15), errorStyle: const TextStyle(height: 0)),
      ),
    );
  }
}

class _AmountField extends StatefulWidget {
  final TextEditingController controller; final FocusNode focusNode; final Color accentColor; final _C c;
  const _AmountField({required this.controller, required this.focusNode, required this.accentColor, required this.c});
  @override State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  bool _focused = false;
  @override void initState() { super.initState(); widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); }); }
  @override Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedContainer(
      duration: _C.fast,
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: _focused ? widget.accentColor.withOpacity(0.5) : c.sep.withOpacity(0.4), width: _focused ? 1.5 : 0.5),
        boxShadow:[BoxShadow(color: _focused ? widget.accentColor.withOpacity(c.isDark ? 0.10 : 0.06) : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03), blurRadius: _focused ? 12 : 5, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: widget.controller, focusNode: widget.focusNode, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.label, letterSpacing: -0.5),
        validator: (v) { if (v == null || v.isEmpty) return ''; final n = double.tryParse(v.replaceAll(',', '.')); if (n == null || n <= 0) return ''; return null; },
        decoration: InputDecoration(hintText: '0', hintStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c.label4, letterSpacing: -0.5), prefixIcon: Padding(padding: const EdgeInsets.only(left: 4, right: 2), child: Icon(Iconsax.money_4, color: _focused ? widget.accentColor : c.label4, size: 20)), prefixText: '\$ ', prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _focused ? widget.accentColor : c.label3), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: _C.md, vertical: 16), errorStyle: const TextStyle(height: 0)),
      ),
    );
  }
}

class _ProjectionBadge extends StatelessWidget {
  final double monthly; final double yearly; final Color color; final _C c;
  const _ProjectionBadge({required this.monthly, required this.yearly, required this.color, required this.c});
  @override Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(c.isDark ? 0.18 : 0.09), borderRadius: BorderRadius.circular(_C.rSM)),
      child: Text('${compact.format(monthly)}/mes · ${compact.format(yearly)}/año', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  final List<Account> accounts; final String? selectedId; final Color accentColor; final _C c; final ValueChanged<String> onChanged;
  const _AccountPicker({required this.accounts, required this.selectedId, required this.accentColor, required this.c, required this.onChanged});
  @override Widget build(BuildContext context) {
    final balanceFmt = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(_C.rXL), border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5), boxShadow:[BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03), blurRadius: 5, offset: const Offset(0, 1))]),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: selectedId ?? accounts.first.id, isExpanded: true, borderRadius: BorderRadius.circular(_C.rXL), dropdownColor: c.surface, icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.label3, size: 20), padding: const EdgeInsets.symmetric(horizontal: _C.md, vertical: _C.sm),
            items: accounts.map((acc) => DropdownMenuItem(value: acc.id, child: Row(children:[Container(width: 36, height: 36, decoration: BoxDecoration(color: accentColor.withOpacity(c.isDark ? 0.18 : 0.09), borderRadius: BorderRadius.circular(_C.rSM)), child: Icon(Iconsax.wallet_3, size: 17, color: accentColor)), const SizedBox(width: _C.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children:[Text(acc.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.label)), Text('Saldo: ${balanceFmt.format(acc.balance)}', style: TextStyle(fontSize: 12, color: c.label3))]))]))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    );
  }
}

class _FrequencyPicker extends StatelessWidget {
  final String selectedId; final double rawAmount; final Color accentColor; final _C c; final ValueChanged<String> onChanged;
  const _FrequencyPicker({required this.selectedId, required this.rawAmount, required this.accentColor, required this.c, required this.onChanged});
  @override Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(_C.rXL), border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5), boxShadow:[BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03), blurRadius: 5, offset: const Offset(0, 1))]),
      padding: const EdgeInsets.all(_C.md),
      child: Wrap(
        spacing: _C.sm, runSpacing: _C.sm,
        children: _frequencies.map((freq) {
          final isSelected = freq.id == selectedId;
          final monthly = rawAmount > 0 ? rawAmount * freq.perMonth : 0.0;
          final compact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
          return GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); onChanged(freq.id); },
            child: AnimatedContainer(
              duration: _C.fast, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: isSelected ? accentColor.withOpacity(c.isDark ? 0.22 : 0.12) : c.raised, borderRadius: BorderRadius.circular(_C.rMD), border: Border.all(color: isSelected ? accentColor.withOpacity(c.isDark ? 0.45 : 0.30) : c.sep.withOpacity(0.3), width: isSelected ? 1.0 : 0.5)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children:[Row(mainAxisSize: MainAxisSize.min, children:[Icon(freq.icon, size: 13, color: isSelected ? accentColor : c.label3), const SizedBox(width: 5), Text(freq.shortLabel, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? accentColor : c.label2))]), if (rawAmount > 0) ...[const SizedBox(height: 2), Text('${compact.format(monthly)}/mes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: isSelected ? accentColor.withOpacity(0.8) : c.label4))]]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DateTimeTile extends StatefulWidget {
  final IconData icon; final String title; final String subtitle; final Color accentColor; final _C c; final VoidCallback onTap;
  const _DateTimeTile({required this.icon, required this.title, required this.subtitle, required this.accentColor, required this.c, required this.onTap});
  @override State<_DateTimeTile> createState() => _DateTimeTileState();
}

class _DateTimeTileState extends State<_DateTimeTile> {
  bool _pressing = false;
  @override Widget build(BuildContext context) {
    final c = widget.c;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true), onTapUp: (_) { setState(() => _pressing = false); widget.onTap(); }, onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80), padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(color: _pressing ? c.raised : c.surface, borderRadius: BorderRadius.circular(_C.rLG), border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5), boxShadow:[BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03), blurRadius: 5, offset: const Offset(0, 1))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children:[Icon(widget.icon, size: 15, color: widget.accentColor), const SizedBox(width: 5), Text(widget.subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.label3, letterSpacing: 0.1))]), const SizedBox(height: 4), Text(widget.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.label, letterSpacing: -0.2))]),
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final String type; final double monthly; final double yearly; final Account account; final String freqId; final double rawAmount; final Color accentColor; final _C c;
  const _ImpactCard({required this.type, required this.monthly, required this.yearly, required this.account, required this.freqId, required this.rawAmount, required this.accentColor, required this.c});
  @override Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final compact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final projected3m = type == 'Gasto' ? account.balance - (monthly * 3) : account.balance + (monthly * 3);
    final impactPct = account.balance > 0 ? (monthly / account.balance * 100).clamp(0.0, 100.0) : 0.0;
    final freq = _freqById(freqId);

    return Container(
      padding: const EdgeInsets.all(_C.md + 2),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(_C.rXL), border: Border.all(color: accentColor.withOpacity(0.12), width: 0.5), boxShadow:[BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children:[Container(width: 34, height: 34, decoration: BoxDecoration(color: accentColor.withOpacity(c.isDark ? 0.18 : 0.09), borderRadius: BorderRadius.circular(_C.rSM + 2)), child: Icon(Iconsax.chart_21, size: 16, color: accentColor)), const SizedBox(width: _C.sm + 2), Text('Impacto en tus finanzas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.label, letterSpacing: -0.2))]), const SizedBox(height: _C.md), Container(height: 0.5, color: c.sep), const SizedBox(height: _C.md), if (impactPct > 10) Container(padding: const EdgeInsets.symmetric(horizontal: _C.md, vertical: 10), margin: const EdgeInsets.only(bottom: _C.md), decoration: BoxDecoration(color: _C.orange.withOpacity(c.isDark ? 0.15 : 0.08), borderRadius: BorderRadius.circular(_C.rMD), border: Border.all(color: _C.orange.withOpacity(0.25), width: 0.5)), child: Row(children:[const Icon(Iconsax.warning_2, color: _C.orange, size: 16), const SizedBox(width: _C.sm), Expanded(child: Text('Representa el ${impactPct.toStringAsFixed(1)}% del saldo.', style: TextStyle(fontSize: 12, color: c.label2, fontWeight: FontWeight.w500)))])), _ImpactRow(icon: Iconsax.repeat, label: 'Por cada ${freq.label.toLowerCase()}', value: compact.format(rawAmount), color: accentColor, c: c), _ImpactDivider(c: c), _ImpactRow(icon: Iconsax.calendar_tick, label: 'Proyección anual', value: compact.format(yearly), color: accentColor, c: c), _ImpactDivider(c: c), _ImpactRow(icon: Iconsax.wallet_money, label: 'Saldo proyectado (3m)', value: fmt.format(projected3m), color: projected3m >= 0 ? _C.green : _C.red, c: c, subtitle: account.name), const SizedBox(height: _C.md), Row(children:[Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text('Impacto mensual', style: TextStyle(fontSize: 11, color: c.label3)), Text('${impactPct.toStringAsFixed(1)}% del saldo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor))]), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: impactPct / 100, minHeight: 5, backgroundColor: accentColor.withOpacity(c.isDark ? 0.18 : 0.09), valueColor: AlwaysStoppedAnimation(accentColor)))]))])]),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color; final _C c; final String? subtitle;
  const _ImpactRow({required this.icon, required this.label, required this.value, required this.color, required this.c, this.subtitle});
  @override Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children:[Icon(icon, size: 16, color: color), const SizedBox(width: _C.sm + 2), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(label, style: TextStyle(fontSize: 13, color: c.label3)), if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 11, color: c.label4))])), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.3))]));
  }
}

class _ImpactDivider extends StatelessWidget {
  final _C c; const _ImpactDivider({required this.c});
  @override Widget build(BuildContext context) => Container(height: 0.5, color: c.sep.withOpacity(0.5));
}

class _SaveButton extends StatefulWidget {
  final bool isLoading; final bool hasChanges; final String type; final Color color; final _C c; final VoidCallback onTap;
  const _SaveButton({required this.isLoading, required this.hasChanges, required this.type, required this.color, required this.c, required this.onTap});
  @override State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _pressing = false;
  @override Widget build(BuildContext context) {
    final disabled = widget.isLoading || !widget.hasChanges;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressing = true), onTapUp: disabled ? null : (_) { setState(() => _pressing = false); widget.onTap(); }, onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0, duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: _C.fast, height: 56,
          decoration: BoxDecoration(color: disabled ? widget.c.label4 : widget.color, borderRadius: BorderRadius.circular(_C.rXL), boxShadow: disabled ? null :[BoxShadow(color: widget.color.withOpacity(_pressing ? 0.2 : 0.35), blurRadius: _pressing ? 8 : 18, offset: Offset(0, _pressing ? 2 : 6))]),
          alignment: Alignment.center,
          child: widget.isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Row(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(widget.hasChanges ? Iconsax.tick_circle : Iconsax.edit, color: Colors.white, size: 20), const SizedBox(width: _C.sm + 2), Text(widget.hasChanges ? 'Guardar Cambios' : 'Sin cambios', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2))]),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final _C c; const _BackButton({required this.c});
  @override Widget build(BuildContext context) {
    return GestureDetector(onTap: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); }, child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle), child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: c.label)));
  }
}

class _FieldSkeleton extends StatelessWidget {
  final _C c; const _FieldSkeleton({required this.c});
  @override Widget build(BuildContext context) => Container(height: 56, decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(_C.rXL)), alignment: Alignment.center, child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: c.label4)));
}

class _NoAccountsWarning extends StatelessWidget {
  final _C c; const _NoAccountsWarning({required this.c});
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(_C.md), decoration: BoxDecoration(color: _C.orange.withOpacity(c.isDark ? 0.15 : 0.08), borderRadius: BorderRadius.circular(_C.rLG), border: Border.all(color: _C.orange.withOpacity(0.25), width: 0.5)), child: Row(children:[const Icon(Iconsax.warning_2, color: _C.orange, size: 18), const SizedBox(width: _C.sm), Expanded(child: Text('Crea una cuenta primero para continuar', style: TextStyle(fontSize: 13, color: c.label2, fontWeight: FontWeight.w500)))]));
  }
}