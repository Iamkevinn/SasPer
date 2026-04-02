// lib/screens/simulation_result_screen.dart
//
// Esta pantalla contiene la respuesta real a "¿puedo permitirme esto?".
// Todo lo que se muestra viene de datos reales del usuario.
// Las secciones aparecen solo cuando hay datos — nunca se inventa nada.
//
// ESTRUCTURA (en orden de importancia para la decisión):
// 1. Header — monto + categoría + veredicto con color semántico
// 2. Flujo de caja — qué pasa con el saldo a fin de mes (RPC real)
// 3. Presupuesto — impacto en la categoría (RPC real, aparece solo si hay presupuesto)
// 4. Metas afectadas — cuántos días de retraso por meta (query real, aparece si hay metas)
// 5. Gastos fijos pendientes — lo que aún tienes que pagar este mes (query real)
// 6. Deudas activas — contexto de compromisos existentes (query real, si aplica)
// 7. Nota de simulación — "esto no afecta tus registros"

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/simulation_models.dart';

// ─── Paleta iOS ──────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kOrange = Color(0xFFFF9F0A);
const _kRed    = Color(0xFFFF453A);

// ─── Tipografía ──────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s) => GoogleFonts.dmSans(
        fontSize: s, fontWeight: FontWeight.w700,
        letterSpacing: -0.4, height: 1.1,
      );
  static TextStyle label(double s, {FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w);
  static TextStyle mono(double s) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: FontWeight.w600);
}

final _fmt = NumberFormat.currency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _fmtCompact = NumberFormat.compactCurrency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 1);

// ─── Helpers de veredicto ─────────────────────────────────────────────────────
extension _VerdictX on SimulationVerdict {
  Color get color => switch (this) {
        SimulationVerdict.recommended    => _kGreen,
        SimulationVerdict.withCaution    => _kOrange,
        SimulationVerdict.notRecommended => _kRed,
      };

  String get label => switch (this) {
        SimulationVerdict.recommended    => 'Puedes permitírtelo',
        SimulationVerdict.withCaution    => 'Con precaución',
        SimulationVerdict.notRecommended => 'No recomendado',
      };

  IconData get icon => switch (this) {
        SimulationVerdict.recommended    => Iconsax.shield_tick,
        SimulationVerdict.withCaution    => Iconsax.warning_2,
        SimulationVerdict.notRecommended => Iconsax.danger,
      };
}

// =============================================================================
// SCREEN
// =============================================================================

class SimulationResultScreen extends StatefulWidget {
  final SimulationResult result;

  const SimulationResultScreen({super.key, required this.result});

  @override
  State<SimulationResultScreen> createState() =>
      _SimulationResultScreenState();
}

