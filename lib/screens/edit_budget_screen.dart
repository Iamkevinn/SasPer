// lib/screens/edit_budget_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

enum Periodicity { weekly, monthly, custom }

class _T {
  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w700}) => GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.4, height: 1.1);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w500}) => GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) => GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

const _kBlue = Color(0xFF0A84FF);
const _kRed  = Color(0xFFFF453A); // 👈 FIX: Color agregado

class EditBudgetScreen extends StatefulWidget {
  final Budget budget;
  const EditBudgetScreen({super.key, required this.budget});

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> with SingleTickerProviderStateMixin {
  final _repo = BudgetRepository.instance;
  final _amountCtrl = TextEditingController(); // 👈 El nombre correcto
  
  late Periodicity _periodicity;
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _autoRenew;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.budget.amount.toStringAsFixed(0);
    _startDate = widget.budget.startDate;
    _endDate = widget.budget.endDate;
    _autoRenew = widget.budget.autoRenew;
    _periodicity = Periodicity.values.firstWhere((e) => e.name == widget.budget.periodicity, orElse: () => Periodicity.custom);
  }

  void _calculateDates(Periodicity p) {
    final now = DateTime.now();
    setState(() {
      _periodicity = p;
      if (p == Periodicity.weekly) {
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _endDate = now.add(Duration(days: 7 - now.weekday));
      } else if (p == Periodicity.monthly) {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
      } else {
        _autoRenew = false;
        _startDate = widget.budget.startDate;
        _endDate = widget.budget.endDate;
      }
    });
  }

  Future<void> _update() async {
    FocusScope.of(context).unfocus();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    if (amount <= 0) {
      HapticFeedback.vibrate();
      NotificationHelper.show(message: 'Ingresa un monto válido.', type: NotificationType.error);
      return;
    }

    setState(() => _loading = true);
    try {
      await _repo.updateBudget(
        budgetId: widget.budget.id,
        categoryName: widget.budget.category,
        amount: amount,
        startDate: _startDate,
        endDate: _endDate,
        periodicity: _periodicity.name,
        autoRenew: _periodicity != Periodicity.custom && _autoRenew,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        EventService.instance.fire(AppEvent.budgetsChanged);
        // Le damos tiempo al toast para que se asiente en la pantalla 
        // antes de cerrar la ventana, dando un feeling más premium.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(message: 'Presupuesto actualizado', type: NotificationType.success);
        });
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) NotificationHelper.show(message: 'Error al actualizar.', type: NotificationType.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children:[
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 10),
            child: Row(
              children:[
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Text('Editar presupuesto', style: _T.display(24, c: onSurf)),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              children:[
                // Categoría ReadOnly
                Text('CATEGORÍA', style: _T.label(11, w: FontWeight.w700, c: onSurf.withOpacity(0.4))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children:[
                      Icon(Iconsax.category, size: 18, color: onSurf.withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Text(widget.budget.category, style: _T.label(16, w: FontWeight.w600, c: onSurf)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Periodicidad
                Text('PERIODICIDAD', style: _T.label(11, w: FontWeight.w700, c: onSurf.withOpacity(0.4))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children:[Periodicity.weekly, Periodicity.monthly, Periodicity.custom].map((p) {
                      final sel = _periodicity == p;
                      final label = p == Periodicity.weekly ? 'Semanal' : p == Periodicity.monthly ? 'Mensual' : 'Personaliz.';
                      return Expanded(
                        child: GestureDetector(
                          onTap: () { HapticFeedback.selectionClick(); _calculateDates(p); },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: sel ? surface : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: Text(label, style: _T.label(13, w: sel ? FontWeight.w700 : FontWeight.w500, c: sel ? onSurf : onSurf.withOpacity(0.5))),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                if (_periodicity == Periodicity.custom) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2101), initialDateRange: DateTimeRange(start: _startDate, end: _endDate));
                      if (picked != null) {
                        setState(() { _startDate = picked.start; _endDate = picked.end; });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children:[
                          const Icon(Iconsax.calendar_edit, size: 18, color: _kBlue),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${DateFormat.yMMMd('es_CO').format(_startDate)}  →  ${DateFormat.yMMMd('es_CO').format(_endDate)}', style: _T.label(14, w: FontWeight.w600, c: onSurf))),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Renovar automáticamente', style: _T.label(14, w: FontWeight.w600, c: onSurf)),
                      subtitle: Text('Al terminar se clona con el mismo límite.', style: _T.label(12, c: onSurf.withOpacity(0.4))),
                      value: _autoRenew,
                      activeColor: _kBlue,
                      onChanged: (v) => setState(() => _autoRenew = v),
                    ),
                  )
                ],
                const SizedBox(height: 24),

                // Límite
                Text('LÍMITE DEL PERÍODO', style: _T.label(11, w: FontWeight.w700, c: onSurf.withOpacity(0.4))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children:[
                      Text('\$', style: _T.display(28, c: onSurf.withOpacity(0.3))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _amountCtrl, // 👈 FIX: Usando el nombre correcto
                          keyboardType: TextInputType.number,
                          style: _T.display(40, c: onSurf),
                          decoration: InputDecoration(border: InputBorder.none, hintText: '0', hintStyle: _T.display(40, c: onSurf.withOpacity(0.2))),
                          onChanged: (_) => setState((){}),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Botón Guardar
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 20),
            child: GestureDetector(
              onTap: _loading ? null : _update,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56, width: double.infinity,
                decoration: BoxDecoration(color: _kBlue, borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: _loading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : Text('Actualizar presupuesto', style: _T.label(16, w: FontWeight.w700, c: Colors.white)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}