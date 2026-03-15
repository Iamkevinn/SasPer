// lib/screens/add_transfer_screen.dart
//
// FILOSOFÍA: Cada elemento tiene propósito. Sin datos inventados.
// Sin celebraciones inapropiadas. Sin "IA" que no existe.
// La información que el usuario necesita, cuando la necesita, sin ruido.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'dart:developer' as developer;

import 'package:sasper/widgets/shared/custom_notification_widget.dart';

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
  static TextStyle mono(double s) => GoogleFonts.dmMono(
    fontSize: s, fontWeight: FontWeight.w600,
  );
}

final _fmt = NumberFormat.currency(
  locale: 'es_CO', symbol: '\$', decimalDigits: 0,
);

// =============================================================================
// SCREEN
// =============================================================================

class AddTransferScreen extends StatefulWidget {
  const AddTransferScreen({super.key});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen>
    with TickerProviderStateMixin {

  final _accountRepository = AccountRepository.instance;
  final _amountController = TextEditingController(text: '');
  final _descriptionController = TextEditingController();
  late final Future<List<Account>> _accountsFuture;

  Account? _fromAccount;
  Account? _toAccount;

  bool _isLoading = false;

  // Press state para el botón
  late final AnimationController _btnAnim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 70),
  );

  // Fade-in inicial
  late final AnimationController _fadeAnim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 280),
  );

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    _fadeAnim.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _btnAnim.dispose();
    _fadeAnim.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double get _amount =>
      double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  bool get _canSubmit =>
      _fromAccount != null &&
      _toAccount != null &&
      _fromAccount!.id != _toAccount!.id &&
      _amount > 0 &&
      _amount <= (_fromAccount?.balance ?? 0);

  // Nivel de riesgo basado en % del saldo — dato REAL
  _RiskLevel get _riskLevel {
    if (_fromAccount == null || _amount <= 0) return _RiskLevel.none;
    final pct = _amount / _fromAccount!.balance;
    if (pct > 0.9) return _RiskLevel.high;
    if (pct > 0.7) return _RiskLevel.medium;
    return _RiskLevel.none;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_canSubmit || _isLoading) return;

    // Guardia para transferencias de alto riesgo
    if (_riskLevel != _RiskLevel.none) {
      final confirmed = await _showRiskConfirmation();
      if (!confirmed) return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _isLoading = true);

    try {
      await _accountRepository.createTransfer(
        fromAccountId: _fromAccount!.id,
        toAccountId: _toAccount!.id,
        amount: _amount,
        description: _descriptionController.text.trim().isEmpty
            ? 'Transferencia interna'
            : _descriptionController.text.trim(),
      );

      if (!mounted) return;
      EventService.instance.fire(AppEvent.transactionsChanged);
      Navigator.of(context).pop(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationHelper.show(
          message: 'Transferencia realizada',
          type: NotificationType.success,
        );
      });
    } catch (e) {
      developer.log('🔥 Error en transferencia: $e', name: 'AddTransferScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showRiskConfirmation() async {
    HapticFeedback.mediumImpact();
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _RiskConfirmationSheet(
            amount: _amount,
            fromAccount: _fromAccount!,
            riskLevel: _riskLevel,
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: _T.label(14)),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showAccountPicker(List<Account> accounts, bool isFrom) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountPickerSheet(
        accounts: accounts,
        exclude: isFrom ? _toAccount : _fromAccount,
        onSelected: (account) {
          HapticFeedback.selectionClick();
          setState(() {
            if (isFrom) _fromAccount = account;
            else _toAccount = account;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final accounts = snapshot.data ?? [];
        if (accounts.length < 2) return _EmptyState();

        return FadeTransition(
          opacity: _fadeAnim,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: Stack(
              children: [
                _buildBody(accounts),
                _buildSaveButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(List<Account> accounts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _BlurHeader(
            title: 'Nueva transferencia',
            scaffoldBg: Theme.of(context).colorScheme.surface,
            onBack: () => Navigator.pop(context),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Origen → Destino ─────────────────────────────────────
                _SectionLabel('Cuentas'),
                const SizedBox(height: 10),
                _AccountRow(
                  from: _fromAccount,
                  to: _toAccount,
                  surfBg: surfBg,
                  onTapFrom: () => _showAccountPicker(accounts, true),
                  onTapTo: () => _showAccountPicker(accounts, false),
                ),

                const SizedBox(height: 32),

                // ── Monto ─────────────────────────────────────────────────
                _SectionLabel('Monto'),
                const SizedBox(height: 10),
                _AmountField(
                  controller: _amountController,
                  fromAccount: _fromAccount,
                  surfBg: surfBg,
                  onChanged: () => setState(() {}),
                ),

                // ── Sugerencias de % — solo cuando hay cuenta origen ─────
                if (_fromAccount != null) ...[
                  const SizedBox(height: 12),
                  _PercentSuggestions(
                    balance: _fromAccount!.balance,
                    onTap: (v) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _amountController.text = v.toStringAsFixed(0);
                      });
                    },
                  ),
                ],

                // ── Alerta de riesgo — solo cuando aplica ─────────────────
                if (_riskLevel != _RiskLevel.none) ...[
                  const SizedBox(height: 16),
                  _RiskBanner(
                    level: _riskLevel,
                    amount: _amount,
                    balance: _fromAccount!.balance,
                  ),
                ],

                const SizedBox(height: 32),

                // ── Descripción ───────────────────────────────────────────
                _SectionLabel('Descripción'),
                const SizedBox(height: 10),
                _DescriptionField(
                  controller: _descriptionController,
                  surfBg: surfBg,
                ),

                // ── Resumen — solo cuando todo está listo ─────────────────
                if (_fromAccount != null &&
                    _toAccount != null &&
                    _amount > 0 &&
                    _amount <= (_fromAccount?.balance ?? 0)) ...[
                  const SizedBox(height: 32),
                  _TransferSummary(
                    from: _fromAccount!,
                    to: _toAccount!,
                    amount: _amount,
                    surfBg: surfBg,
                  ),
                ],

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    final canTap = _canSubmit && !_isLoading;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedBuilder(
              animation: _btnAnim,
              builder: (_, __) {
                final v = _btnAnim.value;
                return Transform.scale(
                  scale: ui.lerpDouble(1.0, 0.97, v)!,
                  child: GestureDetector(
                    onTapDown: canTap ? (_) => _btnAnim.forward() : null,
                    onTapUp: canTap ? (_) async {
                      await _btnAnim.reverse();
                      _submit();
                    } : null,
                    onTapCancel: () => _btnAnim.reverse(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 54,
                      decoration: BoxDecoration(
                        color: canTap
                            ? _kBlue
                            : _kBlue.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Transferir',
                                style: _T.label(17, w: FontWeight.w600)
                                    .copyWith(color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BLUR HEADER
// =============================================================================

class _BlurHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final Color scaffoldBg;
  final VoidCallback onBack;

  const _BlurHeader({
    required this.title,
    required this.scaffoldBg,
    required this.onBack,
  });

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
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
              Expanded(
                child: Text(title, style: _T.display(17)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_BlurHeader old) => old.title != title;
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
    vsync: this, duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() { _c.dispose(); super.dispose(); }

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
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: _T.label(11, w: FontWeight.w500).copyWith(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
        letterSpacing: 0.6,
      ),
    );
  }
}

// =============================================================================
// ACCOUNT ROW (origen → destino inline)
// =============================================================================

class _AccountRow extends StatelessWidget {
  final Account? from;
  final Account? to;
  final Color surfBg;
  final VoidCallback onTapFrom;
  final VoidCallback onTapTo;

  const _AccountRow({
    required this.from,
    required this.to,
    required this.surfBg,
    required this.onTapFrom,
    required this.onTapTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _AccountTile(
            label: 'Origen',
            account: from,
            onTap: onTapFrom,
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          ),
          _AccountTile(
            label: 'Destino',
            account: to,
            onTap: onTapTo,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatefulWidget {
  final String label;
  final Account? account;
  final VoidCallback onTap;

  const _AccountTile({
    required this.label,
    required this.account,
    required this.onTap,
  });

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAccount = widget.account != null;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) async {
        await _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: ui.lerpDouble(1.0, 0.97, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Dot indicador
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasAccount ? _kBlue : cs.onSurface.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: _T.label(11, w: FontWeight.w500).copyWith(
                          color: cs.onSurface.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAccount ? widget.account!.name : 'Seleccionar',
                        style: _T.label(15).copyWith(
                          color: hasAccount
                              ? cs.onSurface
                              : cs.onSurface.withOpacity(0.35),
                        ),
                      ),
                    ],
                  ),
                ),
                // Balance real de la cuenta
                if (hasAccount)
                  Text(
                    _fmt.format(widget.account!.balance),
                    style: _T.mono(13).copyWith(
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: cs.onSurface.withOpacity(0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// AMOUNT FIELD
// =============================================================================

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final Account? fromAccount;
  final Color surfBg;
  final VoidCallback onChanged;

  const _AmountField({
    required this.controller,
    required this.fromAccount,
    required this.surfBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final amount = double.tryParse(
          controller.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final overBalance =
        fromAccount != null && amount > fromAccount!.balance && amount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
        border: overBalance
            ? Border.all(color: _kRed.withOpacity(0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '\$',
                style: _T.display(32).copyWith(
                  color: cs.onSurface.withOpacity(0.25),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: _T.display(32).copyWith(
                    color: overBalance ? _kRed : cs.onSurface,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '0',
                    hintStyle: _T.display(32).copyWith(
                      color: cs.onSurface.withOpacity(0.15),
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          // Saldo disponible — dato real
          if (fromAccount != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                overBalance
                    ? 'Saldo insuficiente — disponible ${_fmt.format(fromAccount!.balance)}'
                    : 'Disponible  ${_fmt.format(fromAccount!.balance)}',
                style: _T.label(12).copyWith(
                  color: overBalance
                      ? _kRed
                      : cs.onSurface.withOpacity(0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// PERCENT SUGGESTIONS
// =============================================================================

class _PercentSuggestions extends StatelessWidget {
  final double balance;
  final void Function(double) onTap;

  const _PercentSuggestions({
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = [
      ('25 %', balance * 0.25),
      ('50 %', balance * 0.50),
      ('75 %', balance * 0.75),
      ('Todo', balance),
    ];

    return Row(
      children: options.map((o) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PercentChip(
              label: o.$1,
              onTap: () => onTap(o.$2),
              cs: cs,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PercentChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _PercentChip({
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  State<_PercentChip> createState() => _PercentChipState();
}

class _PercentChipState extends State<_PercentChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) async {
        await _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: ui.lerpDouble(1.0, 0.93, _c.value)!,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              widget.label,
              style: _T.label(13).copyWith(color: _kBlue),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// RISK BANNER — basado en datos reales
// =============================================================================

enum _RiskLevel { none, medium, high }

class _RiskBanner extends StatelessWidget {
  final _RiskLevel level;
  final double amount;
  final double balance;

  const _RiskBanner({
    required this.level,
    required this.amount,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final isHigh = level == _RiskLevel.high;
    final color = isHigh ? _kRed : _kOrange;
    final pct = (amount / balance * 100).round();
    final remaining = balance - amount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isHigh
                ? Icons.warning_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isHigh
                  ? 'Usarás el $pct % de tu saldo. Quedarán ${_fmt.format(remaining)}.'
                  : 'Transferirás el $pct % de tu saldo disponible.',
              style: _T.label(13).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DESCRIPTION FIELD
// =============================================================================

class _DescriptionField extends StatelessWidget {
  final TextEditingController controller;
  final Color surfBg;

  const _DescriptionField({
    required this.controller,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        maxLength: 80,
        style: _T.label(15),
        decoration: InputDecoration(
          hintText: 'Descripción (opcional)',
          hintStyle: _T.label(15).copyWith(
            color: cs.onSurface.withOpacity(0.3),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14,
          ),
          counterText: '',
        ),
      ),
    );
  }
}

// =============================================================================
// TRANSFER SUMMARY — aparece solo cuando todo está válido
// =============================================================================

class _TransferSummary extends StatelessWidget {
  final Account from;
  final Account to;
  final double amount;
  final Color surfBg;

  const _TransferSummary({
    required this.from,
    required this.to,
    required this.amount,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final afterTransfer = from.balance - amount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _SummaryRow(
            label: 'De',
            value: from.name,
            cs: cs,
          ),
          _SummaryRow(
            label: 'A',
            value: to.name,
            cs: cs,
          ),
          Divider(
            height: 20,
            color: cs.onSurface.withOpacity(0.08),
          ),
          _SummaryRow(
            label: 'Monto',
            value: _fmt.format(amount),
            valueStyle: _T.mono(15).copyWith(color: cs.onSurface),
            cs: cs,
          ),
          _SummaryRow(
            label: 'Saldo restante en ${from.name}',
            value: _fmt.format(afterTransfer),
            valueStyle: _T.mono(15).copyWith(
              color: afterTransfer < from.balance * 0.1
                  ? _kRed
                  : cs.onSurface.withOpacity(0.6),
            ),
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final ColorScheme cs;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.cs,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: _T.label(13).copyWith(
              color: cs.onSurface.withOpacity(0.45),
            ),
          ),
          Text(
            value,
            style: valueStyle ??
                _T.label(13).copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ACCOUNT PICKER SHEET
// =============================================================================

class _AccountPickerSheet extends StatefulWidget {
  final List<Account> accounts;
  final Account? exclude;
  final void Function(Account) onSelected;

  const _AccountPickerSheet({
    required this.accounts,
    required this.exclude,
    required this.onSelected,
  });

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final filtered = widget.accounts
        .where((a) =>
            a.id != widget.exclude?.id &&
            (_query.isEmpty ||
                a.name.toLowerCase().contains(_query.toLowerCase())))
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.55, 0.85],
      builder: (_, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: cs.surface.withOpacity(0.97),
              child: Column(
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Seleccionar cuenta', style: _T.display(20)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Buscador
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        style: _T.label(15),
                        decoration: InputDecoration(
                          hintText: 'Buscar',
                          hintStyle: _T.label(15).copyWith(
                            color: cs.onSurface.withOpacity(0.3),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: cs.onSurface.withOpacity(0.3),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lista
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.onSurface.withOpacity(0.06),
                      ),
                      itemBuilder: (_, i) {
                        final account = filtered[i];
                        return _PickerTile(
                          account: account,
                          onTap: () => widget.onSelected(account),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PickerTile extends StatefulWidget {
  final Account account;
  final VoidCallback onTap;

  const _PickerTile({required this.account, required this.onTap});

  @override
  State<_PickerTile> createState() => _PickerTileState();
}

class _PickerTileState extends State<_PickerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) async {
        await _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: ui.lerpDouble(1.0, 0.97, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(
                  widget.account.icon,
                  color: _kBlue,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.account.name, style: _T.label(15)),
                      const SizedBox(height: 2),
                      Text(
                        widget.account.type,
                        style: _T.label(12).copyWith(
                          color: cs.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmt.format(widget.account.balance),
                  style: _T.mono(14).copyWith(
                    color: cs.onSurface.withOpacity(0.6),
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

// =============================================================================
// RISK CONFIRMATION SHEET
// =============================================================================

class _RiskConfirmationSheet extends StatelessWidget {
  final double amount;
  final Account fromAccount;
  final _RiskLevel riskLevel;

  const _RiskConfirmationSheet({
    required this.amount,
    required this.fromAccount,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = riskLevel == _RiskLevel.high ? _kRed : _kOrange;
    final remaining = fromAccount.balance - amount;
    final pct = (amount / fromAccount.balance * 100).round();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: cs.surface.withOpacity(0.97),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Confirmar transferencia',
                style: _T.display(20),
              ),
              const SizedBox(height: 8),
              Text(
                'Vas a transferir el $pct % del saldo de ${fromAccount.name}.',
                style: _T.label(15).copyWith(
                  color: cs.onSurface.withOpacity(0.55),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Datos reales
              _ConfirmRow('Monto', _fmt.format(amount), cs),
              _ConfirmRow('Quedan en ${fromAccount.name}',
                  _fmt.format(remaining), cs),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: _SheetBtn(
                      label: 'Cancelar',
                      filled: false,
                      color: color,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetBtn(
                      label: 'Transferir',
                      filled: true,
                      color: color,
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;

  const _ConfirmRow(this.label, this.value, this.cs);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  _T.label(14).copyWith(color: cs.onSurface.withOpacity(0.45))),
          Text(value, style: _T.mono(14)),
        ],
      ),
    );
  }
}

class _SheetBtn extends StatefulWidget {
  final String label;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  const _SheetBtn({
    required this.label,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SheetBtn> createState() => _SheetBtnState();
}

class _SheetBtnState extends State<_SheetBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) async {
        await _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: ui.lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: widget.filled
                  ? widget.color
                  : widget.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: _T.label(15, w: FontWeight.w600).copyWith(
                color: widget.filled ? Colors.white : widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: _BackBtn(onBack: () => Navigator.pop(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_outlined,
                size: 48, color: cs.onSurface.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text('Necesitas al menos dos cuentas',
                style: _T.display(20), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Crea otra cuenta para poder hacer transferencias entre ellas.',
              style: _T.label(15).copyWith(
                color: cs.onSurface.withOpacity(0.45),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}