class _SimulationResultScreenState extends State<SimulationResultScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final surfBg  = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final result  = widget.result;
    final verdict = result.verdict;

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

            // ── Header blur ─────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _BlurHeader(
                scaffoldBg: bg,
                onBack: () => Navigator.pop(context),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── 1. VEREDICTO HERO ──────────────────────────────────
                  _VerdictHero(
                    verdict: verdict,
                    message: result.verdictMessage,
                    isDark:  isDark,
                  ),
                  const SizedBox(height: 12),

                  // ── 2. FLUJO DE CAJA ───────────────────────────────────
                  // Siempre presente — viene de la RPC
                  _SectionLabel('Flujo de caja a fin de mes', isDark: isDark),
                  const SizedBox(height: 8),
                  _CashFlowCard(
                    impact: result.savingsImpact,
                    verdict: result.verdict,
                    isDark: isDark,
                    surfBg: surfBg,
                  ),
                  const SizedBox(height: 24),

                  // ── 3. PRESUPUESTO ─────────────────────────────────────
                  // Solo si hay presupuesto activo para la categoría
                  if (result.budgetImpact != null) ...[
                    _SectionLabel(
                        'Presupuesto en ${result.budgetImpact!.categoryName}',
                        isDark: isDark),
                    const SizedBox(height: 8),
                    _BudgetCard(
                      impact: result.budgetImpact!,
                      isDark: isDark,
                      surfBg: surfBg,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── 4. METAS AFECTADAS ─────────────────────────────────
                  // Solo si hay metas con savings_amount configurado
                  if (result.affectedGoals.isNotEmpty) ...[
                    _SectionLabel('Metas que se verían afectadas',
                        isDark: isDark),
                    const SizedBox(height: 8),
                    ...result.affectedGoals.map((g) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _GoalImpactCard(
                            goal: g, isDark: isDark, surfBg: surfBg,
                          ),
                        )),
                    const SizedBox(height: 16),
                  ],

                  // ── 5. GASTOS FIJOS PENDIENTES ─────────────────────────
                  // Solo si hay gastos recurrentes este mes
                  if (result.recurringContext.hasData) ...[
                    _SectionLabel('Gastos fijos pendientes este mes',
                        isDark: isDark),
                    const SizedBox(height: 8),
                    _RecurringCard(
                      ctx: result.recurringContext,
                      isDark: isDark,
                      surfBg: surfBg,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── 6. DEUDAS ACTIVAS ──────────────────────────────────
                  // Solo si hay deudas — da contexto sin alarmar
                  if (result.debtContext.hasData) ...[
                    _SectionLabel('Compromisos existentes', isDark: isDark),
                    const SizedBox(height: 8),
                    _DebtContextCard(
                      ctx: result.debtContext,
                      isDark: isDark,
                      surfBg: surfBg,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── 7. NOTA LEGAL ──────────────────────────────────────
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Esta simulación no afecta tus registros ni mueve dinero.',
                        style: _T.label(12).copyWith(
                          color: isDark
                              ? Colors.white.withOpacity(0.25)
                              : Colors.black.withOpacity(0.25),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// VEREDICTO HERO
// =============================================================================

class _VerdictHero extends StatelessWidget {
  final SimulationVerdict verdict;
  final String message;
  final bool isDark;

  const _VerdictHero({
    required this.verdict,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color   = verdict.color;
    final surfBg  = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(verdict.icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verdict.label,
                  style: _T.display(18).copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: _T.label(14).copyWith(
                    color: isDark
                        ? Colors.white.withOpacity(0.55)
                        : Colors.black.withOpacity(0.55),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FLUJO DE CAJA
// =============================================================================

// =============================================================================
// FLUJO DE CAJA — reemplaza _CashFlowCard completo
// =============================================================================

class _CashFlowCard extends StatelessWidget {
  final SavingsImpact impact;
  final SimulationVerdict verdict;
  final bool isDark;
  final Color surfBg;

  const _CashFlowCard({
    required this.impact,
    required this.verdict,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final projected = impact.projectedEOMBalance;
    final current   = impact.currentEOMBalance;
    final diff      = current - projected;
    final isNeg     = projected < 0;

    final bool flowNegButSafe =
        isNeg && verdict == SimulationVerdict.recommended;

    final bool flowNegAndBad =
        isNeg && verdict == SimulationVerdict.notRecommended;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: flowNegButSafe
            ? Border.all(color: _kOrange.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        children: [
          // ── Fila principal ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _FlowColumn(
                  label: 'Proyección actual',
                  value: _fmtCompact.format(current),
                  color: isDark
                      ? Colors.white.withOpacity(0.6)
                      : Colors.black.withOpacity(0.6),
                  isDark: isDark,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark
                      ? Colors.white.withOpacity(0.2)
                      : Colors.black.withOpacity(0.2),
                  size: 18,
                ),
              ),
              Expanded(
                child: _FlowColumn(
                  label: 'Si haces este gasto',
                  value: _fmtCompact.format(projected),
                  color: isNeg ? _kRed : _kGreen,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          // ── Reducción + contexto ─────────────────────────────────────
          if (diff > 0) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reducción en tu flujo de caja',
                  style: _T.label(13).copyWith(
                    color: isDark
                        ? Colors.white.withOpacity(0.45)
                        : Colors.black.withOpacity(0.45),
                  ),
                ),
                Text(
                  '− ${_fmtCompact.format(diff)}',
                  style: _T.mono(13).copyWith(
                    // Gris neutro si el flujo sigue positivo,
                    // rojo si queda negativo
                    color: isNeg
                        ? _kRed
                        : (isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4)),
                  ),
                ),
              ],
            ),

            // Línea de contexto debajo de la reducción
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isNeg
                    ? 'El mes cerraría en negativo — revisa si tienes ahorros de respaldo.'
                    : 'Tu flujo del mes seguiría positivo en ${_fmtCompact.format(projected.abs())}.',
                style: _T.label(11).copyWith(
                  color: isNeg
                      ? _kOrange
                      : (isDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.black.withOpacity(0.3)),
                ),
              ),
            ),
          ],

          // ── Contexto naranja: verde pero flujo negativo ──────────────
          if (flowNegButSafe) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kOrange.withOpacity(isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Iconsax.warning_2, size: 16, color: _kOrange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu saldo bancario cubre este gasto, pero terminarás el mes '
                      'gastando más de lo que ingresaste. Asegúrate de tener '
                      'ahorros que respalden esa diferencia.',
                      style: _T.label(12).copyWith(
                        color: _kOrange,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Contexto rojo: flujo negativo y veredicto malo ───────────
          if (flowNegAndBad) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Iconsax.danger, size: 16, color: _kRed),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este gasto dejaría tu flujo del mes en negativo y además '
                      'comprometería tu liquidez real. No es el momento.',
                      style: _T.label(12).copyWith(
                        color: _kRed,
                        height: 1.4,
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
}
class _FlowColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _FlowColumn({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _T.label(11).copyWith(
            color: isDark
                ? Colors.white.withOpacity(0.35)
                : Colors.black.withOpacity(0.35),
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: _T.mono(18).copyWith(color: color)),
        Text(
          'fin de mes',
          style: _T.label(10).copyWith(
            color: isDark
                ? Colors.white.withOpacity(0.25)
                : Colors.black.withOpacity(0.25),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// PRESUPUESTO
// =============================================================================

class _BudgetCard extends StatelessWidget {
  final BudgetImpact impact;
  final bool isDark;
  final Color surfBg;

  const _BudgetCard({
    required this.impact,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final current    = impact.currentProgress.clamp(0.0, 1.0);
    final projected  = impact.clampedProjectedProgress;
    final exceedColor = impact.willExceed ? _kRed : _kOrange;
    final safeColor   = _kGreen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: impact.willExceed
            ? Border.all(color: _kRed.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra actual
          _BudgetBar(
            label: 'Gastado hasta ahora',
            value: current,
            amount: impact.currentSpent,
            budget: impact.budgetAmount,
            color: current > 0.8 ? _kRed : current > 0.5 ? _kOrange : safeColor,
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Barra proyectada
          _BudgetBar(
            label: 'Si haces este gasto',
            value: projected,
            amount: impact.projectedSpent,
            budget: impact.budgetAmount,
            color: impact.willExceed ? exceedColor : _kOrange,
            isDark: isDark,
            showExceed: impact.willExceed,
            projectedLabel: impact.formattedProjectedProgress,
          ),
        ],
      ),
    );
  }
}

class _BudgetBar extends StatelessWidget {
  final String label;
  final double value;      // 0.0–1.0
  final double amount;
  final double budget;
  final Color color;
  final bool isDark;
  final bool showExceed;
  final String? projectedLabel;

  const _BudgetBar({
    required this.label,
    required this.value,
    required this.amount,
    required this.budget,
    required this.color,
    required this.isDark,
    this.showExceed = false,
    this.projectedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: _T.label(12).copyWith(
                color: isDark
                    ? Colors.white.withOpacity(0.45)
                    : Colors.black.withOpacity(0.45),
              ),
            ),
            Row(
              children: [
                Text(
                  _fmtCompact.format(amount),
                  style: _T.mono(12).copyWith(color: color),
                ),
                Text(
                  ' / ${_fmtCompact.format(budget)}',
                  style: _T.label(12).copyWith(
                    color: isDark
                        ? Colors.white.withOpacity(0.3)
                        : Colors.black.withOpacity(0.3),
                  ),
                ),
                if (showExceed && projectedLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      projectedLabel!,
                      style: _T.mono(10).copyWith(color: _kRed),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// METAS AFECTADAS
// =============================================================================

class _GoalImpactCard extends StatelessWidget {
  final GoalImpact goal;
  final bool isDark;
  final Color surfBg;

  const _GoalImpactCard({
    required this.goal,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final days    = goal.daysDelayed ?? 0;
    final newDate = goal.newTargetDate;
    final pct     = (goal.progressPct * 100).clamp(0, 100);

    // Color según retraso
    final color = days > 60 ? _kRed : days > 14 ? _kOrange : _kOrange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.18 : 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Iconsax.flag, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.goalName,
                        style: _T.label(15, w: FontWeight.w600)),
                    Text(
                      '${pct.toStringAsFixed(0)} % completada',
                      style: _T.label(12).copyWith(
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              // Badge de retraso
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$days días',
                  style: _T.mono(12).copyWith(color: color),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de progreso actual
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progressPct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
              valueColor: const AlwaysStoppedAnimation(_kGreen),
            ),
          ),

          const SizedBox(height: 10),

          // Datos reales: quedan / objetivo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Faltan ${_fmtCompact.format(goal.remaining)}',
                style: _T.label(12).copyWith(
                  color: isDark
                      ? Colors.white.withOpacity(0.45)
                      : Colors.black.withOpacity(0.45),
                ),
              ),
              if (newDate != null)
                Text(
                  'Nueva fecha estimada: ${_formatDate(newDate)}',
                  style: _T.label(12).copyWith(color: color),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day} ${_monthName(d.month)} ${d.year}';
  }

  String _monthName(int m) => const [
        '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ][m];
}

// =============================================================================
// GASTOS FIJOS PENDIENTES
// =============================================================================

class _RecurringCard extends StatelessWidget {
  final RecurringContext ctx;
  final bool isDark;
  final Color surfBg;

  const _RecurringCard({
    required this.ctx,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Resumen total
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ctx.count} gasto${ctx.count > 1 ? 's' : ''} pendiente${ctx.count > 1 ? 's' : ''}',
                      style: _T.label(14, w: FontWeight.w600),
                    ),
                    Text(
                      'Este mes aún tienes que pagar',
                      style: _T.label(12).copyWith(
                        color: isDark
                            ? Colors.white.withOpacity(0.4)
                            : Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                Text(
                  _fmtCompact.format(ctx.pendingThisMonth),
                  style: _T.mono(18).copyWith(color: _kOrange),
                ),
              ],
            ),
          ),

          // Items individuales (máx. 3)
          if (ctx.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
            ),
            ...ctx.items.map((item) => _RecurringRow(
                  item: item,
                  isDark: isDark,
                )),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _RecurringRow extends StatelessWidget {
  final RecurringItem item;
  final bool isDark;

  const _RecurringRow({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final daysLeft = item.nextDueDate.difference(DateTime.now()).inDays;
    final urgentColor = daysLeft <= 0
        ? _kRed
        : daysLeft <= 3
            ? _kOrange
            : (isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description, style: _T.label(14)),
                Text(
                  daysLeft <= 0
                      ? 'Vence hoy'
                      : daysLeft == 1
                          ? 'Vence mañana'
                          : 'Vence en $daysLeft días',
                  style: _T.label(11).copyWith(color: urgentColor),
                ),
              ],
            ),
          ),
          Text(
            _fmtCompact.format(item.amount),
            style: _T.mono(13).copyWith(
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DEUDAS ACTIVAS
// =============================================================================

class _DebtContextCard extends StatelessWidget {
  final DebtContext ctx;
  final bool isDark;
  final Color surfBg;

  const _DebtContextCard({
    required this.ctx,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kRed.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Iconsax.receipt_2, size: 18, color: _kRed),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ctx.count} deuda${ctx.count > 1 ? 's' : ''} activa${ctx.count > 1 ? 's' : ''}',
                  style: _T.label(14, w: FontWeight.w600),
                ),
                Text(
                  'Tienes compromisos de deuda existentes',
                  style: _T.label(12).copyWith(
                    color: isDark
                        ? Colors.white.withOpacity(0.4)
                        : Colors.black.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _fmtCompact.format(ctx.totalBalance),
            style: _T.mono(15).copyWith(color: _kRed),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLUR HEADER
// =============================================================================

class _BlurHeader extends SliverPersistentHeaderDelegate {
  final Color scaffoldBg;
  final VoidCallback onBack;

  const _BlurHeader({required this.scaffoldBg, required this.onBack});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
      BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          color: scaffoldBg.withOpacity(0.93),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _BackBtn(onBack: onBack),
              const SizedBox(width: 8),
              Text('Análisis del gasto',
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_BlurHeader o) => false;
}

class _BackBtn extends StatefulWidget {
  final VoidCallback onBack;
  const _BackBtn({required this.onBack});

  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) async {
        await _c.reverse();
        widget.onBack();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: ui.lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _kBlue,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION LABEL
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: isDark
            ? Colors.white.withOpacity(0.35)
            : Colors.black.withOpacity(0.35),
      ),
    );
  }
}