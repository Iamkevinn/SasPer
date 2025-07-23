// lib/screens/edit_transaction_screen.dart (VERSIÓN FINAL COMPLETA)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class EditTransactionScreen extends StatefulWidget {
  final Transaction transaction;
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;

  const EditTransactionScreen({
    super.key,
    required this.transaction,
    required this.transactionRepository,
    required this.accountRepository,
  });

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late String _transactionType;
  String? _selectedCategory;
  String? _selectedAccountId;
  bool _isLoading = false;

  late Future<List<Account>> _accountsFuture;

  final Map<String, IconData> _expenseCategories = {
    'Comida': Iconsax.cup, 'Transporte': Iconsax.bus, 'Ocio': Iconsax.gameboy, 'Salud': Iconsax.health, 'Hogar': Iconsax.home, 'Compras': Iconsax.shopping_bag, 'Servicios': Iconsax.flash_1, 'Deudas y Préstamos': Iconsax.money_change, 'Otro': Iconsax.category
  };
  final Map<String, IconData> _incomeCategories = {
    'Sueldo': Iconsax.money_recive, 'Inversión': Iconsax.chart, 'Freelance': Iconsax.briefcase, 'Regalo': Iconsax.gift, 'Deudas y Préstamos': Iconsax.money_send, 'Otro': Iconsax.category_2
  };
  Map<String, IconData> get _currentCategories => _transactionType == 'Gasto' ? _expenseCategories : _incomeCategories;

  @override
  void initState() {
    super.initState();
    // Usamos el valor absoluto para la UI, el signo se maneja al guardar.
    _amountController = TextEditingController(text: widget.transaction.amount.abs().toString());
    _descriptionController = TextEditingController(text: widget.transaction.description ?? '');
    _transactionType = widget.transaction.type;
    _selectedCategory = widget.transaction.category;
    _selectedAccountId = widget.transaction.accountId;
    _accountsFuture = widget.accountRepository.getAccounts();
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null || _selectedAccountId == null) {
      NotificationHelper.show(
            context: context,
            message: 'Porfavor completa todos los campos requeridos.',
            type: NotificationType.error,
          );
      return;
    }

    setState(() => _isLoading = true);

    double amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0;
    // Aseguramos que el monto sea negativo si es un gasto.
    if (_transactionType == 'Gasto') {
      amount = -amount.abs();
    } else {
      amount = amount.abs();
    }

    try {
      await widget.transactionRepository.updateTransaction(
        transactionId: widget.transaction.id,
        accountId: _selectedAccountId!,
        amount: amount,
        type: _transactionType,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        transactionDate: widget.transaction.transactionDate,
      );

      if (!mounted) return;
      widget.accountRepository.forceRefresh();
      NotificationHelper.show(
            context: context,
            message: 'Transacción actualizada correctamente!',
            type: NotificationType.success,
          );
      Navigator.of(context).pop(true);

    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
            context: context,
            message: 'Error al actualizar la transacción.',
            type: NotificationType.error,
          );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction() async {
    if (widget.transaction.debtId != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          title: const Text('Acción no permitida'),
          content: Text(
            "Esta transacción está vinculada a una deuda o préstamo ('${widget.transaction.description}').\n\nPara gestionarla, ve a la sección de Deudas.",
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);
      try {
        await widget.transactionRepository.deleteTransaction(widget.transaction.id);
        if (!mounted) return;
        widget.accountRepository.forceRefresh();
        NotificationHelper.show(
            context: context,
            message: 'Transacción eliminada correctamente.',
            type: NotificationType.success,
          );
        Navigator.of(context).pop(true);
      } catch (e) {
        if (!mounted) return;
        NotificationHelper.show(
            context: context,
            message: 'Error al eliminar la transacción.',
            type: NotificationType.error,
          );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Transacción', style: GoogleFonts.poppins()),
        actions: [
          IconButton(icon: Icon(Iconsax.trash, color: Theme.of(context).colorScheme.error), onPressed: _isLoading ? null : _deleteTransaction)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa un monto';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Ingresa un monto válido';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  textStyle: GoogleFonts.poppins(),
                ),
                segments: const [
                  ButtonSegment(value: 'Gasto', label: Text('Gasto'), icon: Icon(Iconsax.arrow_down_2)),
                  ButtonSegment(value: 'Ingreso', label: Text('Ingreso'), icon: Icon(Iconsax.arrow_up_1)),
                ],
                selected: {_transactionType},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    setState(() {
                      _transactionType = selection.first;
                      _selectedCategory = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<Account>>(
                future: _accountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('Error: No se pudieron cargar las cuentas.', style: TextStyle(color: Theme.of(context).colorScheme.error));
                  }
                  final accounts = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    items: accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedAccountId = value),
                    decoration: InputDecoration(
                      labelText: 'Cuenta',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) => value == null ? 'Debes seleccionar una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Categoría', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentCategories.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.key),
                    labelStyle: GoogleFonts.poppins(),
                    avatar: Icon(entry.value, size: 18),
                    selected: _selectedCategory == entry.key,
                    onSelected: (isSelected) {
                      if (isSelected) {
                        setState(() => _selectedCategory = entry.key);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Iconsax.edit),
                label: _isLoading ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : const Text('Guardar Cambios'),
                onPressed: _isLoading ? null : _updateTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}