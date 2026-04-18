// lib/screens/smart_summary_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';

// ─── TOKENS DE DISEÑO ────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w800}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -1.0, height: 1.1);
  static TextStyle title(double s, {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.4);
  static TextStyle body(double s, {Color? c, FontWeight w = FontWeight.w400}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, height: 1.5);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: 0.1);
}

const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kPurple = Color(0xFFBF5AF2);
const _kTeal   = Color(0xFF5AC8FA);

// ─── DATA CONTAINER ──────────────────────────────────────────────────────────
class _SummaryData {
  // Transacciones
  final double totalIncome;
  final double totalExpense;
  final String topCategory;
  final double topCategoryAmount;
  final String topDay;
  final String topMood;
  final double impulsiveExpense;

  // Metas
  final List<Goal> activeGoals;

  // Presupuestos
  final List<Budget> budgets;

  // Deudas
  final List<Debt> activeDebts;

  // Recurrentes próximas (7 días)
  final List<RecurringTransaction> upcomingRecurring;

  const _SummaryData({
    required this.totalIncome,
    required this.totalExpense,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.topDay,
    required this.topMood,
    required this.impulsiveExpense,
    required this.activeGoals,
    required this.budgets,
    required this.activeDebts,
    required this.upcomingRecurring,
  });
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────
class SmartSummaryScreen extends StatefulWidget {
  const SmartSummaryScreen({super.key});

  @override
  State<SmartSummaryScreen> createState() => _SmartSummaryScreenState();
}

class _SmartSummaryScreenState extends State<SmartSummaryScreen> {
  bool _isLoading = true;
  _SummaryData? _data;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth   = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final in7Days      = now.add(const Duration(days: 7));

      // ── Carga en paralelo para máxima velocidad ───────────────────────────
      final results = await Future.wait([
        TransactionRepository.instance.getFilteredTransactions(
          dateRange: DateTimeRange(start: startOfMonth, end: endOfMonth),
        ),
        GoalRepository.instance.getActiveGoals(),
        BudgetRepository.instance.getBudgets(),
        DebtRepository.instance.getActiveDebts(),
        RecurringRepository.instance.getAll(),
      ]);

      final txs        = results[0] as List<Transaction>;
      final goals      = results[1] as List<Goal>;
      final budgets    = results[2] as List<Budget>;
      final debts      = results[3] as List<Debt>;
      final allRecurring = results[4] as List<RecurringTransaction>;

      // ── Análisis de transacciones ─────────────────────────────────────────
      double income = 0, expense = 0, impulsive = 0;
      final catMap  = <String, double>{};
      final dayMap  = <int, double>{};
      final moodMap = <TransactionMood, double>{};

      for (final tx in txs) {
        final amount = tx.amount.abs();
        if (tx.amount > 0 || tx.type.toLowerCase() == 'ingreso') {
          income += amount;
        } else {
          expense += amount;
          final cat = tx.category ?? 'Otros';
          catMap[cat] = (catMap[cat] ?? 0) + amount;
          final day = tx.transactionDate.weekday;
          dayMap[day] = (dayMap[day] ?? 0) + amount;
          if (tx.mood != null) {
            moodMap[tx.mood!] = (moodMap[tx.mood!] ?? 0) + amount;
            if (tx.mood == TransactionMood.impulsivo) impulsive += amount;
          }
        }
      }

      String topCategory = '', topDay = '', topMood = '';
      double topCategoryAmount = 0;

      if (catMap.isNotEmpty) {
        final e = catMap.entries.reduce((a, b) => a.value > b.value ? a : b);
        topCategory = e.key;
        topCategoryAmount = e.value;
      }
      if (dayMap.isNotEmpty) {
        const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final e = dayMap.entries.reduce((a, b) => a.value > b.value ? a : b);
        topDay = days[e.key - 1];
      }
      if (moodMap.isNotEmpty) {
        final e = moodMap.entries.reduce((a, b) => a.value > b.value ? a : b);
        topMood = e.key.displayName;
      }

      // ── Recurrentes próximas 7 días ───────────────────────────────────────
      final upcoming = allRecurring
          .where((r) =>
              r.status == RecurringStatus.active &&
              !r.nextDueDate.isAfter(in7Days) &&
              !r.nextDueDate.isBefore(now))
          .toList()
        ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

