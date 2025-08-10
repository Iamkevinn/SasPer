// lib/screens/edit_transaction_screen.dart (VERSIÓN FINAL COMPLETA USANDO SINGLETONS)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart'; // Importamos EventService para la notificación global
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;
import 'package:sasper/main.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';

class EditTransactionScreen extends StatefulWidget {
  final Transaction transaction;

  // Los repositorios ya no se pasan en el constructor.
  const EditTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final TransactionRepository _transactionRepository =
      TransactionRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;
  final CategoryRepository _categoryRepository = CategoryRepository.instance;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  String? _selectedCategoryName;
  late String _transactionType;
  String? _selectedCategory;
  String? _selectedAccountId;
  bool _isLoading = false;
  TransactionMood? _selectedMood;

  late Future<List<Account>> _accountsFuture;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.transaction.amount.abs().toString());
    _descriptionController =
        TextEditingController(text: widget.transaction.description ?? '');
    _transactionType = widget.transaction.type;
    _selectedCategoryName = widget.transaction.category;
    _selectedAccountId = widget.transaction.accountId;
    _selectedMood = widget.transaction.mood; 
    // Usamos la instancia singleton para cargar las cuentas.
    _accountsFuture = _accountRepository.getAccounts();
    _categoriesFuture = _categoryRepository.getCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCategoryName == null ||
        _selectedAccountId == null) {
      if (!_formKey.currentState!.validate() ||
          _selectedCategory == null ||
          _selectedAccountId == null) {
        NotificationHelper.show(
          message: 'Por favor completa todos los campos requeridos.',
          type: NotificationType.error,
        );
        return;
      }

      setState(() => _isLoading = true);

      double amount =
          double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ??
              0;
      if (_transactionType == 'Gasto') {
        amount = -amount.abs();
      } else {
        amount = amount.abs();
      }

      try {
        await _transactionRepository.updateTransaction(
          transactionId: widget.transaction.id,
          accountId: _selectedAccountId!,
          amount: amount,
          type: _transactionType,
          category: _selectedCategoryName!,
          description: _descriptionController.text.trim(),
          mood: _selectedMood,
          transactionDate: widget.transaction.transactionDate,
        );

        if (!mounted) return;

        // Disparamos el evento global para que el Dashboard y otras partes se enteren.
        EventService.instance.fire(AppEvent.transactionUpdated);

        // Devolvemos 'true' para que la pantalla anterior (la lista) pueda refrescarse.
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Transacción actualizada correctamente!',
            type: NotificationType.success,
          );
        });
      } catch (e) {
        developer.log('🔥 FALLO AL ACTUALIZAR TRANSACCIÓN: $e',
            name: 'EditTransactionScreen');
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al actualizar la transacción.',
            type: NotificationType.error,
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTransaction() async {
    if (widget.transaction.debtId != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
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
      // 1. Usamos el context del Navigator global.
      context: navigatorKey.currentContext!,

      // 2. Usamos 'dialogContext' para el builder.
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          // 3. Usamos 'dialogContext' para obtener el tema.
          backgroundColor:
              Theme.of(dialogContext).colorScheme.surface.withOpacity(0.85),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          title: const Text('Confirmar eliminación'),
          content:
              const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            // 4. Usamos 'dialogContext' para cerrar el diálogo.
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                // 5. Usamos 'dialogContext' para el tema aquí también.
                backgroundColor:
                    Theme.of(dialogContext).colorScheme.errorContainer,
                foregroundColor:
                    Theme.of(dialogContext).colorScheme.onErrorContainer,
              ),
              // 6. Y para cerrar el diálogo.
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);
      try {
        await _transactionRepository.deleteTransaction(widget.transaction.id);
        if (!mounted) return;

        // Disparamos el evento global
        EventService.instance.fire(AppEvent.transactionDeleted);

        // Devolvemos 'true' para el refresco inmediato
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Transacción eliminada correctamente.',
            type: NotificationType.success,
          );
        });
      } catch (e) {
        developer.log('🔥 FALLO AL ELIMINAR TRANSACCIÓN: $e',
            name: 'EditTransactionScreen');
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al eliminar la transacción.',
            type: NotificationType.error,
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // NOVEDAD: Se añade esta línea para que 'colorScheme' esté disponible en todo el método.
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Transacción', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
              icon: Icon(Iconsax.trash,
                  color: Theme.of(context).colorScheme.error),
              onPressed: _isLoading ? null : _deleteTransaction)
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa un monto';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) {
                    return 'Ingresa un monto válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  textStyle: GoogleFonts.poppins(),
                ),
                segments: const [
                  ButtonSegment(
                      value: 'Gasto',
                      label: Text('Gasto'),
                      icon: Icon(Iconsax.arrow_down_2)),
                  ButtonSegment(
                      value: 'Ingreso',
                      label: Text('Ingreso'),
                      icon: Icon(Iconsax.arrow_up_1)),
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
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Text('Error: No se pudieron cargar las cuentas.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error));
                  }
                  final accounts = snapshot.data!;
                  // Lógica para evitar errores si la cuenta asociada fue eliminada
                  if (_selectedAccountId != null &&
                      !accounts.any((acc) => acc.id == _selectedAccountId)) {
                    _selectedAccountId = null;
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    items: accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedAccountId = value),
                    decoration: InputDecoration(
                      labelText: 'Cuenta',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) =>
                        value == null ? 'Debes seleccionar una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text('Categoría',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              FutureBuilder<List<Category>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData) {
                    return const Text('No se pudieron cargar las categorías.');
                  }

                  final allUserCategories = snapshot.data!;
                  final expectedTypeName = _transactionType == 'Gasto' ? 'expense' : 'income';
                  final currentCategories = allUserCategories
                      .where((c) => c.type.name == expectedTypeName)
                      .toList();
                      
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: currentCategories.map((category) {
                      return ChoiceChip(
                        label: Text(category.name),
                        avatar:
                            Icon(category.icon ?? Iconsax.category, size: 18),
                        selected: _selectedCategoryName ==
                            category.name, // <-- Comparamos por nombre
                        onSelected: (isSelected) {
                          if (isSelected) {
                            setState(
                                () => _selectedCategoryName = category.name);
                          }
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // NOVEDAD: Añadimos la sección para seleccionar el estado de ánimo.
              // Es idéntica a la de la pantalla de añadir.
              if (_transactionType == 'Gasto') ...[
                Text('Estado de ánimo del gasto (Opcional)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: TransactionMood.values.map((mood) {
                    return FilterChip(
                      label: Text(mood.displayName, style: GoogleFonts.poppins()),
                      avatar: Icon(
                        mood.icon,
                        color: _selectedMood == mood ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                      ),
                      selected: _selectedMood == mood,
                      onSelected: (selected) {
                        setState(() {
                          _selectedMood = selected ? mood : null;
                        });
                      },
                      selectedColor: colorScheme.secondaryContainer,
                      checkmarkColor: colorScheme.onSecondaryContainer,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              
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
