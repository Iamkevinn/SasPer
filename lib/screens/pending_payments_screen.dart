// lib/screens/pending_payments_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Pagos Pendientes — Apple-first + fix bug "Pagar Cuota"
//
// BUG CORREGIDO:
// _InstallmentPendingCard recibía `accounts` del FutureBuilder padre.
// Si accSnap.data era null cuando se construía la lista → accounts = []
// → el sheet aparecía vacío y colapsado en altura mínima.
//
// FIX: _PaymentSourceSheet es StatefulWidget autónomo. Carga las cuentas
// en su propio initState(). Nunca depende del padre. Nunca puede quedar vacío.
//
// ELIMINADO (Material → iOS):
// · SliverAppBar + FlexibleSpaceBar → header blur sticky
// · AlertDialog editar cuotas → _EditProgressSheet blur
// · AlertDialog eliminar → _ConfirmDeleteSheet blur
// · showModalBottomSheet sin blur → BackdropFilter en todos
// · ListTile en sheets → filas con press state
// · Border.all colorido → opacity-based surface
// · BoxShape.circle en íconos → borderRadius
// · Colors.* hardcoded → paleta iOS
// · Función global _showPaymentSourcePicker duplicada → eliminada
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Tokens ─────────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s, fontWeight: w, color: c,
          letterSpacing: -0.4, height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);

  static TextStyle mono(double s,
          {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);

  static const double h = 20.0;
  static const double r = 18.0;
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kGrey   = Color(0xFF8E8E93);

final _fmt = NumberFormat.currency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class PendingPaymentsScreen extends StatelessWidget {
  const PendingPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(children: [
        // ── Header blur sticky ────────────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.93),
              padding: EdgeInsets.only(
                  top: statusH + 10, left: _T.h + 4,
                  right: _T.h, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('FINANZAS',
                      style: _T.label(10,
                          w: FontWeight.w700,
                          c: onSurf.withOpacity(0.35))),
                  Text('Pagos Pendientes',
                      style: _T.display(28, c: onSurf)),
                ],
              ),
            ),
          ),
        ),

        // ── Contenido ────────────────────────────────────────────────────
        Expanded(
          child: FutureBuilder<List<Account>>(
            future: AccountRepository.instance.getAccounts(),
            builder: (_, accSnap) {
              return StreamBuilder<List<RecurringTransaction>>(
                stream: RecurringRepository.instance
                    .getRecurringTransactionsStream(),
                builder: (_, recSnap) {
                  return StreamBuilder<List<Transaction>>(
                    stream: TransactionRepository.instance
                        .getTransactionsStream(),
                    builder: (_, txSnap) {
                      // Esperar a que los streams principales estén listos
                      if (recSnap.connectionState ==
                              ConnectionState.waiting ||
                          txSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      final accounts     = accSnap.data ?? [];
                      final recurring    = recSnap.data ?? [];
                      final transactions = txSnap.data ?? [];
                      final now          = DateTime.now();

                      // Gastos fijos vencidos o próximos (≤ 3 días)
                      final pendingRecurring = recurring.where((tx) =>
                          tx.nextDueDate.isBefore(
                              now.add(const Duration(days: 3)))).toList();

                      // Cuotas activas con pagos pendientes
                      final activeInstallments = transactions.where((tx) =>
                          tx.isInstallment == true &&
                          tx.installmentsCurrent != null &&
                          tx.installmentsTotal != null &&
                          tx.installmentsCurrent! <=
                              tx.installmentsTotal!).toList();

                      // Tarjetas con cuota de manejo
                      final creditCardsWithFee = accounts.where((a) =>
                          a.type == 'Tarjeta de Crédito' &&
                          a.maintenanceFee > 0).toList();

                      final isEmpty = pendingRecurring.isEmpty &&
                          activeInstallments.isEmpty &&
                          creditCardsWithFee.isEmpty;

                      if (isEmpty) return const _EmptyState();

                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            _T.h, 8, _T.h, 100),
                        children: [
                          // 1. Cuotas de manejo (obligaciones bancarias)
                          if (creditCardsWithFee.isNotEmpty) ...[
                            _SectionLabel('CUOTAS DE MANEJO'),
                            const SizedBox(height: 8),
                            ...creditCardsWithFee.map(
                                (acc) => _MaintenanceFeeCard(account: acc)),
                            const SizedBox(height: 24),
                          ],

                          // 2. Compras a cuotas
                          if (activeInstallments.isNotEmpty) ...[
                            _SectionLabel('COMPRAS A CUOTAS'),
                            const SizedBox(height: 8),
                            ...activeInstallments.map((tx) =>
                                _InstallmentCard(tx: tx, accounts: accounts)),
                            const SizedBox(height: 24),
                          ],

                          // 3. Gastos fijos recurrentes
                          if (pendingRecurring.isNotEmpty) ...[
                            _SectionLabel('GASTOS FIJOS'),
                            const SizedBox(height: 8),
                            ...pendingRecurring.map(
                                (tx) => _RecurringCard(tx: tx)),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA — GASTO FIJO RECURRENTE
// ─────────────────────────────────────────────────────────────────────────────

class _RecurringCard extends StatelessWidget {
  final RecurringTransaction tx;
  const _RecurringCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = tx.nextDueDate.isBefore(DateTime.now());
    final accent    = isOverdue ? _kRed : _kOrange;
    final bg        = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(isOverdue ? Iconsax.warning_2 : Iconsax.clock,
                    color: accent, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.description,
                      style: _T.label(15,
                          w: FontWeight.w700, c: onSurf)),
                  const SizedBox(height: 2),
                  Text(
                    isOverdue
                        ? 'Venció el ${DateFormat("d MMM", "es_CO").format(tx.nextDueDate)}'
                        : 'Vence el ${DateFormat("d MMM", "es_CO").format(tx.nextDueDate)}',
                    style: _T.label(12, c: accent)),
                ],
              ),
            ),
            Text(_fmt.format(tx.amount),
                style: _T.mono(17, c: onSurf)),
          ]),
        ),

        Container(height: 0.5, color: onSurf.withOpacity(0.07)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Expanded(child: _ActionBtn(
              label: 'Confirmar pago',
              icon: Iconsax.tick_circle,
              color: _kGreen,
              onTap: () async {
                HapticFeedback.mediumImpact();
                await RecurringRepository.instance.processPayment(tx.id);
                await widget_service.WidgetService.updateNextPaymentWidget();
                await widget_service.WidgetService
                    .updateUpcomingPaymentsWidget();
                NotificationHelper.show(
                    message: 'Pago registrado',
                    type: NotificationType.success);
              },
            )),
            const SizedBox(width: 8),
            _ActionBtn(
              label: 'Omitir',
              icon: Iconsax.arrow_right_1,
              color: _kGrey,
              onTap: () async {
                HapticFeedback.lightImpact();
                await RecurringRepository.instance.skipPayment(tx.id);
                await widget_service.WidgetService.updateNextPaymentWidget();
                await widget_service.WidgetService
                    .updateUpcomingPaymentsWidget();
                NotificationHelper.show(
                    message: 'Saltado al próximo mes',
                    type: NotificationType.info);
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA — COMPRA A CUOTAS
// ─────────────────────────────────────────────────────────────────────────────

class _InstallmentCard extends StatelessWidget {
  final Transaction   tx;
  final List<Account> accounts; // Solo para mostrar nombre de tarjeta
  const _InstallmentCard({required this.tx, required this.accounts});

  double get _cuotaValue =>
      tx.amount.abs() / tx.installmentsTotal!;
  int    get _restantes  =>
      (tx.installmentsTotal! - tx.installmentsCurrent!) + 1;
  double get _totalRestante => _cuotaValue * _restantes;

  String _cardName() {
    if (tx.creditCardId == null) return 'Tarjeta';
    try {
      return accounts.firstWhere((a) => a.id == tx.creditCardId).name;
    } catch (_) {
      return 'Tarjeta';
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                  child: Icon(Iconsax.card, color: _kBlue, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.description ?? 'Compra a cuotas',
                      style: _T.label(15,
                          w: FontWeight.w700, c: onSurf)),
                  const SizedBox(height: 2),
                  Text(
                    'Cuota ${tx.installmentsCurrent} de '
                    '${tx.installmentsTotal}  ·  ${_cardName()}',
                    style: _T.label(12,
                        c: _kBlue, w: FontWeight.w600)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt.format(_cuotaValue),
                  style: _T.mono(17, c: onSurf)),
              Text('c/cuota',
                  style: _T.label(10, c: onSurf.withOpacity(0.38))),
            ]),
          ]),
        ),

        Container(height: 0.5, color: onSurf.withOpacity(0.07)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            Expanded(child: _ActionBtn(
              label: 'Pagar cuota',
              icon: Iconsax.tick_circle,
              color: _kBlue,
              onTap: () => _openPaymentSheet(context),
            )),
            const SizedBox(width: 8),
            _ActionBtn(
              label: 'Opciones',
              icon: Iconsax.more,
              color: _kGrey,
              onTap: () => _openOptionsSheet(context),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Sheet: selección de cuenta ─────────────────────────────────────────
  // FIX CENTRAL: _PaymentSourceSheet carga las cuentas en su initState.
  // No recibe `accounts` del padre → nunca puede estar vacío.
  void _openPaymentSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _PaymentSourceSheet(
          title: 'Pagar cuota ${tx.installmentsCurrent} '
              'de ${tx.installmentsTotal}',
          amount: _cuotaValue,
          onAccountSelected: (acc) async {
            HapticFeedback.mediumImpact();
            await TransactionRepository.instance.payInstallment(
              originalTransaction: tx,
              paymentSourceAccountId: acc.id,
            );
            await widget_service.WidgetService.updateNextPaymentWidget();
            await widget_service.WidgetService
                .updateUpcomingPaymentsWidget();
            NotificationHelper.show(
                message: '¡Cuota registrada!',
                type: NotificationType.success);
          },
        ),
      ),
    );
  }

  // ── Sheet: opciones avanzadas ─────────────────────────────────────────
  void _openOptionsSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _InstallmentOptionsSheet(
          tx:            tx,
          cuotaValue:    _cuotaValue,
          totalRestante: _totalRestante,
          onPayAll: () => _openPayAllSheet(context),
          onEditProgress: () => _openEditProgressSheet(context),
          onDelete: () => _openDeleteSheet(context),
        ),
      ),
    );
  }

  void _openPayAllSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _PaymentSourceSheet(
          title: 'Pagar totalidad',
          amount: _totalRestante,
          onAccountSelected: (acc) async {
            HapticFeedback.mediumImpact();
            await TransactionRepository.instance.addTransaction(
              accountId: acc.id,
              amount: -_totalRestante,
              type: 'Gasto',
              category: tx.category ?? 'Pago Tarjeta',
              description: 'Pago total anticipado: ${tx.description}',
              transactionDate: DateTime.now(),
            );
            await TransactionRepository.instance
                .updateInstallmentProgress(
              transactionId: tx.id,
              currentInstallment: tx.installmentsTotal! + 1,
              totalInstallments: tx.installmentsTotal!,
            );
            await widget_service.WidgetService.updateNextPaymentWidget();
            await widget_service.WidgetService
                .updateUpcomingPaymentsWidget();
            NotificationHelper.show(
                message: '¡Deuda saldada por completo!',
                type: NotificationType.success);
          },
        ),
      ),
    );
  }

  void _openEditProgressSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _EditProgressSheet(tx: tx),
      ),
    );
  }

  void _openDeleteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmDeleteSheet(
          label: tx.description ?? 'esta compra',
          onConfirm: () async {
            HapticFeedback.heavyImpact();
            await TransactionRepository.instance
                .deleteTransaction(tx.id);
            await widget_service.WidgetService.updateNextPaymentWidget();
            await widget_service.WidgetService
                .updateUpcomingPaymentsWidget();
            NotificationHelper.show(
                message: 'Compra eliminada',
                type: NotificationType.info);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA — CUOTA DE MANEJO
// ─────────────────────────────────────────────────────────────────────────────

class _MaintenanceFeeCard extends StatelessWidget {
  final Account account;
  const _MaintenanceFeeCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: _kGrey.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
              child: Icon(Iconsax.bank, color: _kGrey, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cuota de Manejo',
                  style: _T.label(15,
                      w: FontWeight.w700, c: onSurf)),
              const SizedBox(height: 2),
              Text(account.name,
                  style: _T.label(12, c: onSurf.withOpacity(0.42))),
            ],
          ),
        ),
        Text(_fmt.format(account.maintenanceFee),
            style: _T.mono(17, c: onSurf)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET — SELECCIÓN DE CUENTA  ← EL FIX DEL BUG
// ─────────────────────────────────────────────────────────────────────────────
// Carga las cuentas de forma autónoma en initState().
// No recibe ni depende de ningún dato del widget padre.
// Muestra un loading indicator mientras carga.
// Muestra un estado vacío descriptivo si no hay cuentas.

class _PaymentSourceSheet extends StatefulWidget {
  final String title;
  final double amount;
  final Future<void> Function(Account) onAccountSelected;

  const _PaymentSourceSheet({
    required this.title,
    required this.amount,
    required this.onAccountSelected,
  });

  @override
  State<_PaymentSourceSheet> createState() => _PaymentSourceSheetState();
}

class _PaymentSourceSheetState extends State<_PaymentSourceSheet> {
  List<Account> _accounts = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      // 1. Obtener cuentas del repositorio
      final all = await AccountRepository.instance.getAccounts();
      
      // 2. Filtrar para mostrar solo cuentas que sirven para pagar (no crédito)
      // Normalizamos el string para evitar errores de mayúsculas/tildes
      final validAccounts = all.where((a) {
        final type = a.type.toLowerCase();
        return !type.contains('crédito') && !type.contains('credito');
      }).toList();

      if (mounted) {
        setState(() {
          _accounts = validAccounts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Error al cargar cuentas: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white; // Color sólido para evitar transparencias raras
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(widget.title,
              style: _T.display(18, c: onSurf),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(_fmt.format(widget.amount),
              style: _T.mono(24, c: _kBlue)),
          const SizedBox(height: 4),
          Text('¿Desde qué cuenta sale el dinero?',
              style: _T.label(13, c: onSurf.withOpacity(0.45))),
          const SizedBox(height: 14),

          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(16)),
            child: _buildContent(onSurf),
          ),

          const SizedBox(height: 10),
          _CancelRow(),
        ]),
      ),
    );
  }

  Widget _buildContent(Color onSurf) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Iconsax.warning_2, color: _kRed, size: 32),
          const SizedBox(height: 10),
          Text('Error de conexión', style: _T.label(15, c: onSurf, w: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_errorMessage!, textAlign: TextAlign.center, style: _T.label(13, c: onSurf.withOpacity(0.45))),
        ]),
      );
    }

    if (_accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Iconsax.wallet_remove, color: _kOrange, size: 32),
          const SizedBox(height: 10),
          Text('Sin cuentas de pago', style: _T.label(15, c: onSurf, w: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('No tienes cuentas de débito o efectivo registradas.', textAlign: TextAlign.center, style: _T.label(13, c: onSurf.withOpacity(0.45))),
        ]),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: _accounts.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(left: 56),
        child: Container(height: 0.5, color: onSurf.withOpacity(0.08))),
      itemBuilder: (_, i) => _AccountRow(
        account: _accounts[i],
        isFirst: i == 0,
        isLast: i == _accounts.length - 1,
        onTap: () async {
          Navigator.pop(context); // Cerrar sheet primero
          await widget.onAccountSelected(_accounts[i]); // Luego ejecutar acción
        },
      ),
    );
  }
}
// ── Fila de cuenta ────────────────────────────────────────────────────────────

