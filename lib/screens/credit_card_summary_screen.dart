import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/utils/credit_card_engine.dart';

class _T {
  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.4, height: 1.1);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
  static const double r = 18.0;
}

const _kBlue = Color(0xFF0A84FF);
const _kGreen = Color(0xFF30D158);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kGrey = Color(0xFF8E8E93);
final _fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

class CreditCardSummaryScreen extends StatefulWidget {
  final Account cardAccount;

  const CreditCardSummaryScreen({super.key, required this.cardAccount});

  @override
  State<CreditCardSummaryScreen> createState() => _CreditCardSummaryScreenState();
}

class _CreditCardSummaryScreenState extends State<CreditCardSummaryScreen> {
  bool _isLoading = true;
  List<Transaction> _transactions = [];
  Map<String, double> _debtSegments = {'current_cycle': 0, 'next_cycle': 0};
  Map<String, double> _analytics = {'totalDebt': 0, 'monthlyObligation': 0};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final txs = await AccountRepository.instance.getTransactionsForAccount(widget.cardAccount.id);
      final analytics = await AccountRepository.instance.getCreditCardAnalytics(widget.cardAccount.id);
      
      setState(() {
        _transactions = txs;
        _analytics = analytics;
        _debtSegments = CreditCardEngine.segmentDebtByClosingDate(widget.cardAccount, txs);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurf = theme.colorScheme.onSurface;
    final card = widget.cardAccount;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: onSurf, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Resumen Inteligente', style: _T.label(16, w: FontWeight.w700, c: onSurf)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : RefreshIndicator(
              color: _kBlue,
              onRefresh: _loadData,
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                children: [
                  _buildMainCardStatus(card, onSurf, isDark),
                  const SizedBox(height: 24),
                  _buildDatesRow(card, onSurf, isDark),
                  const SizedBox(height: 24),
                  _buildDebtBreakdown(onSurf, isDark),
                  const SizedBox(height: 24),
                  _buildCreditScoreInsight(card, onSurf, isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildMainCardStatus(Account card, Color onSurf, bool isDark) {
    final double totalDebt = card.currentDebt.abs();
    final double available = card.availableCredit;
    final double utilization = card.creditLimit > 0 ? (totalDebt / card.creditLimit) : 0;
    final String utilPct = '${(utilization * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(_T.r),
        border: isDark ? null : Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: card.accountColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(card.icon, color: card.accountColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name, style: _T.label(16, w: FontWeight.w700, c: onSurf)),
                    Text('Tarjeta de Crédito', style: _T.label(12, c: onSurf.withOpacity(0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deuda Total', style: _T.label(12, c: onSurf.withOpacity(0.5))),
                  const SizedBox(height: 4),
                  Text(_fmt.format(totalDebt), style: _T.display(24, c: onSurf)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (utilization > 0.8 ? _kRed : (utilization > 0.5 ? _kOrange : _kGreen)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$utilPct Uso', style: _T.mono(12, c: utilization > 0.8 ? _kRed : (utilization > 0.5 ? _kOrange : _kGreen), w: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: utilization,
              backgroundColor: onSurf.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(utilization > 0.8 ? _kRed : (utilization > 0.5 ? _kOrange : _kBlue)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text('Cupo disponible: ${_fmt.format(available)}', style: _T.mono(12, c: onSurf.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildDatesRow(Account card, Color onSurf, bool isDark) {
    final nextClosing = CreditCardEngine.getNextClosingDate(card);
    final nextDue = CreditCardEngine.getNextDueDate(card);

    return Row(
      children: [
        Expanded(child: _DateCard(title: 'Próximo Corte', date: nextClosing, icon: Iconsax.calendar_1, color: _kBlue, isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(child: _DateCard(title: 'Límite de Pago', date: nextDue, icon: Iconsax.timer_1, color: _kOrange, isDark: isDark)),
      ],
    );
  }

  Widget _buildDebtBreakdown(Color onSurf, bool isDark) {
    final currentDebt = _debtSegments['current_cycle'] ?? 0;
    final nextDebt = _debtSegments['next_cycle'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(_T.r),
        border: isDark ? null : Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.receipt_2, size: 20, color: _kGrey),
              const SizedBox(width: 10),
              Text('Desglose del Estado de Cuenta', style: _T.label(15, w: FontWeight.w700, c: onSurf)),
            ],
          ),
          const SizedBox(height: 20),
          _BreakdownRow(title: 'Facturado para pagar ahora', amount: currentDebt, color: _kRed),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 12),
            child: Text('Compras realizadas antes de tu último corte.', style: _T.label(11, c: onSurf.withOpacity(0.4))),
          ),
          Container(height: 0.5, color: onSurf.withOpacity(0.08)),
          const SizedBox(height: 12),
          _BreakdownRow(title: 'Pasa para el próximo mes', amount: nextDebt, color: onSurf),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text('Compras que hiciste después del corte, tienes más tiempo para pagarlas.', style: _T.label(11, c: onSurf.withOpacity(0.4))),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditScoreInsight(Account card, Color onSurf, bool isDark) {
    final totalDebt = card.currentDebt.abs();
    final currentCycleDebt = _debtSegments['current_cycle'] ?? 0;
    
    final score = CreditCardEngine.calculateCreditScoreImpact(card, currentCycleDebt, totalDebt);
    
    String message = '';
    String emoji = '';
    Color scoreColor = _kBlue;

    if (score >= 90) { message = '¡Excelente! Eres un "Totalero". Las centrales de riesgo aman este comportamiento.'; emoji = '🌟'; scoreColor = _kGreen;}
    else if (score >= 70) { message = 'Vas bien, pero cuidado con el cupo. Intenta bajar la deuda para mejorar tu score.'; emoji = '👍'; scoreColor = _kBlue;}
    else if (score >= 50) { message = 'Alerta. Tu uso está alto y podrías pagar muchos intereses. Intenta no usarla este mes.'; emoji = '⚠️'; scoreColor = _kOrange;}
    else { message = 'Peligro financiero. Tu utilización es extrema y los intereses te comerán. ¡Frena el gasto ya!'; emoji = '🚨'; scoreColor = _kRed;}

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(_T.r),
        border: Border.all(color: scoreColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text('Análisis de Vida Crediticia', style: _T.label(15, w: FontWeight.w700, c: scoreColor)),
            ],
          ),
          const SizedBox(height: 12),
          Text(message, style: _T.label(13, c: onSurf.withOpacity(0.8), w: FontWeight.w500).copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String title;
  final DateTime date;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _DateCard({required this.title, required this.date, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(_T.r),
        border: isDark ? null : Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 12),
          Text(title, style: _T.label(12, c: onSurf.withOpacity(0.5))),
          const SizedBox(height: 4),
          Text(DateFormat("d MMM", "es_CO").format(date), style: _T.display(18, c: onSurf)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;

  const _BreakdownRow({required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title, style: _T.label(13, w: FontWeight.w600, c: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
        Text(_fmt.format(amount), style: _T.mono(15, c: color)),
      ],
    );
  }
}