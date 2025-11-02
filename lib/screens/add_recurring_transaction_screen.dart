// lib/screens/add_recurring_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

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
  final AccountRepository _accountRepository = AccountRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isLoading = false;
  String _type = 'Gasto';
  String _frequency = 'mensual';
  String? _selectedAccountId;
  Account? _selectedAccount;
  late DateTime _startDate;
  final String _category = 'Gastos Fijos';
  late Future<List<Account>> _accountsFuture;

  // Animaciones
  late AnimationController _typeAnimationController;
  // ignore: unused_field
  late Animation<double> _typeAnimation;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    _startDate = DateTime.now();

    // Animación del selector de tipo
    _typeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _typeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _typeAnimationController, curve: Curves.easeInOut),
    );

    // Listener para recalcular impacto
    _amountController.addListener(_recalculateImpact);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _typeAnimationController.dispose();
    super.dispose();
  }

  void _recalculateImpact() {
    if (mounted) setState(() {});
  }

  void _changeType(String newType) {
    if (newType == _type) return;
    setState(() => _type = newType);
    if (newType == 'Gasto') {
      _typeAnimationController.forward();
    } else {
      _typeAnimationController.reverse();
    }
  }

  double get _monthlyAmount {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    switch (_frequency) {
      case 'diario':
        return amount * 30;
      case 'semanal':
        return amount * 4;
      case 'quincenal':
        return amount * 2;
      default:
        return amount;
    }
  }

  double get _yearlyAmount => _monthlyAmount * 12;

  DateTime get _nextPaymentDate {
    switch (_frequency) {
      case 'diario':
        return _startDate.add(const Duration(days: 1));
      case 'semanal':
        return _startDate.add(const Duration(days: 7));
      case 'quincenal':
        return _startDate.add(const Duration(days: 15));
      default:
        return DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      NotificationHelper.show(
        message: 'Por favor, completa todos los campos requeridos.',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newTransaction = await _repository.addRecurringTransaction(
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        type: _type,
        category: _category,
        accountId: _selectedAccountId!,
        frequency: _frequency,
        interval: 1,
        startDate: _startDate,
      );

      await NotificationService.instance
          .scheduleRecurringReminders(newTransaction);
      developer.log('✅ Notificaciones programadas para: ${newTransaction.description}',
          name: 'AddRecurringScreen');

      if (mounted) {
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: '${_type == 'Gasto' ? 'Gasto' : 'Ingreso'} fijo creado correctamente.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL GUARDAR: $e', name: 'AddRecurringScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al guardar: ${e.toString().replaceFirst("Exception: ", "")}',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Color dinámico según tipo
    final accentColor = _type == 'Gasto'
        ? (isDark ? Colors.orange : Colors.deepOrange)
        : (isDark ? Colors.teal : Colors.green);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // HEADER CON SELECTOR DE TIPO
            SliverToBoxAdapter(
              child: _RecurringHeaderSelector(
                type: _type,
                onTypeChanged: _changeType,
                accentColor: accentColor,
              ),
            ),

            // FORMULARIO PRINCIPAL
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Descripción
                  _PremiumTextField(
                    controller: _descriptionController,
                    label: 'Descripción',
                    hint: _type == 'Gasto'
                        ? 'Ej: Netflix, Alquiler, Gimnasio'
                        : 'Ej: Salario, Freelance, Inversión',
                    icon: Iconsax.document_text,
                    accentColor: accentColor,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'La descripción es requerida' : null,
                  ),

                  const SizedBox(height: 20),

                  // Monto con proyección
                  _AmountFieldWithProjection(
                    controller: _amountController,
                    frequency: _frequency,
                    monthlyAmount: _monthlyAmount,
                    yearlyAmount: _yearlyAmount,
                    accentColor: accentColor,
                  ),

                  const SizedBox(height: 20),

                  // Selector de cuenta
                  FutureBuilder<List<Account>>(
                    future: _accountsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Crea una cuenta primero para continuar',
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                        );
                      }

                      return _AccountDropdownPremium(
                        accounts: snapshot.data!,
                        selectedAccountId: _selectedAccountId,
                        onChanged: (accountId) {
                          setState(() {
                            _selectedAccountId = accountId;
                            _selectedAccount = snapshot.data!
                                .firstWhere((acc) => acc.id == accountId);
                          });
                        },
                        accentColor: accentColor,
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Frecuencia
                  _FrequencySmartPicker(
                    frequency: _frequency,
                    onChanged: (val) => setState(() => _frequency = val),
                    accentColor: accentColor,
                  ),

                  const SizedBox(height: 20),

                  // Fecha de inicio
                  _StartDateAnimatedTile(
                    startDate: _startDate,
                    onTap: () => _selectDate(context),
                    accentColor: accentColor,
                  ),

                  const SizedBox(height: 32),

                  // TARJETA DE IMPACTO FINANCIERO
                  if (_monthlyAmount > 0 && _selectedAccount != null)
                    _FinancialImpactCard(
                      type: _type,
                      monthlyAmount: _monthlyAmount,
                      yearlyAmount: _yearlyAmount,
                      account: _selectedAccount!,
                      nextPaymentDate: _nextPaymentDate,
                      accentColor: accentColor,
                    ),

                  const SizedBox(height: 32),

                  // BOTÓN DE GUARDAR
                  _PremiumSaveButton(
                    isLoading: _isLoading,
                    type: _type,
                    onPressed: _save,
                    accentColor: accentColor,
                  ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== WIDGETS MODULARES ====================

// 1. HEADER CON SELECTOR DE TIPO
class _RecurringHeaderSelector extends StatelessWidget {
  final String type;
  final Function(String) onTypeChanged;
  final Color accentColor;

  const _RecurringHeaderSelector({
    required this.type,
    required this.onTypeChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.repeat, size: 28, color: accentColor),
              const SizedBox(width: 12),
              Text(
                'Nuevo ${type == 'Gasto' ? 'Gasto' : 'Ingreso'} Fijo',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configura un movimiento que se repita automáticamente',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          // Segmented control animado
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TypeButton(
                    label: 'Gasto',
                    icon: Iconsax.card_remove,
                    isSelected: type == 'Gasto',
                    onTap: () => onTypeChanged('Gasto'),
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _TypeButton(
                    label: 'Ingreso',
                    icon: Iconsax.card_tick,
                    isSelected: type == 'Ingreso',
                    onTap: () => onTypeChanged('Ingreso'),
                    color: Colors.green,
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

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Material(
        color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 2. CAMPO DE TEXTO PREMIUM
class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final String? Function(String?)? validator;

  const _PremiumTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: accentColor),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// 3. CAMPO DE MONTO CON PROYECCIÓN
class _AmountFieldWithProjection extends StatelessWidget {
  final TextEditingController controller;
  final String frequency;
  final double monthlyAmount;
  final double yearlyAmount;
  final Color accentColor;

  const _AmountFieldWithProjection({
    required this.controller,
    required this.frequency,
    required this.monthlyAmount,
    required this.yearlyAmount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Monto',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixText: '\$ ',
            prefixStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            prefixIcon: Icon(Iconsax.money_4, color: accentColor),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: accentColor, width: 2),
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'El monto es requerido';
            if (double.tryParse(v.replaceAll(',', '.')) == null) {
              return 'Ingresa un monto válido';
            }
            if (double.parse(v.replaceAll(',', '.')) <= 0) {
              return 'El monto debe ser mayor a cero';
            }
            return null;
          },
        ),
        if (monthlyAmount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.1),
                  accentColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Iconsax.chart_21, size: 20, color: accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Proyección automática',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currencyFormat.format(monthlyAmount)}/mes • ${currencyFormat.format(yearlyAmount)}/año',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// 4. SELECTOR DE CUENTA PREMIUM
class _AccountDropdownPremium extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedAccountId;
  final Function(String) onChanged;
  final Color accentColor;

  const _AccountDropdownPremium({
    required this.accounts,
    required this.selectedAccountId,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    //final selectedAccount = accounts.firstWhere(
      //(acc) => acc.id == selectedAccountId,
      //orElse: () => accounts.first,
    //);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Cuenta de Origen',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedAccountId ?? accounts.first.id,
              isExpanded: true,
              icon: Icon(Iconsax.arrow_down_1, color: accentColor),
              items: accounts.map((account) {
                final currencyFormat = NumberFormat.currency(
                  locale: 'es_CO',
                  symbol: '\$',
                  decimalDigits: 0,
                );
                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Iconsax.wallet_3, size: 20, color: accentColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              account.name,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Saldo: ${currencyFormat.format(account.balance)}',
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
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// 5. SELECTOR DE FRECUENCIA
class _FrequencySmartPicker extends StatelessWidget {
  final String frequency;
  final Function(String) onChanged;
  final Color accentColor;

  const _FrequencySmartPicker({
    required this.frequency,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final frequencies = [
      ('diario', 'Diario', Iconsax.calendar_1),
      ('semanal', 'Semanal', Iconsax.calendar_2),
      ('quincenal', 'Quincenal', Iconsax.calendar),
      ('mensual', 'Mensual', Iconsax.calendar_tick),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                'Frecuencia de Repetición',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Define cada cuánto tiempo se repetirá este movimiento',
                child: Icon(
                  Iconsax.info_circle,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: frequencies.map((freq) {
            final isSelected = frequency == freq.$1;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    freq.$3,
                    size: 18,
                    color: isSelected ? Colors.white : accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(freq.$2),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(freq.$1),
              selectedColor: accentColor,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : null,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? accentColor
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// 6. FECHA DE INICIO
class _StartDateAnimatedTile extends StatelessWidget {
  final DateTime startDate;
  final VoidCallback onTap;
  final Color accentColor;

  const _StartDateAnimatedTile({
    required this.startDate,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Fecha de Inicio',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Iconsax.calendar_1, color: accentColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primera ejecución',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMMd('es_CO').format(startDate),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_right_3,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 7. TARJETA DE IMPACTO FINANCIERO
class _FinancialImpactCard extends StatelessWidget {
  final String type;
  final double monthlyAmount;
  final double yearlyAmount;
  final Account account;
  final DateTime nextPaymentDate;
  final Color accentColor;

  const _FinancialImpactCard({
    required this.type,
    required this.monthlyAmount,
    required this.yearlyAmount,
    required this.account,
    required this.nextPaymentDate,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final projectedBalance = type == 'Gasto'
        ? account.balance - (monthlyAmount * 3)
        : account.balance + (monthlyAmount * 3);

    final impactPercentage = (monthlyAmount / account.balance * 100).clamp(0, 100);
    
    final isHighImpact = impactPercentage > 10;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.15),
            accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.magic_star,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis Inteligente',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Impacto en tus finanzas',
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
          
          const SizedBox(height: 24),
          
          // Alerta de impacto alto
          if (isHighImpact)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.warning_2, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Este ${type.toLowerCase()} representa el ${impactPercentage.toStringAsFixed(1)}% del saldo de tu cuenta',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Estadísticas
          _ImpactStat(
            icon: Iconsax.calendar_tick,
            label: 'Proyección anual',
            value: currencyFormat.format(yearlyAmount),
            accentColor: accentColor,
          ),
          
          const SizedBox(height: 16),
          
          _ImpactStat(
            icon: Iconsax.wallet_money,
            label: 'Saldo proyectado (3 meses)',
            value: currencyFormat.format(projectedBalance),
            accentColor: projectedBalance > 0 ? Colors.green : Colors.red,
            subtitle: 'En cuenta: ${account.name}',
          ),
          
          const SizedBox(height: 16),
          
          _ImpactStat(
            icon: Iconsax.notification,
            label: 'Próxima ejecución',
            value: DateFormat('d MMM yyyy', 'es_CO').format(nextPaymentDate),
            accentColor: accentColor,
            subtitle: 'Notificación activada',
          ),
          
          const SizedBox(height: 20),
          
          // Barra de progreso del impacto
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Impacto en cuenta',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${impactPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: impactPercentage / 100,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final String? subtitle;

  const _ImpactStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// 8. BOTÓN DE GUARDAR PREMIUM
class _PremiumSaveButton extends StatelessWidget {
  final bool isLoading;
  final String type;
  final VoidCallback onPressed;
  final Color accentColor;

  const _PremiumSaveButton({
    required this.isLoading,
    required this.type,
    required this.onPressed,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoading
              ? [Colors.grey, Colors.grey.shade600]
              : [accentColor, accentColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLoading
            ? null
            : [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.tick_circle, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Confirmar y Activar',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}