class _AccountRow extends StatefulWidget {
  final Account account;
  final bool isFirst, isLast;
  final VoidCallback onTap;
  const _AccountRow({
    required this.account, required this.onTap,
    required this.isFirst, required this.isLast,
  });
  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final acc    = widget.account;
    final topR   = widget.isFirst ? const Radius.circular(16) : Radius.zero;
    final botR   = widget.isLast  ? const Radius.circular(16) : Radius.zero;

    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: _c.value > 0.01
                ? onSurf.withOpacity(0.04 * _c.value)
                : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: topR, topRight: topR,
              bottomLeft: botR, bottomRight: botR,
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: acc.accountColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Icon(acc.icon,
                  size: 17, color: acc.accountColor)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(acc.name,
                      style: _T.label(14,
                          w: FontWeight.w600, c: onSurf)),
                  const SizedBox(height: 2),
                  Text(_fmt.format(acc.balance),
                      style: _T.mono(12,
                          c: onSurf.withOpacity(0.50))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 17, color: onSurf.withOpacity(0.22)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET — OPCIONES DE CUOTA
// ─────────────────────────────────────────────────────────────────────────────

class _InstallmentOptionsSheet extends StatelessWidget {
  final Transaction tx;
  final double cuotaValue, totalRestante;
  final VoidCallback onPayAll, onEditProgress, onDelete;

  const _InstallmentOptionsSheet({
    required this.tx,
    required this.cuotaValue,
    required this.totalRestante,
    required this.onPayAll,
    required this.onEditProgress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: onSurf.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(tx.description ?? 'Compra a cuotas',
                style: _T.label(13,
                    c: onSurf.withOpacity(0.42),
                    w: FontWeight.w400)),
          ),
          Container(
            decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _SheetRow(
                icon: Iconsax.flash_1,
                label: 'Adelantar todas las cuotas',
                sublabel: 'Pagar ${_fmt.format(totalRestante)} de una vez',
                color: _kGreen, isFirst: true,
                onTap: () { Navigator.pop(context); onPayAll(); },
              ),
              _SheetRow(
                icon: Iconsax.edit,
                label: 'Ajustar progreso',
                sublabel: 'Cambiar en qué cuota vas',
                color: _kBlue,
                onTap: () { Navigator.pop(context); onEditProgress(); },
              ),
              _SheetRow(
                icon: Iconsax.trash,
                label: 'Eliminar compra',
                sublabel: 'Borrará esta deuda para siempre',
                color: _kRed, isLast: true, isDestructive: true,
                onTap: () { Navigator.pop(context); onDelete(); },
              ),
            ]),
          ),
          const SizedBox(height: 10),
          _CancelRow(),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET — EDITAR PROGRESO (reemplaza AlertDialog)
// ─────────────────────────────────────────────────────────────────────────────

class _EditProgressSheet extends StatefulWidget {
  final Transaction tx;
  const _EditProgressSheet({required this.tx});
  @override
  State<_EditProgressSheet> createState() => _EditProgressSheetState();
}

class _EditProgressSheetState extends State<_EditProgressSheet> {
  late int _current;
  late int _total;

  @override
  void initState() {
    super.initState();
    _current = widget.tx.installmentsCurrent!;
    _total   = widget.tx.installmentsTotal!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, bottom: 8,
          // Evita que el teclado tape el sheet si aparece
          top: MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 0,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: onSurf.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2))),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Text('Ajustar cuotas',
                  style: _T.display(18, c: onSurf)),
              const SizedBox(height: 24),

