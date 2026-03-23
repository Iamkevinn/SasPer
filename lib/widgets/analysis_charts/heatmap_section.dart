// lib/widgets/analysis_charts/heatmap_section.dart
//
// iOS: PageView por mes con navegación de flechas + dots,
// empieza en el mes más reciente, tap abre bottom sheet minimalista.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class HeatmapSection extends StatefulWidget {
  final Map<DateTime, int> data;
  final DateTime startDate;
  final DateTime endDate;

  const HeatmapSection({
    super.key,
    required this.data,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<HeatmapSection> createState() => _HeatmapSectionState();
}

class _HeatmapSectionState extends State<HeatmapSection> {
  late final Map<DateTime, int> _normalized;
  late final List<DateTime> _months;
  late final double _maxPos;
  late final double _maxNeg;
  late final PageController _pageCtrl;
  int _currentPage = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label  => _isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _empty  => _isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

  @override
  void initState() {
    super.initState();
    _normalized = _normalizeData(widget.data, widget.startDate, widget.endDate);
    _months = _calcMonths(widget.startDate, widget.endDate);
    _calcMaxValues();
    _currentPage = _months.isEmpty ? 0 : _months.length - 1;
    _pageCtrl = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _calcMaxValues() {
    final pos = _normalized.values.where((v) => v > 0);
    final neg = _normalized.values.where((v) => v < 0).map((v) => v.abs());
    _maxPos = pos.isEmpty ? 1.0 : pos.reduce(max).toDouble();
    _maxNeg = neg.isEmpty ? 1.0 : neg.reduce(max).toDouble();
  }

  static Map<DateTime, int> _normalizeData(Map<DateTime, int> src, DateTime start, DateTime end) {
    final norm = {
      for (var e in src.entries) DateTime(e.key.year, e.key.month, e.key.day): e.value
    };
    final result = <DateTime, int>{};
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      result[d] = norm[d] ?? 0;
    }
    return result;
  }

  static List<DateTime> _calcMonths(DateTime start, DateTime end) {
    final months = <DateTime>[];
    var cur = DateTime(start.year, start.month, 1);
    while (!cur.isAfter(end)) {
      months.add(cur);
      cur = DateTime(cur.year, cur.month + 1, 1);
    }
    return months;
  }

  Color _cellColor(int value) {
    if (value == 0) return _empty;
    if (value > 0) {
      final t = (value / _maxPos).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFF34C759).withOpacity(0.2), const Color(0xFF34C759), t)!;
    } else {
      final t = (value.abs() / _maxNeg).clamp(0.0, 1.0);
      return Color.lerp(const Color(0xFFFF3B30).withOpacity(0.2), const Color(0xFFFF3B30), t)!;
    }
  }

  void _onTap(DateTime date) {
    HapticFeedback.selectionClick();
    final value = _normalized[date] ?? 0;
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DaySheet(
        date: DateFormat.yMMMd('es_CO').format(date),
        value: value,
        formatted: fmt.format(value.abs()),
        isDark: _isDark,
      ),
    );
  }

  void _go(int direction) {
    final target = _currentPage + direction;
    if (target < 0 || target >= _months.length) return;
    HapticFeedback.selectionClick();
    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_months.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          // ── Navegación mes ───────────────────────────────────────────
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                enabled: _currentPage > 0,
                onTap: () => _go(-1),
                isDark: _isDark,
                label: _label,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: Text(
                    key: ValueKey(_currentPage),
                    DateFormat.yMMMM('es_CO').format(_months[_currentPage]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: _label, letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                enabled: _currentPage < _months.length - 1,
                onTap: () => _go(1),
                isDark: _isDark,
                label: _label,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Cabeceras de días ────────────────────────────────────────
          Row(
            children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((d) => Expanded(
              child: Center(
                child: Text(d, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600, color: _label3,
                )),
              ),
            )).toList(),
          ),

          const SizedBox(height: 6),

          // ── PageView ─────────────────────────────────────────────────
          SizedBox(
            height: 220,
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemCount: _months.length,
              itemBuilder: (_, i) => _MonthGrid(
                year: _months[i].year,
                month: _months[i].month,
                data: _normalized,
                cellColor: _cellColor,
                onTap: _onTap,
                label3: _label3,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Dots de página ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_months.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF007AFF)
                      : (_isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2)),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),

          const SizedBox(height: 16),

          // ── Leyenda ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Gasto', style: TextStyle(fontSize: 11, color: _label3)),
              const SizedBox(width: 6),
              ...List.generate(4, (i) => Container(
                width: 12, height: 12,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFFF3B30).withOpacity(0.2),
                    const Color(0xFFFF3B30), (i + 1) / 4,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
              Container(
                width: 12, height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: _empty, borderRadius: BorderRadius.circular(3)),
              ),
              ...List.generate(4, (i) => Container(
                width: 12, height: 12,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFF34C759).withOpacity(0.2),
                    const Color(0xFF34C759), (i + 1) / 4,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
              const SizedBox(width: 6),
              Text('Ingreso', style: TextStyle(fontSize: 11, color: _label3)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Botón de navegación ───────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;
  final Color label;

  const _NavButton({
    required this.icon, required this.enabled,
    required this.onTap, required this.isDark, required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.25,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: label),
        ),
      ),
    );
  }
}

// ── Grid de un mes ────────────────────────────────────────────────────────────
class _MonthGrid extends StatelessWidget {
  final int year;
  final int month;
  final Map<DateTime, int> data;
  final Color Function(int) cellColor;
  final void Function(DateTime) onTap;
  final Color label3;

  const _MonthGrid({
    required this.year, required this.month, required this.data,
    required this.cellColor, required this.onTap, required this.label3,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final emptyCells = DateTime(year, month, 1).weekday - 1;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: daysInMonth + emptyCells,
      itemBuilder: (_, i) {
        if (i < emptyCells) return const SizedBox.shrink();
        final day = i - emptyCells + 1;
        final date = DateTime(year, month, day);
        final value = data[date] ?? 0;
        final color = cellColor(value);

        return GestureDetector(
          onTap: () => onTap(date),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: color.computeLuminance() > 0.4 ? Colors.black54 : Colors.white70,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom sheet del día ──────────────────────────────────────────────────────
class _DaySheet extends StatelessWidget {
  final String date;
  final int value;
  final String formatted;
  final bool isDark;

  const _DaySheet({
    required this.date, required this.value,
    required this.formatted, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = value > 0;
    final isZero = value == 0;
    final color = isZero
        ? (isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366))
        : isPositive ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(date, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1C1C1E),
          )),
          const SizedBox(height: 10),
          Text(
            isZero ? 'Sin movimientos' : (isPositive ? 'Flujo neto positivo' : 'Flujo neto negativo'),
            style: TextStyle(fontSize: 13,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366)),
          ),
          if (!isZero) ...[
            const SizedBox(height: 8),
            Text(formatted, style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: color, letterSpacing: -0.5,
            )),
          ],
        ],
      ),
    );
  }
}