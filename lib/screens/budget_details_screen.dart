// lib/screens/budget_details_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/screens/edit_transaction_screen.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';

class _T {
  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.4, height: 1.1);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

class BudgetDetailsScreen extends StatefulWidget {
  final int budgetId;
  const BudgetDetailsScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  final _budgetRepo = BudgetRepository.instance;
  final _txRepo     = TransactionRepository.instance;

  Budget? _budget;
  bool _loading = true;
  late Future<List<Transaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Actualizar si el usuario edita o elimina algo desde otra pantalla
    EventService.instance.eventStream.listen((event) {
      if (event == AppEvent.transactionDeleted || event == AppEvent.transactionUpdated || event == AppEvent.budgetsChanged) {
        if (mounted) _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final budgets = await _budgetRepo.getBudgets();
      _budget = budgets.firstWhere((b) => b.id == widget.budgetId);
      _transactionsFuture = _txRepo.getTransactionsForBudget(_budget!);
    } catch (_) {
      _budget = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 👈 FIX: Ahora devuelve Future<bool>
  Future<bool> _deleteTx(Transaction tx) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmDeleteSheet(title: tx.description ?? 'este movimiento'),
      ),
    );

    if (ok == true && mounted) {
      await _txRepo.deleteTransaction(tx.id);
      EventService.instance.fire(AppEvent.transactionDeleted);
      NotificationHelper.show(message: 'Movimiento eliminado', type: NotificationType.success);
      _loadData();
      return true; // 👈 Retorna true si se eliminó
    }
    return false; // 👈 Retorna false si se canceló
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

    if (_loading) return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator(color: _kBlue)));
    if (_budget == null) return Scaffold(backgroundColor: bg, body: const Center(child: Text('El presupuesto ya no existe.')));

    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final color = _budget!.progress >= 1.0 ? _kRed : (_budget!.progress >= 0.85 ? _kOrange : _kGreen);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers:[
          // Header
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: bg,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            title: Column(
              children:[
                Text(_budget!.category, style: _T.label(16, w: FontWeight.w700, c: onSurf)),
                Text(_budget!.periodText, style: _T.label(12, c: onSurf.withOpacity(0.5))),
              ],
            ),
            centerTitle: true,
          ),

          // Tarjeta de Resumen
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow:[BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children:[
                    if (_budget!.isActive && _budget!.daysLeft >= 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Quedan ${_budget!.daysLeft} días', style: _T.label(11, w: FontWeight.w700, c: _kBlue)),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children:[
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:[
                            Text('Gastado', style: _T.label(12, c: onSurf.withOpacity(0.5))),
                            Text(fmt.format(_budget!.spentAmount), style: _T.mono(22, c: color)),
                          ],
                        )),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children:[
                            Text('Límite', style: _T.label(12, c: onSurf.withOpacity(0.5))),
                            Text(fmt.format(_budget!.amount), style: _T.mono(16, c: onSurf)),
                          ],
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(children:[
                        Container(height: 6, color: color.withOpacity(0.12)),
                        FractionallySizedBox(
                          widthFactor: _budget!.progress.clamp(0.0, 1.0),
                          child: Container(height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text('MOVIMIENTOS DEL PERÍODO', style: _T.label(11, w: FontWeight.w700, c: onSurf.withOpacity(0.4))),
            ),
          ),

          // Lista de transacciones
          FutureBuilder<List<Transaction>>(
            future: _transactionsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }
              final txs = snap.data ??[];
              if (txs.isEmpty) {
                return const SliverFillRemaining(child: Center(child: Text('Aún no hay gastos registrados en este período.')));
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = txs[index];
                      return TransactionTile(
                        transaction: tx,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => EditTransactionScreen(transaction: tx)));
                          _loadData();
                        },
                        onDeleted: () => _deleteTx(tx),
                      );
                    },
                    childCount: txs.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// 👈 FIX: Agregamos el BottomSheet de confirmación que faltaba aquí
class _ConfirmDeleteSheet extends StatelessWidget {
  final String title;
  const _ConfirmDeleteSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white, 
            borderRadius: BorderRadius.circular(20)
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children:[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _kRed.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Iconsax.trash, color: _kRed, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Eliminar', style: _T.display(18, c: onSurf)),
            const SizedBox(height: 4),
            Text('¿Seguro que deseas eliminar $title?', textAlign: TextAlign.center, style: _T.label(14, c: onSurf.withOpacity(0.5))),
            const SizedBox(height: 24),
            Row(children:[
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, false), child: Container(height: 50, decoration: BoxDecoration(color: onSurf.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Cancelar', style: _T.label(15, w: FontWeight.bold, c: onSurf)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(context, true), child: Container(height: 50, decoration: BoxDecoration(color: _kRed.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('Eliminar', style: _T.label(15, w: FontWeight.bold, c: _kRed)))))),
            ])
          ]),
        ),
      ),
    );
  }
}