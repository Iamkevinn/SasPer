// lib/screens/add_debt_screen.dart

import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:developer' as developer;

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen>
    with TickerProviderStateMixin {
  // Repositorios
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController(text: '0');
  final _entityControllerForManualEntry = TextEditingController();
  final DebtRepository _debtRepository = DebtRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;
  late ConfettiController _confettiController;

  // Estado
  DebtType _selectedDebtType = DebtType.debt;
  DebtImpactType _selectedImpactType = DebtImpactType.liquid; // <--- NUEVO
  Account? _selectedAccount;
  DateTime? _dueDate;
  bool _isLoading = false;
  bool _isSuccess = false;
  contacts.Contact? _selectedContact;
  double? _contactTotalBalance;
  bool _isFetchingDebt = false;

  // Animaciones
  late AnimationController _typeAnimationController;
  late AnimationController _impactAnimationController;
  late Animation<double> _typeAnimation;
  late Animation<double> _impactAnimation;

  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Animación del selector de tipo
    _typeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _typeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _typeAnimationController, curve: Curves.easeInOutBack),
    );

    // Animación del impacto financiero
    _impactAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _impactAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _impactAnimationController, curve: Curves.easeOutCubic),
    );

    // Listeners para actualizar en tiempo real
    _nameController.addListener(() => setState(() {}));
    _amountController.addListener(() {
      setState(() {});
      _impactAnimationController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _entityControllerForManualEntry.dispose();
    _confettiController.dispose();
    _typeAnimationController.dispose();
    _impactAnimationController.dispose();
    super.dispose();
  }

  void _changeDebtType(DebtType newType) {
    if (newType == _selectedDebtType) return;
    setState(() => _selectedDebtType = newType);
    if (newType == DebtType.debt) {
      _typeAnimationController.forward();
    } else {
      _typeAnimationController.reverse();
    }
  }

  // Lógica de contactos
  Future<void> _pickContact() async {
    Navigator.pop(context);
    if (await Permission.contacts.request().isGranted) {
      final contact = await contacts.FlutterContacts.openExternalPick();
      if (contact != null) {
        setState(() {
          _selectedContact = contact;
          _entityControllerForManualEntry.clear();
        });
        _fetchDebtForSelectedContact();
      }
    } else {
      NotificationHelper.show(
        message: 'Permiso de contactos denegado.',
        type: NotificationType.warning,
      );
    }
  }

  void _useManualEntry() {
    Navigator.pop(context);
    setState(() {
      _selectedContact = null;
      _contactTotalBalance = null;
    });
  }

  void _clearSelectedContact() {
    setState(() {
      _selectedContact = null;
      _contactTotalBalance = null;
      _entityControllerForManualEntry.clear();
    });
  }

  Future<void> _fetchDebtForSelectedContact() async {
    if (_selectedContact == null) return;
    setState(() => _isFetchingDebt = true);
    try {
      final total = await _debtRepository
          .getTotalDebtForEntity(_selectedContact!.displayName);
      if (mounted) setState(() => _contactTotalBalance = total);
    } catch (e) {
      developer.log('Error al obtener deuda del contacto: $e');
    } finally {
      if (mounted) setState(() => _isFetchingDebt = false);
    }
  }

  // Guardar
  void _showConfirmationModal() {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) {
      NotificationHelper.show(
        message: 'Por favor, completa todos los campos requeridos.',
        type: NotificationType.error,
      );
      return;
    }

    final amount = double.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PremiumConfirmationModal(
        debtType: _selectedDebtType,
        amount: amount,
        concept: _nameController.text,
        entityName: _selectedContact?.displayName ??
            _entityControllerForManualEntry.text,
        account: _selectedAccount!,
        onConfirm: _submitForm,
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_isLoading || _isSuccess) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final entityName = _selectedContact?.displayName ??
          _entityControllerForManualEntry.text.trim();
      await _debtRepository.addDebtAndInitialTransaction(
        name: _nameController.text.trim(),
        type: _selectedDebtType,
        entityName: entityName.isNotEmpty ? entityName : null,
        amount: double.parse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), '')),
        accountId: _selectedAccount!.id,
        dueDate: _dueDate,
        transactionDate: DateTime.now(),
        impactType: _selectedImpactType, // <--- NUEVO
      );

      if (mounted) {
        setState(() => _isSuccess = true);
        _confettiController.play();
        EventService.instance.fire(AppEvent.transactionsChanged);
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) Navigator.of(context).pop();
        NotificationHelper.show(
          message: '¡Operación registrada exitosamente!',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          message:
              'Error al guardar: ${e.toString().replaceFirst("Exception: ", "")}',
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

    final double amount = double.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final entityName =
        _selectedContact?.displayName ?? _entityControllerForManualEntry.text;

    // Color dinámico según tipo
    final accentColor = _selectedDebtType == DebtType.debt
        ? (isDark ? Colors.red.shade400 : Colors.red.shade700)
        : (isDark ? Colors.green.shade400 : Colors.green.shade700);

    return Stack(
      children: [
        // Fondo animado con gradiente dinámico
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(0.05),
                colorScheme.surface,
                colorScheme.surface,
              ],
            ),
          ),
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // HEADER CON SELECTOR DE TIPO (Esto no cambia)
              _buildPremiumHeader(accentColor, isDark),

              SliverToBoxAdapter(
                child: Padding(
                  // Añadimos un Padding para el margen horizontal
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildFloatingHeroCard(
                      amount, entityName, accentColor, isDark),
                ),
              ),

              // FORMULARIO INTELIGENTE Y TARJETA HERO
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8), // Pequeño espacio superior

                    // 1. HEMOS MOVIDO LA TARJETA HERO AQUÍ
                    //_buildFloatingHeroCard(
                      //  amount, entityName, accentColor, isDark),

                    // 2. HEMOS QUITADO EL SizedBox(height: 24) DE AQUÍ
                    Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.all(
                            4.0), // Padding para el formulario
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                                height: 32), // Espacio después de la tarjeta

                            // Concepto
                            _buildSectionLabel(
                                '¿Para qué es?', Iconsax.note_1, accentColor),
                            const SizedBox(height: 12),
                            _PremiumTextField(
                              controller: _nameController,
                              hint: _selectedDebtType == DebtType.debt
                                  ? 'Ej: Préstamo para el coche'
                                  : 'Ej: Dinero del viaje',
                              icon: Iconsax.note_text,
                              accentColor: accentColor,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'El concepto es obligatorio'
                                  : null,
                            ),

                            const SizedBox(height: 32),

                            // Contacto
                            _buildSectionLabel(
                                _selectedDebtType == DebtType.debt
                                    ? '¿A quién le debes?'
                                    : '¿Quién te debe?',
                                Iconsax.user_search,
                                accentColor),
                            const SizedBox(height: 12),
                            _ContactSelectorPremium(
                              selectedContact: _selectedContact,
                              manualEntryController:
                                  _entityControllerForManualEntry,
                              contactBalance: _contactTotalBalance,
                              isFetching: _isFetchingDebt,
                              onClear: _clearSelectedContact,
                              onTap: _showContactPicker,
                              accentColor: accentColor,
                            ),

                            const SizedBox(height: 32),

                            // Monto
                            _buildSectionLabel(
                                'Monto', Iconsax.money_4, accentColor),
                            const SizedBox(height: 12),
                            _PremiumAmountField(
                              controller: _amountController,
                              accentColor: accentColor,
                            ),

                            const SizedBox(height: 32),

                            // Cuenta y fecha
                            _buildSectionLabel(
                                'Detalles', Iconsax.setting_2, accentColor),
                            const SizedBox(height: 12),
                            _buildAccountAndDatePickers(accentColor),
