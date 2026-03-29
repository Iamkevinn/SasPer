// lib/screens/split_bill_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as contacts;

import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class SplitBillScreen extends StatefulWidget {
  final double? initialAmount;
  final String? initialConcept;

  const SplitBillScreen({super.key, this.initialAmount, this.initialConcept});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  final _amountCtrl = TextEditingController();
  final _conceptCtrl = TextEditingController();
  final _friendCtrl = TextEditingController();
  final _friendFocus = FocusNode();

  final List<String> _friends = [];
  bool _includeMe = true;
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountCtrl.text = widget.initialAmount!.toInt().toString();
    }
    if (widget.initialConcept != null) {
      _conceptCtrl.text = widget.initialConcept!;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _conceptCtrl.dispose();
    _friendCtrl.dispose();
    _friendFocus.dispose();
    super.dispose();
  }

  double get _totalAmount => double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
  int get _divisor => _friends.length + (_includeMe ? 1 : 0);
  double get _perPerson => _divisor > 0 ? _totalAmount / _divisor : 0.0;

  // ── Añadir desde texto ──
  void _addFriend() {
    final name = _friendCtrl.text.trim();
    if (name.isNotEmpty && !_friends.contains(name)) {
      HapticFeedback.lightImpact();
      setState(() {
        _friends.insert(0, name); // Agregar al inicio
        _friendCtrl.clear();
      });
      _friendFocus.requestFocus(); // Mantener el teclado abierto
    }
  }

  // ── Añadir desde Agenda (NUEVO) ──
  Future<void> _pickContact() async {
    // Escondemos el teclado si está abierto
    FocusScope.of(context).unfocus();
    
    if (!await Permission.contacts.request().isGranted) {
      NotificationHelper.show(message: 'Permiso de contactos denegado.', type: NotificationType.warning);
      return;
    }
    
    final contact = await contacts.FlutterContacts.openExternalPick();
    if (contact != null && mounted) {
      final name = contact.displayName.trim();
      if (name.isNotEmpty && !_friends.contains(name)) {
        HapticFeedback.selectionClick();
        setState(() {
          _friends.insert(0, name);
        });
      } else if (_friends.contains(name)) {
        NotificationHelper.show(message: '$name ya está en la lista.', type: NotificationType.info);
      }
    }
  }

  void _removeFriend(String name) {
    HapticFeedback.selectionClick();
    setState(() => _friends.remove(name));
  }

  Future<void> _submit() async {
    if (_totalAmount <= 0) {
      NotificationHelper.show(message: 'Ingresa un monto válido.', type: NotificationType.error);
      return;
    }
    if (_friends.isEmpty) {
      NotificationHelper.show(message: 'Agrega al menos a un amigo.', type: NotificationType.error);
      return;
    }
    if (_conceptCtrl.text.trim().isEmpty) {
      NotificationHelper.show(message: 'Ingresa un concepto (Ej: Cena).', type: NotificationType.error);
      return;
    }

    // Cerramos el teclado para que la animación de carga se vea limpia
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await DebtRepository.instance.addSplitDebts(
        concept: _conceptCtrl.text.trim(),
        friends: _friends,
        amountPerPerson: _perPerson,
      );

      setState(() { _isSuccess = true; _isLoading = false; });
      HapticFeedback.mediumImpact();

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop();
        NotificationHelper.show(message: '¡Cuenta dividida con éxito!', type: NotificationType.success);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      NotificationHelper.show(message: 'Error al dividir la cuenta.', type: NotificationType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final compact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: onSurf),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Dividir Gasto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: onSurf, letterSpacing: -0.3)),
      ),
      body: Column(
        children:[
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children:[
                const SizedBox(height: 10),

                // ── 1. MONTO TOTAL ──
                Text('Monto total a dividir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurf.withOpacity(0.4))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: TextFormField(
                    controller: _amountCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters:[FilteringTextInputFormatter.digitsOnly, _MoneyFmt()],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: _totalAmount > 0 ? const Color(0xFF0A84FF) : onSurf.withOpacity(0.3), letterSpacing: -1.5),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '\$ 0',
                      hintStyle: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: onSurf.withOpacity(0.2), letterSpacing: -1.5),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 2. CONCEPTO ──
                Text('Concepto', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurf.withOpacity(0.4))),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
                  child: TextFormField(
                    controller: _conceptCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurf),
                    decoration: InputDecoration(
                      hintText: 'Ej: Cena en PapaJohns',
                      hintStyle: TextStyle(fontSize: 15, color: onSurf.withOpacity(0.3)),
                      prefixIcon: Icon(Iconsax.receipt_2, size: 18, color: onSurf.withOpacity(0.4)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 3. PARTICIPANTES (Con Agenda) ──
                Text('¿Con quién lo compartes?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurf.withOpacity(0.4))),
                const SizedBox(height: 8),
                
                Row(
                  children:[
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: onSurf.withOpacity(0.1))),
                        child: Row(
                          children:[
                            // Botón de Contactos de Agenda
                            GestureDetector(
                              onTap: _pickContact,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 48,
                                alignment: Alignment.center,
                                child: const Icon(Iconsax.user_search, size: 20, color: Color(0xFF0A84FF)),
                              ),
                            ),
                            Container(width: 1, height: 24, color: onSurf.withOpacity(0.1)),
                            
                            // Campo de texto manual
                            Expanded(
                              child: TextFormField(
                                controller: _friendCtrl,
                                focusNode: _friendFocus,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _addFriend(),
                                style: TextStyle(fontSize: 15, color: onSurf, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: 'Escribe un nombre...',
                                  hintStyle: TextStyle(fontSize: 14, color: onSurf.withOpacity(0.3)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _addFriend,
                      child: Container(
                        height: 50, width: 50,
                        decoration: BoxDecoration(color: const Color(0xFF0A84FF).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.add_rounded, color: Color(0xFF0A84FF)),
                      ),
                    )
                  ],
                ),
                
                // Lista de burbujas (Chips)
                if (_friends.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _friends.map((friend) => Chip(
                      label: Text(friend, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      backgroundColor: onSurf.withOpacity(0.05),
                      side: BorderSide.none,
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => _removeFriend(friend),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 24),

                // ── 4. SWITCH: INCLUIRME ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children:[
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: const Color(0xFF30D158).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Iconsax.user_tick, size: 18, color: Color(0xFF30D158)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:[
                            Text('Yo también pago mi parte', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onSurf)),
                            Text('Divide entre ${_friends.length + 1}', style: TextStyle(fontSize: 12, color: onSurf.withOpacity(0.5))),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _includeMe,
                        activeColor: const Color(0xFF30D158),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _includeMe = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── 5. TARJETA DE RESULTADO ──
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: (_friends.isNotEmpty && _totalAmount > 0)
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A84FF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF0A84FF).withOpacity(0.3), width: 1),
                          ),
                          child: Column(
                            children:[
                              Text('Se registrarán ${_friends.length} deudas a tu favor', style: TextStyle(fontSize: 13, color: onSurf.withOpacity(0.6))),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children:[
                                  Text(compact.format(_perPerson), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0A84FF), letterSpacing: -1)),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 6, left: 4),
                                    child: Text('c/u', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0A84FF))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children:[
                                  const Icon(Iconsax.info_circle, size: 14, color: Color(0xFF0A84FF)),
                                  const SizedBox(width: 6),
                                  Text('Esto no descontará saldo de tus cuentas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: onSurf.withOpacity(0.6))),
                                ],
                              )
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // ── BOTÓN FLOTANTE (CON EL BUG DE LA ANIMACIÓN ARREGLADO) ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Obtenemos el ancho real de la pantalla en lugar de usar double.infinity
                  final fullWidth = constraints.maxWidth;
                  
                  return GestureDetector(
                    onTap: (_isLoading || _isSuccess) ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      // AQUÍ ESTÁ EL ARREGLO: Animamos entre 56 y el ancho matemático real
                      height: 56, 
                      width: _isLoading || _isSuccess ? 56 : fullWidth,
                      decoration: BoxDecoration(
                        color: _isSuccess ? const Color(0xFF30D158) : const Color(0xFF0A84FF),
                        borderRadius: BorderRadius.circular((_isLoading || _isSuccess) ? 28 : 16),
                        boxShadow:[BoxShadow(color: const Color(0xFF0A84FF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : _isSuccess
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
                                : const Text('Dividir Gasto', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  );
                }
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Formateador de moneda
class _MoneyFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next.copyWith(text: '');
    final n = int.tryParse(next.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final s = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(n);
    return next.copyWith(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}