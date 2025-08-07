import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

// El enum y la extensión se mantienen, son una excelente práctica.
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

  // Este ya no lo usaremos, la gráfica lo reemplaza.
  // IconData get icon { ... }
}

class BalanceCard extends StatefulWidget {
  final double totalBalance;

  const BalanceCard({super.key, required this.totalBalance});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  bool _isBalanceVisible = true;
  late final AnimationController _eyeAnimationController;

  @override
  void initState() {
    super.initState();
    _eyeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _eyeAnimationController.dispose();
    super.dispose();
  }

  void _toggleVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
      if (_isBalanceVisible) {
        _eyeAnimationController.reverse();
      } else {
        _eyeAnimationController.forward();
      }
    });
  }

  BalanceStatus get _status => widget.totalBalance > 0
      ? BalanceStatus.positive
      : widget.totalBalance < 0
          ? BalanceStatus.negative
          : BalanceStatus.neutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final statusColor = _status.getColor(context);
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

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
        // --- NOVEDAD: Usamos un Stack para superponer la gráfica ---
        child: Stack(
          children: [
            // --- NOVEDAD: Gráfica de tendencia posicionada en la esquina ---
            Positioned(
              bottom: -2,
              right: -2,
              child: SizedBox(
                width: 80,
                height: 50,
                child: CustomPaint(
                  painter: _BalanceTrendPainter(
                    status: _status,
                    // Usamos el mismo color pero con opacidad para que sea más sutil
                    color: statusColor.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            
            // Contenido principal de la tarjeta
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saldo Total',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Text(
                      key: ValueKey<bool>(_isBalanceVisible),
                      _isBalanceVisible
                          ? currencyFormat.format(widget.totalBalance)
                          : '∗∗∗∗',
                      style: textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: _isBalanceVisible ? -1 : 4,
                      ),
                    ),
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


// --- NOVEDAD: Widget de dibujo personalizado para la gráfica de tendencia ---
class _BalanceTrendPainter extends CustomPainter {
  final BalanceStatus status;
  final Color color;

  _BalanceTrendPainter({required this.status, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5 // Grosor de la línea
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round; // Extremos de línea redondeados

    final path = Path();
    
    switch (status) {
      case BalanceStatus.positive:
        // Dibuja una línea que empieza abajo y termina arriba (tendencia positiva)
        path.moveTo(size.width * 0.1, size.height * 0.9); // Inicio
        path.cubicTo(
          size.width * 0.3, size.height * 0.8, // Punto de control 1
          size.width * 0.6, size.height * 0.2, // Punto de control 2
          size.width, size.height * 0.1,      // Fin
        );
        break;
      case BalanceStatus.negative:
        // Dibuja una línea que empieza arriba y termina abajo (tendencia negativa)
        path.moveTo(size.width * 0.1, size.height * 0.1); // Inicio
        path.cubicTo(
          size.width * 0.3, size.height * 0.2, // Punto de control 1
          size.width * 0.6, size.height * 0.8, // Punto de control 2
          size.width, size.height * 0.9,      // Fin
        );
        break;
      case BalanceStatus.neutral:
        // Dibuja una línea horizontal
        path.moveTo(size.width * 0.1, size.height / 2);
        path.lineTo(size.width, size.height / 2);
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BalanceTrendPainter oldDelegate) {
    // Solo redibuja si el estado o el color han cambiado
    return oldDelegate.status != status || oldDelegate.color != color;
  }
}