// C:\Proyectos\SasPer\lib\widgets\dashboard\balance_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconsax/iconsax.dart';

enum BalanceStatus { positive, negative, neutral }

extension BalanceStatusX on BalanceStatus {
  Color getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (this) {
      case BalanceStatus.positive:
        return Colors.green.shade600;
      case BalanceStatus.negative:
        return colorScheme.error;
      case BalanceStatus.neutral:
        return colorScheme.onSurfaceVariant;
    }
  }
}

class BalanceCard extends StatefulWidget {
  // NUEVO: Ahora recibimos los 3 pilares financieros
  final double availableBalance; // Saldo operativo (Efectivo - Restringido)
  final double restrictedBalance; // Dinero reservado para metas/pagos
  final double totalDebt; // Deudas acumuladas

  const BalanceCard({
    super.key, 
    required this.availableBalance,
    required this.restrictedBalance,
    required this.totalDebt,
  });

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  bool _isBalanceVisible = true;
  late final AnimationController _eyeAnimationController;

  static const String _balanceVisibilityKey = 'balance_visibility_preference';

  @override
  void initState() {
    super.initState();
    _eyeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadVisibilityPreference();
  }
  
  Future<void> _loadVisibilityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isBalanceVisible = prefs.getBool(_balanceVisibilityKey) ?? true;
        if (_isBalanceVisible) {
          _eyeAnimationController.value = 0; // Ojo abierto
        } else {
          _eyeAnimationController.value = 1; // Ojo cerrado
        }
      });
    }
  }

  Future<void> _saveVisibilityPreference(bool isVisible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_balanceVisibilityKey, isVisible);
  }

  @override
  void dispose() {
    _eyeAnimationController.dispose();
    super.dispose();
  }

  void _toggleVisibility() async {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
      if (_isBalanceVisible) {
        _eyeAnimationController.reverse();
      } else {
        _eyeAnimationController.forward();
      }
    });
    await _saveVisibilityPreference(_isBalanceVisible);
  }

  // El estatus ahora se basa en el saldo DISPONIBLE
  BalanceStatus get _status => widget.availableBalance > 0
      ? BalanceStatus.positive
      : widget.availableBalance < 0
          ? BalanceStatus.negative
          : BalanceStatus.neutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final statusColor = _status.getColor(context);
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      color: statusColor.withOpacity(0.08),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 6)),
        ),
        child: Stack(
          children:[
            // Pintor de fondo original
            Positioned(
              bottom: -2,
              right: -2,
              child: SizedBox(
                width: 80,
                height: 50,
                child: CustomPaint(
                  painter: _BalanceTrendPainter(
                    status: _status,
                    color: statusColor.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  // --- SECCIÓN 1: SALDO DISPONIBLE (HERO) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      Row(
                        children:[
                          Icon(Iconsax.wallet_money, size: 20, color: statusColor),
                          const SizedBox(width: 8),
                          Text(
                            'Disponible para gastar',
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _toggleVisibility,
                        child: Lottie.asset(
                          'assets/animations/eye_animation.json',
                          controller: _eyeAnimationController,
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      key: ValueKey<bool>(_isBalanceVisible),
                      _isBalanceVisible
                          ? currencyFormat.format(widget.availableBalance)
                          : '∗∗∗∗',
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: _isBalanceVisible ? -1 : 4,
                        fontSize: 36,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  Divider(color: statusColor.withOpacity(0.2), thickness: 1),
                  const SizedBox(height: 16),
                  
                  // --- SECCIÓN 2: RESERVADO Y DEUDAS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:[
                      // Bloque Reservado
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children:[
                                Icon(Iconsax.lock_1, size: 14, color: Colors.blue.shade600),
                                const SizedBox(width: 6),
                                Text(
                                  'Reservado / Metas',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: Text(
                                key: ValueKey<bool>(_isBalanceVisible),
                                _isBalanceVisible
                                    ? currencyFormat.format(widget.restrictedBalance)
                                    : '∗∗∗',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  letterSpacing: _isBalanceVisible ? 0 : 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Separador vertical
                      Container(
                        height: 30,
                        width: 1,
                        color: statusColor.withOpacity(0.2),
                      ),
                      const SizedBox(width: 16),
                      
                      // Bloque Deudas
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:[
                            Row(
                              children:[
                                Icon(Iconsax.chart_fail, size: 14, color: colorScheme.error),
                                const SizedBox(width: 6),
                                Text(
                                  'Deuda Total',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: Text(
                                key: ValueKey<bool>(_isBalanceVisible),
                                _isBalanceVisible
                                    ? currencyFormat.format(widget.totalDebt)
                                    : '∗∗∗',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.error,
                                  letterSpacing: _isBalanceVisible ? 0 : 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pintor de fondo
class _BalanceTrendPainter extends CustomPainter {
  final BalanceStatus status;
  final Color color;

  _BalanceTrendPainter({required this.status, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    switch (status) {
      case BalanceStatus.positive:
        path.moveTo(size.width * 0.1, size.height * 0.9);
        path.cubicTo(
          size.width * 0.3, size.height * 0.8,
          size.width * 0.6, size.height * 0.2,
          size.width, size.height * 0.1,
        );
        break;
      case BalanceStatus.negative:
        path.moveTo(size.width * 0.1, size.height * 0.1);
        path.cubicTo(
          size.width * 0.3, size.height * 0.2,
          size.width * 0.6, size.height * 0.8,
          size.width, size.height * 0.9,
        );
        break;
      case BalanceStatus.neutral:
        path.moveTo(size.width * 0.1, size.height / 2);
        path.lineTo(size.width, size.height / 2);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BalanceTrendPainter oldDelegate) {
    return oldDelegate.status != status || oldDelegate.color != color;
  }
}