              // Cuota actual
              _CounterRow(
                label: 'Cuota actual',
                value: _current,
                onDecrement:
                    _current > 1 ? () => setState(() => _current--) : null,
                onIncrement: _current < _total
                    ? () => setState(() => _current++)
                    : null,
              ),
              const SizedBox(height: 14),

              // Total de cuotas
              _CounterRow(
                label: 'Total cuotas',
                value: _total,
                onDecrement: _total > _current
                    ? () => setState(() => _total--)
                    : null,
                onIncrement: () => setState(() => _total++),
              ),
              const SizedBox(height: 24),

              Row(children: [
                Expanded(child: _InlineBtn(
                    label: 'Cancelar',
                    color: onSurf,
                    onTap: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(child: _InlineBtn(
                    label: 'Guardar',
                    color: _kBlue,
                    onTap: () async {
                      Navigator.pop(context);
                      HapticFeedback.mediumImpact();
                      await TransactionRepository.instance
                          .updateInstallmentProgress(
                        transactionId: widget.tx.id,
                        currentInstallment: _current,
                        totalInstallments: _total,
                      );
                      await widget_service.WidgetService
                          .updateNextPaymentWidget();
                      await widget_service.WidgetService
                          .updateUpcomingPaymentsWidget();
                      NotificationHelper.show(
                          message: 'Progreso actualizado',
                          type: NotificationType.success);
                    })),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _CounterRow({
    required this.label, required this.value,
    required this.onDecrement, required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: _T.label(14, c: onSurf)),
        Row(children: [
          _StepBtn(icon: Icons.remove_rounded,
              color: _kGrey, onTap: onDecrement),
          SizedBox(
            width: 44,
            child: Center(child: Text('$value',
                style: _T.display(20, c: onSurf)))),
          _StepBtn(icon: Icons.add_rounded,
              color: _kBlue, onTap: onIncrement),
        ]),
      ],
    );
  }
}

class _StepBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.color,
      required this.onTap});
  @override
  State<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends State<_StepBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return GestureDetector(
      onTapDown:   disabled ? null : (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     disabled ? null : (_) {
        _c.reverse(); widget.onTap!(); },
      onTapCancel: disabled ? null : () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.88, _c.value)!,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: widget.color
                  .withOpacity(disabled ? 0.05 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Icon(widget.icon, size: 16,
                color: widget.color
                    .withOpacity(disabled ? 0.28 : 1.0))),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET — CONFIRMAR ELIMINACIÓN
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDeleteSheet extends StatelessWidget {
  final String label;
  final Future<void> Function() onConfirm;
  const _ConfirmDeleteSheet(
      {required this.label, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: onSurf.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2))),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: const Icon(Iconsax.trash,
                    color: _kRed, size: 24),
              ),
              const SizedBox(height: 12),
              Text('Eliminar compra',
                  style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text(
                '"$label"\nEsta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: _T.label(14,
                    c: onSurf.withOpacity(0.48),
                    w: FontWeight.w400)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _InlineBtn(
                    label: 'Cancelar', color: onSurf,
                    onTap: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(child: _InlineBtn(
                    label: 'Eliminar', color: _kRed, impact: true,
                    onTap: () async {
                      Navigator.pop(context);
                      await onConfirm();
                    })),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.copy_success, size: 64,
                color: _kGreen.withOpacity(0.28)),
            const SizedBox(height: 20),
            Text('¡Todo al día!',
                style: _T.display(24, c: onSurf)),
            const SizedBox(height: 8),
            Text(
              'No tienes pagos pendientes\npor confirmar.',
              textAlign: TextAlign.center,
              style: _T.label(14,
                  c: onSurf.withOpacity(0.45),
                  w: FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: _T.label(11,
              w: FontWeight.w700,
              c: onSurf.withOpacity(0.35))),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.95, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(isDark ? 0.14 : 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 15, color: widget.color),
                const SizedBox(width: 5),
                Text(widget.label,
                    style: _T.label(12,
                        c: widget.color, w: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color color;
  final bool isFirst, isLast, isDestructive;
  final VoidCallback onTap;

  const _SheetRow({
    required this.icon, required this.label, required this.color,
    required this.onTap,
    this.sublabel, this.isFirst = false, this.isLast = false,
    this.isDestructive = false,
  });
  @override
  State<_SheetRow> createState() => _SheetRowState();
}

class _SheetRowState extends State<_SheetRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color  = widget.isDestructive ? _kRed : widget.color;
    final topR   = widget.isFirst ? const Radius.circular(16) : Radius.zero;
    final botR   = widget.isLast  ? const Radius.circular(16) : Radius.zero;

    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: _c.value > 0.01
                ? color.withOpacity(0.05 * _c.value)
                : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: topR, topRight: topR,
              bottomLeft: botR, bottomRight: botR,
            ),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              child: Row(children: [
                Icon(widget.icon, size: 18, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label,
                          style: _T.label(15, c: color)),
                      if (widget.sublabel != null) ...[
                        const SizedBox(height: 2),
                        Text(widget.sublabel!,
                            style: _T.label(12,
                                c: onSurf.withOpacity(0.42))),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            if (!widget.isLast)
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Container(height: 0.5,
                    color: onSurf.withOpacity(0.07))),
          ]),
        ),
      ),
    );
  }
}

class _InlineBtn extends StatefulWidget {
  final String label;
  final Color color;
  final bool impact;
  final VoidCallback onTap;
  const _InlineBtn({required this.label, required this.color,
      required this.onTap, this.impact = false});
  @override
  State<_InlineBtn> createState() => _InlineBtnState();
}

class _InlineBtnState extends State<_InlineBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        widget.impact
            ? HapticFeedback.mediumImpact()
            : HapticFeedback.selectionClick();
      },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(widget.label,
                style: _T.label(15,
                    w: FontWeight.w600, c: widget.color))),
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatefulWidget {
  @override
  State<_CancelRow> createState() => _CancelRowState();
}

class _CancelRowState extends State<_CancelRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);

    return GestureDetector(
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); Navigator.pop(context); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('Cancelar',
                style: _T.label(16,
                    w: FontWeight.w600, c: _kBlue))),
          ),
        ),
      ),
    );
  }
}