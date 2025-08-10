// C:\Proyectos\SasPer\lib\widgets\dashboard\balance_card.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
// NOVEDAD: Importamos el paquete para guardar las preferencias.
import 'package:shared_preferences/shared_preferences.dart';

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
}

class BalanceCard extends StatefulWidget {
  final double totalBalance;

  const BalanceCard({super.key, required this.totalBalance});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> with SingleTickerProviderStateMixin {
  // Se mantiene el valor inicial en true, pero se sobrescribirá al cargar las preferencias.
  bool _isBalanceVisible = true;
  late final AnimationController _eyeAnimationController;

  // NOVEDAD: Definimos una clave constante para guardar la preferencia.
  static const String _balanceVisibilityKey = 'balance_visibility_preference';

  @override
  void initState() {
    super.initState();
    _eyeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // NOVEDAD: Llamamos a la función para cargar la preferencia del usuario.
    _loadVisibilityPreference();
  }
  
  // NOVEDAD: Nueva función asíncrona para cargar el estado de visibilidad.
  Future<void> _loadVisibilityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // Leemos el valor guardado. Si no existe (la primera vez que se usa la app),
    // el valor por defecto será 'true' (visible).
    setState(() {
      _isBalanceVisible = prefs.getBool(_balanceVisibilityKey) ?? true;
      // Sincronizamos la animación del ojo con el estado cargado.
      if (_isBalanceVisible) {
        _eyeAnimationController.value = 0; // Ojo abierto
      } else {
        _eyeAnimationController.value = 1; // Ojo cerrado
      }
    });
  }

  // NOVEDAD: Nueva función asíncrona para guardar el estado de visibilidad.
  Future<void> _saveVisibilityPreference(bool isVisible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_balanceVisibilityKey, isVisible);
  }


  @override
  void dispose() {
    _eyeAnimationController.dispose();
    super.dispose();
  }

  // NOVEDAD: La función ahora es 'async' para poder guardar la preferencia.
  void _toggleVisibility() async {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
      if (_isBalanceVisible) {
        _eyeAnimationController.reverse();
      } else {
        _eyeAnimationController.forward();
      }
    });
    // NOVEDAD: Guardamos el nuevo estado cada vez que se cambia.
    await _saveVisibilityPreference(_isBalanceVisible);
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
        child: Stack(
          children: [
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

// El widget _BalanceTrendPainter no necesita cambios.
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