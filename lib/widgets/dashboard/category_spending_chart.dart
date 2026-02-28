// lib/widgets/dashboard/category_spending_chart.dart
// ─────────────────────────────────────────────────────────────────
// Apple-style Premium Card — OLED Dark Dashboard
// Micro-interactions: spring radius, haptics, staggered legend reveal,
// shimmer on load, liquid center label crossfade.
// ─────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/screens/analysis_screen.dart';

// ── Design Tokens ──────────────────────────────────────────────────────────
class _T {
  static const bg         = Color(0xFF1C1C1E);   // iOS system grouped background
  static const surface    = Color(0xFF2C2C2E);   // iOS secondary grouped background
  static const border     = Color(0xFF3A3A3C);   // separator
  static const labelPri   = Color(0xFFFFFFFF);
  static const labelSec   = Color(0xFF8E8E93);   // iOS secondary label
  static const labelTer   = Color(0xFF48484A);   // iOS tertiary label
  static const tint       = Color(0xFF30D158);   // iOS green system tint
  static const tintBlue   = Color(0xFF0A84FF);
  static const radius     = 20.0;
  static const cardPad    = EdgeInsets.all(20.0);
}

// ── Main Widget ─────────────────────────────────────────────────────────────
class CategorySpendingChart extends StatefulWidget {
  final List<CategorySpending> spendingData;
  const CategorySpendingChart({super.key, required this.spendingData});

  @override
  State<CategorySpendingChart> createState() => _CategorySpendingChartState();
}

class _CategorySpendingChartState extends State<CategorySpendingChart>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────
  int _touched = -1;

  // ── Animations ────────────────────────────────────────────────
  late final AnimationController _mountCtrl;   // stagger on mount
  late final AnimationController _labelCtrl;   // center label crossfade
  late final Animation<double> _labelFade;
  late final Animation<Offset> _labelSlide;

  String _centerValue = '';
  String _centerLabel = 'Total';
  String _nextValue   = '';
  String _nextLabel   = '';

  @override
  void initState() {
    super.initState();

    // Always initialize ALL controllers unconditionally —
    // even when spendingData is empty, so `late` fields are never
    // accessed before assignment.
    _mountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _labelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _labelFade = CurvedAnimation(parent: _labelCtrl, curve: Curves.easeOut);
    _labelSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _labelCtrl, curve: Curves.easeOutCubic));

    // Seed center label — safe even when list is empty
    if (widget.spendingData.isNotEmpty) {
      final data  = _processed;
      final total = data.fold<double>(0, (s, d) => s + d.totalAmount);
      _centerValue = _formatCompact(total);
    } else {
      _centerValue = '\$0';
    }
    _centerLabel = 'Total';

    // Start label at full opacity (forward to 1.0 immediately)
    _labelCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _mountCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  // ── Data Processing ───────────────────────────────────────────
  List<CategorySpending> get _processed {
    if (widget.spendingData.length <= 5) return widget.spendingData;
    final sorted = List<CategorySpending>.from(widget.spendingData)
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    final top4 = sorted.take(4).toList();
    final rest = sorted.skip(4).toList();
    if (rest.isNotEmpty) {
      top4.add(CategorySpending(
        categoryName: 'Otros',
        totalAmount: rest.fold(0, (s, i) => s + i.totalAmount),
        color: '#636366',
      ));
    }
    return top4;
  }

  // ── Touch Handling with Haptics ───────────────────────────────
  void _onTouch(int index, List<CategorySpending> data, double total) {
    if (index == _touched) return;

    HapticFeedback.selectionClick();

    // Prepare next label values
    if (index >= 0 && index < data.length) {
      _nextValue = '${(data[index].totalAmount / total * 100).toStringAsFixed(0)}%';
      _nextLabel = data[index].categoryName;
    } else {
      _nextValue = _formatCompact(total);
      _nextLabel = 'Total';
    }

    // Crossfade animation
    _labelCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _touched     = index;
        _centerValue = _nextValue;
        _centerLabel = _nextLabel;
      });
      _labelCtrl.forward();
    });
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.spendingData.isEmpty) {
      // _mountCtrl is guaranteed initialized — safe to pass
      return _EmptyState(mountCtrl: _mountCtrl);
    }

    final data  = _processed;

    final total = data.fold<double>(0, (s, d) => s + d.totalAmount);

    return FadeTransition(
      opacity: CurvedAnimation(parent: _mountCtrl, curve: const Interval(0, 0.5)),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(
              parent: _mountCtrl,
              curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
            )),
        child: _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(mountCtrl: _mountCtrl),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _DonutChart(
                    data: data,
                    total: total,
                    touched: _touched,
                    onTouch: (i) => _onTouch(i, data, total),
                    centerValue: _centerValue,
                    centerLabel: _centerLabel,
                    labelFade: _labelFade,
                    labelSlide: _labelSlide,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _Legend(
                      data: data,
                      total: total,
                      touched: _touched,
                      mountCtrl: _mountCtrl,
                      onTap: (i) => _onTouch(i, data, total),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _BarStrip(data: data, total: total, touched: _touched, mountCtrl: _mountCtrl),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  String _formatCompact(double v) {
    if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '\$${(v / 1000).toStringAsFixed(1)}k';
    return '\$${v.toStringAsFixed(0)}';
  }
}

// ── Card Shell ───────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    // Transparent — the dashboard provides the card surface.
    return Padding(
      padding: _T.cardPad,
      child: child,
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final AnimationController mountCtrl;
  const _Header({required this.mountCtrl});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: mountCtrl,
        curve: const Interval(0.1, 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GASTOS',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: _T.labelSec,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Distribución',
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: _T.labelPri,
                  height: 1.1,
                ),
              ),
            ],
          ),
          _DetailButton(),
        ],
      ),
    );
  }
}