      if (mounted) {
        setState(() {
          _data = _SummaryData(
            totalIncome: income,
            totalExpense: expense,
            topCategory: topCategory,
            topCategoryAmount: topCategoryAmount,
            topDay: topDay,
            topMood: topMood,
            impulsiveExpense: impulsive,
            activeGoals: goals,
            budgets: budgets,
            activeDebts: debts,
            upcomingRecurring: upcoming,
          );
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurf = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurf, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Tu mes en resumen', style: _T.title(16, c: onSurf)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kPurple))
          : RefreshIndicator(
              color: _kPurple,
              onRefresh: _loadAll,
              child: ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                children: [
                  _buildHeroConclusion(onSurf, isDark),
                  const SizedBox(height: 24),
                  _buildCashFlowInsight(onSurf, isDark),
                  const SizedBox(height: 16),
                  if (_data!.budgets.isNotEmpty) ...[
                    _buildBudgetsInsight(onSurf, isDark),
                    const SizedBox(height: 16),
                  ],
                  if (_data!.activeGoals.isNotEmpty) ...[
                    _buildGoalsInsight(onSurf, isDark),
                    const SizedBox(height: 16),
                  ],
                  if (_data!.activeDebts.isNotEmpty) ...[
                    _buildDebtsInsight(onSurf, isDark),
                    const SizedBox(height: 16),
                  ],
                  if (_data!.upcomingRecurring.isNotEmpty) ...[
                    _buildUpcomingInsight(onSurf, isDark),
                    const SizedBox(height: 16),
                  ],
                  if (_data!.totalExpense > 0) ...[
                    _buildBehaviorInsight(onSurf, isDark),
                    const SizedBox(height: 16),
                  ],
                  if (_data!.topMood.isNotEmpty) ...[
                    _buildMoodInsight(onSurf, isDark),
                  ],
                ],
              ),
            ),
    );
  }

