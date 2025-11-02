// lib/screens/edit_transaction_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;
import 'package:sasper/main.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';

class EditTransactionScreen extends StatefulWidget {
  final Transaction transaction;

  const EditTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;
  final CategoryRepository _categoryRepository = CategoryRepository.instance;
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  String? _selectedCategoryName;
  late String _transactionType;
  String? _selectedAccountId;
  bool _isLoading = false;
  TransactionMood? _selectedMood;

  late Future<List<Account>> _accountsFuture;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.abs().toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.transaction.description ?? '',
    );
    _transactionType = widget.transaction.type;
    _selectedCategoryName = widget.transaction.category;
    _selectedAccountId = widget.transaction.accountId;
    _selectedMood = widget.transaction.mood;
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
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryName == null || _selectedAccountId == null) {
      NotificationHelper.show(
        message: 'Por favor completa todos los campos requeridos.',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    double amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    ) ?? 0;

    amount = _transactionType == 'Gasto' ? -amount.abs() : amount.abs();

    try {
      await _transactionRepository.updateTransaction(
        transactionId: widget.transaction.id,
        accountId: _selectedAccountId!,
        type: _transactionType,
        category: _selectedCategoryName!,
        description: _descriptionController.text.trim(),
        mood: _selectedMood,
        transactionDate: widget.transaction.transactionDate,
      );

      if (!mounted) return;

      EventService.instance.fire(AppEvent.transactionUpdated);
      Navigator.of(context).pop(true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationHelper.show(
          message: 'Transacción actualizada',
          type: NotificationType.success,
        );
      });
    } catch (e) {
      developer.log('🔥 FALLO AL ACTUALIZAR: $e', name: 'EditTransactionScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al actualizar',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction() async {
    if (widget.transaction.debtId != null) {
      showDialog(
        context: context,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Iconsax.link_21,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Acción no permitida'),
              ],
            ),
            content: Text(
              "Esta transacción está vinculada a una deuda.\n\nPara gestionarla, ve a la sección de Deudas.",
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Iconsax.trash,
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Eliminar transacción'),
            ],
          ),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
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

        EventService.instance.fire(AppEvent.transactionDeleted);
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Transacción eliminada',
            type: NotificationType.success,
          );
        });
      } catch (e) {
        developer.log('🔥 FALLO AL ELIMINAR: $e', name: 'EditTransactionScreen');
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al eliminar',
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
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = _transactionType == 'Gasto';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar moderna
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
              title: Text(
                'Editar Transacción',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: colorScheme.onSurface,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isExpense
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Iconsax.trash,
                  color: colorScheme.error,
                ),
                onPressed: _isLoading ? null : _deleteTransaction,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card de información de la transacción original
                    _buildTransactionInfoCard().animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 24),

                    // Selector de tipo
                    _buildTypeSelector(colorScheme).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: 24),

                    // Selector de cuenta
                    _buildAccountSelector().animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 24),

                    // Selector de categoría
                    _buildCategorySelector().animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 24),

                    // Selector de estado de ánimo (solo gastos)
                    if (isExpense) ...[
                      _buildMoodSelector(colorScheme).animate().fadeIn(delay: 400.ms),
                      const SizedBox(height: 24),
                    ],

                    // Campo de descripción
                    _buildDescriptionField().animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 32),

                    // Botón de guardar
                    _buildSaveButton(colorScheme).animate().fadeIn(delay: 600.ms).scale(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = widget.transaction.type == 'Gasto';
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final dateFormat = DateFormat.yMMMd('es_CO');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpense
              ? [
                  Colors.red.withOpacity(0.15),
                  Colors.orange.withOpacity(0.1),
                ]
              : [
                  Colors.green.withOpacity(0.15),
                  Colors.teal.withOpacity(0.1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpense
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isExpense
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isExpense ? Iconsax.arrow_down_2 : Iconsax.arrow_up_1,
                  color: isExpense ? Colors.red : Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto Original',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(widget.transaction.amount.abs()),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isExpense ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Iconsax.calendar, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(widget.transaction.transactionDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'No editable',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.arrow_swap_horizontal, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Tipo de Transacción',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          style: SegmentedButton.styleFrom(
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            selectedBackgroundColor: _transactionType == 'Gasto'
                ? Colors.red.withOpacity(0.2)
                : Colors.green.withOpacity(0.2),
            selectedForegroundColor: _transactionType == 'Gasto' ? Colors.red : Colors.green,
          ),
          segments: const [
            ButtonSegment(
              value: 'Gasto',
              label: Text('Gasto'),
              icon: Icon(Iconsax.arrow_down_2),
            ),
            ButtonSegment(
              value: 'Ingreso',
              label: Text('Ingreso'),
              icon: Icon(Iconsax.arrow_up_1),
            ),
          ],
          selected: {_transactionType},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              setState(() {
                _transactionType = selection.first;
                _selectedCategoryName = null;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.wallet, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Cuenta',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Account>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Error al cargar cuentas',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }

            final accounts = snapshot.data!;
            if (_selectedAccountId != null &&
                !accounts.any((acc) => acc.id == _selectedAccountId)) {
              _selectedAccountId = null;
            }

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedAccountId,
                items: accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account.id,
                    child: Row(
                      children: [
                        Icon(Iconsax.wallet_3, size: 18),
                        const SizedBox(width: 12),
                        Text(account.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedAccountId = value),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Selecciona una cuenta',
                ),
                validator: (value) =>
                    value == null ? 'Debes seleccionar una cuenta' : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.category, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Categoría',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
              spacing: 10,
              runSpacing: 10,
              children: currentCategories.map((category) {
                final isSelected = _selectedCategoryName == category.name;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? category.colorAsObject
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected
                        ? category.colorAsObject.withOpacity(0.15)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategoryName = category.name),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            category.icon ?? Iconsax.category,
                            size: 20,
                            color: isSelected
                                ? category.colorAsObject
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected
                                  ? category.colorAsObject
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMoodSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.emoji_happy, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Estado de ánimo (Opcional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: TransactionMood.values.map((mood) {
            final isSelected = _selectedMood == mood;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
              ),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedMood = isSelected ? null : mood;
                }),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mood.icon,
                        size: 20,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mood.displayName,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.note_text, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Descripción (Opcional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Añade una nota sobre esta transacción...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return FilledButton(
      onPressed: _isLoading ? null : _updateTransaction,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.tick_circle),
                const SizedBox(width: 12),
                Text(
                  'Guardar Cambios',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}