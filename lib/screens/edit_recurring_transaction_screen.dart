// lib/screens/edit_recurring_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;
import 'package:sasper/services/notification_service.dart';

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
  final AccountRepository _accountRepository = AccountRepository.instance;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  
  late String _type;
  late String _frequency;
  String? _selectedAccountId;
  
  late DateTime _nextDueDate;
  late TimeOfDay _notificationTime;
  
  bool _isLoading = false;
  bool _hasChanges = false;
  late Future<List<Account>> _accountsFuture;

  // Animación
  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonScale;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    
    final t = widget.transaction;
    _descriptionController = TextEditingController(text: t.description);
    _amountController = TextEditingController(text: t.amount.toStringAsFixed(2).replaceAll('.00', ''));
    _type = t.type;
    _frequency = t.frequency;
    _selectedAccountId = t.accountId;
    _nextDueDate = t.nextDueDate;
    _notificationTime = TimeOfDay(hour: t.nextDueDate.hour, minute: t.nextDueDate.minute);

    // Animación del botón de guardar
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _saveButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeInOut),
    );

    // Detectar cambios
    _descriptionController.addListener(_markAsChanged);
    _amountController.addListener(_markAsChanged);
  }

  void _markAsChanged() {
    if (!_hasChanges && mounted) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
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
    if (picked != null && picked != _nextDueDate) {
      setState(() {
        _nextDueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _nextDueDate.hour,
          _nextDueDate.minute,
        );
        _hasChanges = true;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _notificationTime) {
      setState(() {
        _notificationTime = picked;
        _nextDueDate = DateTime(
          _nextDueDate.year,
          _nextDueDate.month,
          _nextDueDate.day,
          picked.hour,
          picked.minute,
        );
        _hasChanges = true;
      });
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) return;

    _saveButtonController.forward().then((_) => _saveButtonController.reverse());
    setState(() => _isLoading = true);

    try {
      final updatedTransaction = widget.transaction.copyWith(
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        type: _type,
        accountId: _selectedAccountId,
        frequency: _frequency,
        nextDueDate: _nextDueDate,
      );

      await _repository.updateRecurringTransaction(updatedTransaction);
      await NotificationService.instance.cancelRecurringReminders(widget.transaction.id);
      await NotificationService.instance.scheduleRecurringReminders(updatedTransaction);
      
      developer.log('✅ Notificaciones reprogramadas para: ${updatedTransaction.description}', 
          name: 'EditRecurringScreen');

      if (mounted) {
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: '✨ Gasto fijo actualizado correctamente',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 Error: $e', name: 'EditRecurringScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error: ${e.toString().replaceFirst("Exception: ", "")}',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _type == 'Gasto'
        ? (isDark ? Colors.orange : Colors.deepOrange)
        : (isDark ? Colors.teal : Colors.green);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar estilo Apple
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Editar Gasto Fijo',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
          ),

          // Contenido
          SliverToBoxAdapter(
            child: FutureBuilder<List<Account>>(
              future: _accountsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final accounts = snapshot.data ?? [];
                if (_selectedAccountId != null && 
                    !accounts.any((acc) => acc.id == _selectedAccountId)) {
                  _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
                }

                return Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selector de Tipo (Gasto/Ingreso)
                        _TypeSelector(
                          type: _type,
                          onChanged: (newType) {
                            setState(() {
                              _type = newType;
                              _hasChanges = true;
                            });
                          },
                          accentColor: accentColor,
                        ),

                        const SizedBox(height: 24),

                        // Descripción
                        _AppleTextField(
                          controller: _descriptionController,
                          label: 'Descripción',
                          hint: 'Ej: Netflix, Gimnasio',
                          icon: Iconsax.document_text,
                          accentColor: accentColor,
                          validator: (v) => v == null || v.trim().isEmpty 
                              ? 'La descripción es requerida' 
                              : null,
                        ),

                        const SizedBox(height: 20),

                        // Monto
                        _AppleTextField(
                          controller: _amountController,
                          label: 'Monto',
                          hint: '0.00',
                          icon: Iconsax.money_4,
                          prefixText: '\$ ',
                          accentColor: accentColor,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'El monto es requerido';
                            if (double.tryParse(v.replaceAll(',', '.')) == null) {
                              return 'Monto inválido';
                            }
                            if (double.parse(v.replaceAll(',', '.')) <= 0) {
                              return 'Debe ser mayor a cero';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Cuenta
                        _AccountSelector(
                          accounts: accounts,
                          selectedAccountId: _selectedAccountId,
                          onChanged: (accountId) {
                            setState(() {
                              _selectedAccountId = accountId;
                              _hasChanges = true;
                            });
                          },
                          accentColor: accentColor,
                        ),

                        const SizedBox(height: 20),

                        // Frecuencia
                        _FrequencySelector(
                          frequency: _frequency,
                          onChanged: (freq) {
                            setState(() {
                              _frequency = freq;
                              _hasChanges = true;
                            });
                          },
                          accentColor: accentColor,
                        ),

                        const SizedBox(height: 20),

                        // Fecha y Hora
                        Row(
                          children: [
                            Expanded(
                              child: _DateTimeTile(
                                label: 'Próxima fecha',
                                value: DateFormat('d MMM yyyy', 'es_CO').format(_nextDueDate),
                                icon: Iconsax.calendar_1,
                                onTap: () => _selectDate(context),
                                accentColor: accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateTimeTile(
                                label: 'Hora',
                                value: _notificationTime.format(context),
                                icon: Iconsax.clock,
                                onTap: () => _selectTime(context),
                                accentColor: accentColor,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Botón de guardar con animación
                        ScaleTransition(
                          scale: _saveButtonScale,
                          child: _SaveButton(
                            isLoading: _isLoading,
                            hasChanges: _hasChanges,
                            type: _type,
                            onPressed: _update,
                            accentColor: accentColor,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== WIDGETS PERSONALIZADOS ====================

class _TypeSelector extends StatelessWidget {
  final String type;
  final Function(String) onChanged;
  final Color accentColor;

  const _TypeSelector({
    required this.type,
    required this.onChanged,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeOption(
              label: 'Gasto',
              icon: Iconsax.card_remove,
              isSelected: type == 'Gasto',
              onTap: () => onChanged('Gasto'),
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TypeOption(
              label: 'Ingreso',
              icon: Iconsax.card_tick,
              isSelected: type == 'Ingreso',
              onTap: () => onChanged('Ingreso'),
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
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

class _AppleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final String? prefixText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AppleTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.prefixText,
    this.keyboardType,
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
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          style: GoogleFonts.poppins(
            fontSize: prefixText != null ? 20 : 16,
            fontWeight: prefixText != null ? FontWeight.bold : FontWeight.normal,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

class _AccountSelector extends StatelessWidget {
  final List<Account> accounts;
  final String? selectedAccountId;
  final Function(String) onChanged;
  final Color accentColor;

  const _AccountSelector({
    required this.accounts,
    required this.selectedAccountId,
    required this.onChanged,
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
            'Cuenta',
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
              value: selectedAccountId ?? (accounts.isNotEmpty ? accounts.first.id : null),
              isExpanded: true,
              icon: Icon(Iconsax.arrow_down_1, color: accentColor),
              items: accounts.map((account) {
                return DropdownMenuItem(
                  value: account.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Iconsax.wallet_3, size: 18, color: accentColor),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        account.name,
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
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

class _FrequencySelector extends StatelessWidget {
  final String frequency;
  final Function(String) onChanged;
  final Color accentColor;

  const _FrequencySelector({
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
          child: Text(
            'Frecuencia',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
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
                    size: 16,
                    color: isSelected ? Colors.white : accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(freq.$2),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(freq.$1),
              selectedColor: accentColor,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : null,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? accentColor : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Color accentColor;

  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool isLoading;
  final bool hasChanges;
  final String type;
  final VoidCallback onPressed;
  final Color accentColor;

  const _SaveButton({
    required this.isLoading,
    required this.hasChanges,
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
          colors: isLoading || !hasChanges
              ? [Colors.grey, Colors.grey.shade600]
              : [accentColor, accentColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasChanges && !isLoading
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading || !hasChanges ? null : onPressed,
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
                        hasChanges ? 'Guardar Cambios' : 'Sin Cambios',
                        style: GoogleFonts.poppins(
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
    );
  }
}