class _DetailButton extends StatefulWidget {
  @override
  State<_DetailButton> createState() => _DetailButtonState();
}

class _DetailButtonState extends State<_DetailButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); HapticFeedback.lightImpact(); },
      onTapUp:   (_) { _ctrl.reverse(); },
      onTapCancel: () => _ctrl.reverse(),
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AnalysisScreen())),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _T.tint.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _T.tint.withOpacity(0.18), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ver todo',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _T.tint,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: _T.tint),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Donut Chart ──────────────────────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final List<CategorySpending> data;
  final double total;
  final int touched;
  final ValueChanged<int> onTouch;
  final String centerValue, centerLabel;
  final Animation<double> labelFade;
  final Animation<Offset> labelSlide;

  const _DonutChart({
    required this.data,
    required this.total,
    required this.touched,
    required this.onTouch,
    required this.centerValue,
    required this.centerLabel,
    required this.labelFade,
    required this.labelSlide,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle glow ring behind the chart
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (touched >= 0 && touched < data.length
                      ? _hexColor(data[touched].color)
                      : _T.tint).withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, resp) {
                  if (!event.isInterestedForInteractions ||
                      resp == null ||
                      resp.touchedSection == null) {
                    onTouch(-1);
                    return;
                  }
                  onTouch(resp.touchedSection!.touchedSectionIndex);
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2.5,
              centerSpaceRadius: 40,
              sections: _buildSections(),
            ),
          ),
          // Crossfading center label
          SlideTransition(
            position: labelSlide,
            child: FadeTransition(
              opacity: labelFade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerValue,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: _T.labelPri,
                    ),
                  ),
                  Text(
                    centerLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: _T.labelSec,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    if (total == 0) return [];
    return data.asMap().entries.map((e) {
      final isTouched = e.key == touched;
      final color = _hexColor(e.value.color);
      final pct   = e.value.totalAmount / total * 100;

      return PieChartSectionData(
        color: isTouched ? color : color.withOpacity(0.75),
        value: e.value.totalAmount,
        title: '',  // titles rendered in legend; keeps donut clean
        radius: isTouched ? 50.0 : 40.0,
        borderSide: isTouched
            ? BorderSide(color: color, width: 2)
            : const BorderSide(color: Colors.transparent, width: 0),
      );
    }).toList();
  }

  Color _hexColor(String code) {
    try {
      return Color(
          int.parse(code.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (_) { return _T.labelTer; }
  }
}

// ── Legend ───────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final List<CategorySpending> data;
  final double total;
  final int touched;
  final AnimationController mountCtrl;
  final ValueChanged<int> onTap;

  const _Legend({
    required this.data,
    required this.total,
    required this.touched,
    required this.mountCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.asMap().entries.map((e) {
        final delay  = 0.15 + e.key * 0.08;
        final active = e.key == touched;
        final color  = _hexColor(e.value.color);
        final pct    = (e.value.totalAmount / total * 100).toStringAsFixed(0);

        return FadeTransition(
          opacity: CurvedAnimation(
            parent: mountCtrl,
            curve: Interval(delay.clamp(0, 1), (delay + 0.3).clamp(0, 1)),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: mountCtrl,
              curve: Interval(delay.clamp(0, 1), (delay + 0.3).clamp(0, 1),
                  curve: Curves.easeOutCubic),
            )),
            child: _LegendItem(
              color: color,
              name: e.value.categoryName,
              pct: pct,
              amount: e.value.totalAmount,
              active: active,
              onTap: () => onTap(e.key),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _hexColor(String code) {
    try {
      return Color(
          int.parse(code.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (_) { return _T.labelTer; }
  }
}

class _LegendItem extends StatefulWidget {
  final Color color;
  final String name, pct;
  final double amount;
  final bool active;
  final VoidCallback onTap;

  const _LegendItem({
    required this.color,
    required this.name,
    required this.pct,
    required this.amount,
    required this.active,
    required this.onTap,
  });

  @override
  State<_LegendItem> createState() => _LegendItemState();
}

class _LegendItemState extends State<_LegendItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp:   (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _pressScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: widget.active
                ? widget.color.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.active
                  ? widget.color.withOpacity(0.3)
                  : Colors.transparent,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Color dot with animated size
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,  // easeOutBack overshoots → negative shadow blur crash
                width:  widget.active ? 9 : 6,
                height: widget.active ? 9 : 6,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: widget.active
                      ? [BoxShadow(
                          color: widget.color.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.dmSans(
                    fontSize: widget.active ? 13 : 12,
                    fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
                    color: widget.active ? _T.labelPri : _T.labelSec,
                  ),
                  child: Text(
                    widget.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.active ? widget.color : _T.labelSec,
                ),
                child: Text('${widget.pct}%'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Proportional Bar Strip ────────────────────────────────────────────────────
// A horizontal segmented bar — micro-detail that Apple uses in Screen Time.
class _BarStrip extends StatelessWidget {
  final List<CategorySpending> data;
  final double total;
  final int touched;
  final AnimationController mountCtrl;

  const _BarStrip({
    required this.data,
    required this.total,
    required this.touched,
    required this.mountCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(height: 0.5, color: _T.border.withOpacity(0.5)),
        const SizedBox(height: 16),
        // Label
        Text(
          'PROPORCIÓN MENSUAL',
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: _T.labelSec,
          ),
        ),
        const SizedBox(height: 10),
        // Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: mountCtrl,
            builder: (_, __) {
              final progress = CurvedAnimation(
                parent: mountCtrl,
                curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
              ).value;
              return Row(
                children: data.asMap().entries.map((e) {
                  final fraction = e.value.totalAmount / total;
                  final isTouched = e.key == touched;
                  final color = _hexColor(e.value.color);
                  return Flexible(
                    flex: (fraction * 1000).round(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      height: isTouched ? 10 : 7,
                      color: isTouched
                          ? color
                          : color.withOpacity(0.55 * progress),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Value row — each label wrapped in Flexible to prevent overflow
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: data.asMap().entries.map((e) {
            final isTouched = e.key == touched;
            return Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.dmSans(
                  fontSize: isTouched ? 11 : 9,
                  fontWeight: isTouched ? FontWeight.w700 : FontWeight.w400,
                  color: isTouched
                      ? _hexColor(e.value.color)
                      : _T.labelSec,
                ),
                child: Text(
                  e.value.categoryName,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _hexColor(String code) {
    try {
      return Color(
          int.parse(code.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (_) { return _T.labelTer; }
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatefulWidget {
  /// The parent's mount controller — used for the card fade-in.
  /// Guaranteed to be initialized before this widget is built.
  final AnimationController mountCtrl;
  const _EmptyState({required this.mountCtrl});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

// Uses TickerProviderStateMixin (not Single-) so it can own its own
// shimmer controller independently of the parent's controller.
class _EmptyStateState extends State<_EmptyState>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: widget.mountCtrl,
        curve: const Interval(0.0, 0.6),
      ),
      child: _Card(
        child: SizedBox(
          height: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing shimmer icon
              AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (_, child) {
                  final pulse = math.sin(_shimmerCtrl.value * math.pi * 2);
                  return Opacity(
                    opacity: 0.25 + 0.15 * ((pulse + 1) / 2),
                    child: child,
                  );
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _T.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _T.border, width: 0.5),
                  ),
                  child: const Icon(
                    Iconsax.chart_2,
                    size: 22,
                    color: _T.labelSec,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sin datos aún',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _T.labelSec,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Registra un gasto para ver\ntu distribución mensual',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: _T.labelTer,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}