  // ─── 1. VEREDICTO HERO ────────────────────────────────────────────────────
  Widget _buildHeroConclusion(Color onSurf, bool isDark) {
    final d = _data!;
    String title, subtitle;
    Color color;
    IconData icon;

    if (d.totalExpense == 0 && d.totalIncome == 0) {
      title    = 'Mes en blanco';
      subtitle = 'Aún no has registrado movimientos este mes. ¡Empieza a trackear tus gastos!';
      color    = _kBlue;
      icon     = Iconsax.magic_star5;
    } else if (d.totalExpense > d.totalIncome) {
      title    = 'Gastando de más';
      subtitle = 'Este mes tus gastos superan a tus ingresos. Frenemos un poco antes de que afecte tus ahorros.';
      color    = _kRed;
      icon     = Iconsax.warning_25;
    } else if (d.totalExpense > (d.totalIncome * 0.8)) {
      title    = 'Al límite';
      subtitle = 'Estás gastando casi todo lo que ingresas. Vas bien, pero tienes poco margen de maniobra.';
      color    = _kOrange;
      icon     = Iconsax.info_circle5;
    } else {
      title    = 'Excelente control';
      subtitle = 'Tus ingresos superan cómodamente tus gastos. Estás en posición ideal para ahorrar o invertir.';
      color    = _kGreen;
      icon     = Iconsax.shield_tick5;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 16),
          Text(title, style: _T.display(28, c: color)),
          const SizedBox(height: 8),
          Text(subtitle, style: _T.body(15, c: onSurf.withOpacity(0.75))),
        ],
      ),
    );
  }

  // ─── 2. FLUJO DE CAJA ─────────────────────────────────────────────────────
  Widget _buildCashFlowInsight(Color onSurf, bool isDark) {
    final d         = _data!;
    final fmt       = _fmt();
    final remaining = d.totalIncome - d.totalExpense;
    final savingPct = d.totalIncome > 0
        ? ((remaining / d.totalIncome) * 100).clamp(0, 100)
        : 0.0;

    return _InsightCard(
      isDark: isDark,
      icon: Iconsax.wallet_3,
      iconColor: _kBlue,
      title: 'El balance del mes',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: _T.body(15, c: onSurf.withOpacity(0.8)),
              children: [
                const TextSpan(text: 'Ingresaste '),
                TextSpan(text: fmt.format(d.totalIncome), style: _T.title(15, c: _kGreen)),
                const TextSpan(text: ' y gastaste '),
                TextSpan(text: fmt.format(d.totalExpense), style: _T.title(15, c: _kRed)),
                const TextSpan(text: '. '),
                if (remaining > 0) ...[
                  const TextSpan(text: 'Te sobran '),
                  TextSpan(text: fmt.format(remaining), style: _T.title(15, c: onSurf)),
                  TextSpan(
                    text: ' — eso es el ${savingPct.toStringAsFixed(0)}% de tus ingresos que podrías usar para ahorrar.',
                  ),
                ] else if (remaining < 0) ...[
                  const TextSpan(text: 'Llevas '),
                  TextSpan(text: fmt.format(remaining.abs()), style: _T.title(15, c: _kRed)),
                  const TextSpan(text: ' en rojo. Es momento de revisar qué se puede recortar.'),
                ] else ...[
                  const TextSpan(text: 'Estás exactamente en cero. Cero margen de error.'),
                ],
              ],
            ),
          ),
          if (d.totalIncome > 0) ...[
            const SizedBox(height: 14),
            _ProgressBar(
              value: (d.totalExpense / d.totalIncome).clamp(0.0, 1.0),
              color: remaining < 0
                  ? _kRed
                  : remaining < d.totalIncome * 0.2
                      ? _kOrange
                      : _kGreen,
              isDark: isDark,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Gastos', style: _T.label(11, c: onSurf.withOpacity(0.45))),
                Text('Ingresos', style: _T.label(11, c: onSurf.withOpacity(0.45))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── 3. PRESUPUESTOS ──────────────────────────────────────────────────────
  Widget _buildBudgetsInsight(Color onSurf, bool isDark) {
    final d        = _data!;
    final fmt      = _fmt();
    final exceeded = d.budgets.where((b) => b.status == BudgetStatus.exceeded).toList();
    final warning  = d.budgets.where((b) => b.status == BudgetStatus.warning).toList();
    final onTrack  = d.budgets.where((b) => b.status == BudgetStatus.onTrack).toList();

    String headline;
    Color headlineColor;
    if (exceeded.isNotEmpty) {
      headline      = '${exceeded.length} ${exceeded.length == 1 ? 'presupuesto superado' : 'presupuestos superados'} este mes.';
      headlineColor = _kRed;
    } else if (warning.isNotEmpty) {
      headline      = '${warning.length} ${warning.length == 1 ? 'presupuesto' : 'presupuestos'} rozando el límite.';
      headlineColor = _kOrange;
    } else {
      headline      = 'Todos tus presupuestos están bajo control.';
      headlineColor = _kGreen;
    }

    // Mostramos máx. 3 presupuestos: primero los problemáticos
    final toShow = [...exceeded, ...warning, ...onTrack].take(3).toList();

    return _InsightCard(
      isDark: isDark,
      icon: Iconsax.chart_2,
      iconColor: _kOrange,
      title: 'Presupuestos',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: _T.body(15, c: headlineColor, w: FontWeight.w600)),
          const SizedBox(height: 14),
          ...toShow.map((b) {
            final progress = b.progress.clamp(0.0, 1.0);
            final color    = b.status == BudgetStatus.exceeded
                ? _kRed
                : b.status == BudgetStatus.warning
                    ? _kOrange
                    : _kGreen;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          b.category,
                          style: _T.label(13, c: onSurf),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${fmt.format(b.spentAmount)} / ${fmt.format(b.amount)}',
                        style: _T.label(12, c: onSurf.withOpacity(0.55)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ProgressBar(value: progress, color: color, isDark: isDark),
                  if (b.daysLeft > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${b.daysLeft} días restantes',
                        style: _T.label(11, c: onSurf.withOpacity(0.4)),
                      ),
                    ),
                ],
              ),
            );
          }),
          if (d.budgets.length > 3)
            Text(
              '+ ${d.budgets.length - 3} presupuestos más',
              style: _T.label(12, c: onSurf.withOpacity(0.45)),
            ),
        ],
      ),
    );
  }

  // ─── 4. METAS ─────────────────────────────────────────────────────────────
  Widget _buildGoalsInsight(Color onSurf, bool isDark) {
    final d    = _data!;
    final fmt  = _fmt();
    final goals = d.activeGoals;

    // Meta más cercana a completarse
    final sorted = [...goals]..sort((a, b) => b.progress.compareTo(a.progress));
    final topGoal = sorted.first;
    final topPct  = (topGoal.progress * 100).toStringAsFixed(0);

    String intro;
    if (topGoal.progress >= 0.9) {
      intro = '¡Estás a nada de lograr "${topGoal.name}"! Solo te faltan ${fmt.format(topGoal.remainingAmount)}.';
    } else if (topGoal.progress >= 0.5) {
      intro = '"${topGoal.name}" ya lleva el $topPct% completado. Vas muy bien.';
    } else {
      intro = '"${topGoal.name}" apenas lleva el $topPct%. Cada aportación cuenta.';
    }

    // Suma total guardada vs objetivo total
    final totalSaved  = goals.fold(0.0, (s, g) => s + g.currentAmount);
    final totalTarget = goals.fold(0.0, (s, g) => s + g.targetAmount);

    return _InsightCard(
      isDark: isDark,
      icon: Iconsax.flag5,
      iconColor: _kTeal,
      title: 'Tus metas (${goals.length})',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(intro, style: _T.body(15, c: onSurf.withOpacity(0.85))),
          const SizedBox(height: 14),
          // Barra de la meta principal
          _ProgressBar(
            value: topGoal.progress,
            color: _kTeal,
            isDark: isDark,
          ),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(topGoal.currentAmount)} de ${fmt.format(topGoal.targetAmount)}',
            style: _T.label(11, c: onSurf.withOpacity(0.4)),
          ),
          if (goals.length > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kTeal.withOpacity(isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.money_recive, color: _kTeal, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: _T.body(13, c: onSurf.withOpacity(0.7)),
                        children: [
                          const TextSpan(text: 'En total tienes ahorrados '),
                          TextSpan(text: fmt.format(totalSaved), style: _T.title(13, c: _kTeal)),
                          const TextSpan(text: ' de '),
                          TextSpan(text: fmt.format(totalTarget), style: _T.title(13, c: onSurf)),
                          const TextSpan(text: ' en todas tus metas.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 5. DEUDAS ────────────────────────────────────────────────────────────
  Widget _buildDebtsInsight(Color onSurf, bool isDark) {
    final d    = _data!;
    final fmt  = _fmt();
    final debts = d.activeDebts;

    // Separar lo que debo vs lo que me deben
    final iOwe     = debts.where((d) => d.type == DebtType.debt).toList();
    final theyOwe  = debts.where((d) => d.type == DebtType.loan).toList();
    final totalOwed  = iOwe.fold(0.0,    (s, d) => s + d.currentBalance);
    final totalLoaned = theyOwe.fold(0.0, (s, d) => s + d.currentBalance);

    // Deuda con vencimiento próximo (< 15 días)
    final now    = DateTime.now();
    final urgent = debts
        .where((d) => d.dueDate != null && d.dueDate!.difference(now).inDays <= 15)
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    String intro;
    if (urgent.isNotEmpty) {
      final first = urgent.first;
      final days  = first.dueDate!.difference(now).inDays;
      intro = days == 0
          ? '"${first.name}" vence hoy. No lo dejes pasar.'
          : '"${first.name}" vence en $days ${days == 1 ? 'día' : 'días'}. Ponlo en tu radar.';
    } else if (iOwe.isNotEmpty) {
      intro = 'No tienes vencimientos urgentes. Buen momento para adelantar algún pago.';
    } else {
      intro = 'No tienes deudas activas. ¡Así se hace!';
    }

    return _InsightCard(
      isDark: isDark,
      icon: Iconsax.receipt_2,
      iconColor: _kRed,
      title: 'Deudas',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(intro, style: _T.body(15, c: onSurf.withOpacity(0.85))),
          const SizedBox(height: 14),
          Row(
            children: [
              if (iOwe.isNotEmpty)
                Expanded(
                  child: _DebtChip(
                    label: 'Debo',
                    amount: fmt.format(totalOwed),
                    color: _kRed,
                    isDark: isDark,
                  ),
                ),
              if (iOwe.isNotEmpty && theyOwe.isNotEmpty)
                const SizedBox(width: 8),
              if (theyOwe.isNotEmpty)
                Expanded(
                  child: _DebtChip(
                    label: 'Me deben',
                    amount: fmt.format(totalLoaned),
                    color: _kGreen,
                    isDark: isDark,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 6. PRÓXIMOS PAGOS FIJOS ─────────────────────────────────────────────
  Widget _buildUpcomingInsight(Color onSurf, bool isDark) {
    final d    = _data!;
    final fmt  = _fmt();
    final list = d.upcomingRecurring;
    final now  = DateTime.now();

    final totalUpcoming = list.fold(0.0, (s, r) => s + r.amount);

    String intro;
    if (list.length == 1) {
      intro = 'Tienes un pago fijo esta semana: "${list.first.description}".';
    } else {
      intro = 'Esta semana tienes ${list.length} pagos fijos por ${fmt.format(totalUpcoming)} en total.';
    }

    return _InsightCard(
      isDark: isDark,
      icon: Iconsax.calendar_tick,
      iconColor: _kPurple,
      title: 'Próximos 7 días',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(intro, style: _T.body(15, c: onSurf.withOpacity(0.85))),
          const SizedBox(height: 12),
          ...list.take(4).map((r) {
            final days = r.nextDueDate.difference(now).inDays;
            final dayLabel = days == 0
                ? 'Hoy'
                : days == 1
                    ? 'Mañana'
                    : 'En $days días';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kPurple.withOpacity(isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        dayLabel == 'Hoy' ? '!' : days.toString(),
                        style: _T.title(13, c: _kPurple),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.description,
                          style: _T.label(13, c: onSurf),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$dayLabel · ${r.category}',
                          style: _T.label(11, c: onSurf.withOpacity(0.45)),
                        ),
                      ],
                    ),
                  ),
                  Text(fmt.format(r.amount), style: _T.title(13, c: onSurf)),
                ],
              ),
            );
          }),
          if (list.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+ ${list.length - 4} más esta semana',
                style: _T.label(12, c: onSurf.withOpacity(0.45)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 7. HÁBITOS (Categoría + Día) ────────────────────────────────────────
  Widget _buildBehaviorInsight(Color onSurf, bool isDark) {
    final d   = _data!;
    final fmt = _fmt();
    if (d.totalExpense == 0) return const SizedBox.shrink();
    final pct = (d.topCategoryAmount / d.totalExpense * 100).toStringAsFixed(0);

    return _InsightCard(
      isDark: isDark,
      icon: Iconsax.search_normal_1,
      iconColor: _kOrange,
      title: 'Tus hábitos',
      content: RichText(
        text: TextSpan(
          style: _T.body(15, c: onSurf.withOpacity(0.8)),
          children: [
            const TextSpan(text: 'Tu mayor fuga de dinero este mes es en '),
            TextSpan(text: d.topCategory, style: _T.title(15, c: onSurf)),
            TextSpan(text: ' con ${fmt.format(d.topCategoryAmount)}, el $pct% de todos tus gastos.'),
            if (d.topDay.isNotEmpty) ...[
              const TextSpan(text: '\n\nAdemás, los '),
              TextSpan(text: d.topDay, style: _T.title(15, c: _kOrange)),
              const TextSpan(text: ' tienden a ser tu día más caro. Ten cuidado con esos días.'),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 8. EMOCIONES Y DINERO ────────────────────────────────────────────────
  Widget _buildMoodInsight(Color onSurf, bool isDark) {
    final d   = _data!;
    final fmt = _fmt();
    if (d.topMood.isEmpty) return const SizedBox.shrink();

    return _InsightCard(
      isDark: isDark,
      icon: Iconsax.heart,
      iconColor: _kPurple,
      title: 'Emociones y dinero',
      content: RichText(
        text: TextSpan(
          style: _T.body(15, c: onSurf.withOpacity(0.8)),
          children: [
            const TextSpan(text: 'La mayoría de tus gastos del mes fueron por motivos '),
            TextSpan(text: '"${d.topMood}"', style: _T.title(15, c: _kPurple)),
            const TextSpan(text: '.\n'),
            if (d.impulsiveExpense > 0) ...[
              const TextSpan(text: '\nDetectaste '),
              TextSpan(text: fmt.format(d.impulsiveExpense), style: _T.title(15, c: _kRed)),
              const TextSpan(text: ' en compras impulsivas. Pregúntate: ¿los necesitabas de verdad?'),
            ] else ...[
              const TextSpan(text: '\n¡Cero compras impulsivas este mes! Eso es autocontrol de verdad.'),
            ],
          ],
        ),
      ),
    );
  }

  NumberFormat _fmt() =>
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
}

// ─── BARRA DE PROGRESO REUTILIZABLE ──────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final bool isDark;

  const _ProgressBar({
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 7,
        backgroundColor: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.07),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ─── CHIP PARA DEUDAS ─────────────────────────────────────────────────────
class _DebtChip extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final bool isDark;

  const _DebtChip({
    required this.label,
    required this.amount,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _T.label(11, c: color.withOpacity(0.8))),
          const SizedBox(height: 2),
          Text(amount, style: _T.title(15, c: color)),
        ],
      ),
    );
  }
}

// ─── TARJETA BASE REUTILIZABLE ────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget content;

  const _InsightCard({
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.06))
            : Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(title, style: _T.title(15, c: onSurf)),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }
}