const SizedBox(height: 32),

                            // NUEVO: SELECTOR DE IMPACTO (El corazón de nuestra lógica)
                            _buildSectionLabel('¿Cómo afecta tu cuenta?', Iconsax.shuffle, accentColor),
                            const SizedBox(height: 12),
                            _ImpactTypeSelectorPremium(
                              selectedImpact: _selectedImpactType,
                              debtType: _selectedDebtType,
                              accentColor: accentColor,
                              onChanged: (val) {
                                setState(() => _selectedImpactType = val);
                              },
                            ),

                            const SizedBox(height: 32),

                            // TARJETA DE IMPACTO FINANCIERO ...
                            const SizedBox(height: 32),

                            // TARJETA DE IMPACTO FINANCIERO
                            if (amount > 0 && _selectedAccount != null)
                              FadeTransition(
                                opacity: _impactAnimation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.2),
                                    end: Offset.zero,
                                  ).animate(_impactAnimation),
                                  child: _FinancialImpactCard(
                                    debtType: _selectedDebtType,
                                    impactType: _selectedImpactType,
                                    amount: amount,
                                    account: _selectedAccount!,
                                    accentColor: accentColor,
                                    isDark: isDark,
                                  ),
                                ),
                              ),

                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
        // BOTÓN FLOTANTE PREMIUM
        _buildFloatingActionButton(accentColor),

        // CONFETTI
        _ConfettiCelebration(controller: _confettiController),
      ],
    );
  }

  // ==================== COMPONENTES ====================

  Widget _buildPremiumHeader(Color accentColor, bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding:
              const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _typeAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1 + (_typeAnimation.value * 0.1),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withOpacity(0.7)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            _selectedDebtType == DebtType.debt
                                ? Iconsax.money_recive
                                : Iconsax.money_send,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Nueva Operación',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DebtTypeSelectorPremium(
                selectedType: _selectedDebtType,
                onChanged: _changeDebtType,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingHeroCard(
      double amount, String entityName, Color accentColor, bool isDark) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$ ',
      decimalDigits: 0,
    );

    // Devuelve el Container directamente
    return Container(
      margin: const EdgeInsets.symmetric(
          vertical: 8), // Ajustamos el margen vertical
      padding: const EdgeInsets.all(20),
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
            color: accentColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entityName.isEmpty
                          ? 'Ingresa los datos'
                          : (_selectedDebtType == DebtType.debt
                              ? 'Deuda con'
                              : 'Préstamo a'),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        entityName.isEmpty ? '—' : entityName,
                        key: ValueKey(entityName),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Text(
                  currencyFormat.format(amount),
                  key: ValueKey(amount),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, Color accentColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: accentColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountAndDatePickers(Color accentColor) {
    return Column(
      children: [
        // Selector de cuenta
        FutureBuilder<List<Account>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _AccountSelectorPremium(
              accounts: snapshot.data!,
              selectedAccount: _selectedAccount,
              onAccountSelected: (account) {
                setState(() => _selectedAccount = account);
                Navigator.pop(context);
              },
              accentColor: accentColor,
            );
          },
        ),
        const SizedBox(height: 16),
        // Selector de fecha
        _DatePickerPremium(
          dueDate: _dueDate,
          onDateSelected: (date) => setState(() => _dueDate = date),
          accentColor: accentColor,
        ),
      ],
    );
  }

  void _showContactPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactPickerModal(
        onPickContact: _pickContact,
        onManualEntry: _useManualEntry,
      ),
    );
  }

  Widget _buildFloatingActionButton(Color accentColor) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 30,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 64,
        decoration: BoxDecoration(
          gradient: _isSuccess
              ? LinearGradient(colors: [Colors.green, Colors.green.shade700])
              : LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_isSuccess ? Colors.green : accentColor).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading || _isSuccess ? null : _showConfirmationModal,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSuccess ? Iconsax.tick_circle : Iconsax.save_2,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isSuccess ? '¡Registrado!' : 'Confirmar Operación',
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
      ).animate().slideY(begin: 2, delay: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

// ==================== WIDGETS PERSONALIZADOS ====================

// 1. SELECTOR DE TIPO PREMIUM
class _DebtTypeSelectorPremium extends StatelessWidget {
  final DebtType selectedType;
  final Function(DebtType) onChanged;

  const _DebtTypeSelectorPremium({
    required this.selectedType,
    required this.onChanged,
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
            child: _TypeButton(
              label: 'Yo Debo',
              icon: Iconsax.arrow_down,
              isSelected: selectedType == DebtType.debt,
              onTap: () => onChanged(DebtType.debt),
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TypeButton(
              label: 'Me Deben',
              icon: Iconsax.arrow_up_3,
              isSelected: selectedType == DebtType.loan,
              onTap: () => onChanged(DebtType.loan),
              color: Colors.green,
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
                  color: isSelected
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? color
                        : Theme.of(context).colorScheme.onSurfaceVariant,
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
  final String hint;
  final IconData icon;
  final Color accentColor;
  final String? Function(String?)? validator;

  const _PremiumTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.accentColor,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: accentColor),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}

// 3. SELECTOR DE CONTACTO PREMIUM
class _ContactSelectorPremium extends StatelessWidget {
  final contacts.Contact? selectedContact;
  final TextEditingController manualEntryController;
  final double? contactBalance;
  final bool isFetching;
  final VoidCallback onClear;
  final VoidCallback onTap;
  final Color accentColor;

  const _ContactSelectorPremium({
    this.selectedContact,
    required this.manualEntryController,
    this.contactBalance,
    required this.isFetching,
    required this.onClear,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedContact == null) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Iconsax.user_search, color: accentColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Seleccionar o escribir nombre',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.1),
            accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                selectedContact!.displayName[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedContact!.displayName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isFetching)
                  const LinearProgressIndicator()
                else if (contactBalance != null)
                  Text(
                    contactBalance == 0
                        ? 'Sin deudas pendientes'
                        : (contactBalance! > 0
                            ? 'Te debe: ${currencyFormat.format(contactBalance)}'
                            : 'Le debes: ${currencyFormat.format(contactBalance!.abs())}'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: contactBalance == 0
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : (contactBalance! > 0 ? Colors.green : Colors.red),
                    ),
                  )
                else
                  Text(
                    'Primer registro con este contacto',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: Icon(Iconsax.close_circle, color: accentColor),
          ),
        ],
      ),
    );
  }
}

// 4. CAMPO DE MONTO PREMIUM
class _PremiumAmountField extends StatelessWidget {
  final TextEditingController controller;
  final Color accentColor;

  const _PremiumAmountField({
    required this.controller,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Monto de la operación',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CurrencyInputFormatter(),
            ],
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '\$ 0',
              hintStyle: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa un monto';
              final amount =
                  int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
              if (amount == null || amount <= 0) return 'Monto inválido';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    final number =
        int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final format = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    final newText = format.format(number);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// 5. SELECTOR DE CUENTA PREMIUM
class _AccountSelectorPremium extends StatelessWidget {
  final List<Account> accounts;
  final Account? selectedAccount;
  final Function(Account) onAccountSelected;
  final Color accentColor;

  const _AccountSelectorPremium({
    required this.accounts,
    required this.selectedAccount,
    required this.onAccountSelected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _showAccountPicker(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Iconsax.wallet_3, color: accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cuenta afectada',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedAccount?.name ?? 'Seleccionar cuenta',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_down_1,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Selecciona una cuenta',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...accounts.map((account) {
              final currencyFormat = NumberFormat.currency(
                locale: 'es_CO',
                symbol: '\$',
                decimalDigits: 0,
              );
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(account.icon, color: accentColor),
                ),
                title: Text(
                  account.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Saldo: ${currencyFormat.format(account.balance)}',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                onTap: () => onAccountSelected(account),
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// 6. SELECTOR DE FECHA PREMIUM
class _DatePickerPremium extends StatelessWidget {
  final DateTime? dueDate;
  final Function(DateTime) onDateSelected;
  final Color accentColor;

  const _DatePickerPremium({
    required this.dueDate,
    required this.onDateSelected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _selectDate(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Iconsax.calendar_1, color: accentColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha de vencimiento',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dueDate == null
                          ? 'Opcional'
                          : DateFormat('d MMM yyyy', 'es_CO').format(dueDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_down_1,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) onDateSelected(picked);
  }
}

// 7. TARJETA DE IMPACTO FINANCIERO
// 7. TARJETA DE IMPACTO FINANCIERO (ACTUALIZADA)
class _FinancialImpactCard extends StatelessWidget {
  final DebtType debtType;
  final DebtImpactType impactType; // <--- NUEVO
  final double amount;
  final Account account;
  final Color accentColor;
  final bool isDark;

  const _FinancialImpactCard({
    required this.debtType,
    required this.impactType, // <--- NUEVO
    required this.amount,
    required this.account,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    // Lógica contable real
    double projectedBalance = account.balance;
    if (impactType != DebtImpactType.direct) {
      projectedBalance = debtType == DebtType.debt
          ? account.balance + amount // Me prestaron -> Entra dinero
          : account.balance - amount; // Yo presté -> Sale dinero
    }

    final isDirect = impactType == DebtImpactType.direct;
    final impactPercentage = isDirect ? 0.0 : (amount / account.balance * 100).clamp(0, 100);
    final isHighImpact = impactPercentage > 15 && !isDirect;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:[accentColor.withOpacity(0.15), accentColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children:[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Iconsax.chart_success, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    Text('Impacto Financiero', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Así afectará tu cuenta', style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isHighImpact)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children:[
                  Icon(Iconsax.info_circle, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ Esta operación representa el ${impactPercentage.toStringAsFixed(1)}% del saldo disponible',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          _ImpactRow(icon: Iconsax.wallet_money, label: 'Saldo actual en ${account.name}', value: currencyFormat.format(account.balance), color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          
          if (isDirect)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.3))),
              child: Row(
                children:[
                  const Icon(Iconsax.info_circle, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Como es un pago directo, el saldo de tu cuenta no cambiará.', style: GoogleFonts.inter(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            )
          else ...[
            _ImpactRow(
              icon: debtType == DebtType.debt ? Iconsax.arrow_up : Iconsax.arrow_down,
              label: debtType == DebtType.debt ? 'Entrará a tu cuenta' : 'Saldrá de tu cuenta',
              value: currencyFormat.format(amount),
              color: accentColor,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: projectedBalance >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: projectedBalance >= 0 ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children:[
                  Icon(projectedBalance >= 0 ? Iconsax.tick_circle : Iconsax.danger, color: projectedBalance >= 0 ? Colors.green : Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text('Saldo proyectado', style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(currencyFormat.format(projectedBalance), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: projectedBalance >= 0 ? Colors.green : Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
             impactType == DebtImpactType.restricted 
                ? '💡 Recuerda: Este dinero estará reservado, no lo gastes libremente.'
                : (debtType == DebtType.debt
                    ? '💡 Esta deuda se sumará a tus pasivos totales.'
                    : '💡 Mantén control de a quién le prestas dinero.'),
            style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2);
  }
}
class _ImpactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ImpactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
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
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 8. MODAL DE CONFIRMACIÓN PREMIUM
class _PremiumConfirmationModal extends StatelessWidget {
  final DebtType debtType;
  final double amount;
  final String concept;
  final String entityName;
  final Account account;
  final VoidCallback onConfirm;

  const _PremiumConfirmationModal({
    required this.debtType,
    required this.amount,
    required this.concept,
    required this.entityName,
    required this.account,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final accentColor = debtType == DebtType.debt ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              debtType == DebtType.debt
                  ? Iconsax.money_recive
                  : Iconsax.money_send,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¿Confirmar Operación?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _ConfirmRow(
                    'Tipo', debtType == DebtType.debt ? 'Yo Debo' : 'Me Deben'),
                const Divider(height: 24),
                _ConfirmRow('Monto', currencyFormat.format(amount)),
                const Divider(height: 24),
                _ConfirmRow('Concepto', concept),
                const Divider(height: 24),
                _ConfirmRow('Persona', entityName),
                const Divider(height: 24),
                _ConfirmRow('Cuenta', account.name),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Iconsax.tick_circle),
                  label: const Text('Confirmar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// 9. MODAL DE SELECTOR DE CONTACTO
class _ContactPickerModal extends StatelessWidget {
  final VoidCallback onPickContact;
  final VoidCallback onManualEntry;

  const _ContactPickerModal({
    required this.onPickContact,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Seleccionar Contacto',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Iconsax.user_search,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: const Text('Desde la agenda'),
            subtitle: const Text('Buscar en tus contactos'),
            onTap: onPickContact,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Iconsax.edit,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            title: const Text('Escribir manualmente'),
            subtitle: const Text('Ingresar nombre o entidad'),
            onTap: onManualEntry,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// 10. CONFETTI CELEBRATION
class _ConfettiCelebration extends StatelessWidget {
  final ConfettiController controller;
  const _ConfettiCelebration({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        numberOfParticles: 30,
        gravity: 0.3,
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
        ],
      ),
    );
  }
}

// NUEVO: SELECTOR DE IMPACTO FINANCIERO PREMIUM
class _ImpactTypeSelectorPremium extends StatelessWidget {
  final DebtImpactType selectedImpact;
  final DebtType debtType;
  final Color accentColor;
  final Function(DebtImpactType) onChanged;

  const _ImpactTypeSelectorPremium({
    required this.selectedImpact,
    required this.debtType,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children:[
        _buildImpactOption(
          context: context,
          type: DebtImpactType.liquid,
          title: debtType == DebtType.debt ? 'Entró a mi cuenta' : 'Salió de mi cuenta',
          subtitle: 'Afecta mi saldo disponible',
          icon: Iconsax.wallet_add_1,
        ),
        const SizedBox(height: 12),
        _buildImpactOption(
          context: context,
          type: DebtImpactType.restricted,
          title: 'Tiene un propósito fijo',
          subtitle: 'Es para una meta o pago reservado',
          icon: Iconsax.lock_1,
        ),
        const SizedBox(height: 12),
        _buildImpactOption(
          context: context,
          type: DebtImpactType.direct,
          title: debtType == DebtType.debt ? 'Alguien pagó por mí' : 'Pagué por alguien más',
          subtitle: 'El dinero nunca tocó mis cuentas',
          icon: Iconsax.cards,
        ),
      ],
    );
  }

  Widget _buildImpactOption({
    required BuildContext context,
    required DebtImpactType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = selectedImpact == type;
    
    return Material(
      color: isSelected ? accentColor.withOpacity(0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => onChanged(type),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? accentColor.withOpacity(0.5) : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children:[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor.withOpacity(0.2) : Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isSelected ? accentColor : Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? accentColor : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Iconsax.tick_circle, color: accentColor)
            ],
          ),
        ),
      ),
    ).animate(target: isSelected ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02), duration: 200.ms);
  }
}