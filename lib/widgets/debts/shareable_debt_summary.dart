// lib/widgets/debts/shareable_debt_summary.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/debt_model.dart';
import 'dart:math' as math;

class ShareableDebtSummary extends StatelessWidget {
  final Debt debt;

  const ShareableDebtSummary({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    // Forzar modo oscuro para mejor contraste en redes sociales
    final isDark = true;
    
    final progress = debt.paidAmount / debt.initialAmount;
    final remaining = debt.initialAmount - debt.paidAmount;
    
    // Determinar estado emocional
    final status = _getDebtStatus(progress);
    
    return Container(
      width: 1080, // Tamaño Instagram Story
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getBackgroundGradient(status, isDark),
        ),
      ),
      child: Stack(
        children: [
          // Patrón de fondo sutil
          _buildBackgroundPattern(),
          
          // Contenido principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(60.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con logo/branding
                  _buildHeader(),
                  
                  const Spacer(flex: 1),
                  
                  // Hero Title
                  _buildHeroTitle(status),
                  
                  const SizedBox(height: 80),
                  
                  // Ilustración emocional 3D-style
                  Center(
                    child: _buildEmotionalIllustration(status, progress),
                  ),
                  
                  const SizedBox(height: 80),
                  
                  // Tarjeta principal con datos
                  _buildMainDataCard(remaining, progress, status),
                  
                  const SizedBox(height: 60),
                  
                  // Mensaje motivacional IA
                  _buildMotivationalMessage(status, progress),
                  
                  const Spacer(flex: 2),
                  
                  // Footer con CTA
                  _buildFooter(),
                ],
              ),
            ),
          ),
          
          // Efecto de brillo superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.5,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== COMPONENTES ====================

  Widget _buildBackgroundPattern() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridPatternPainter(),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF0EA5A5)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Iconsax.chart_success,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 20),
        Text(
          'SasPer',
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroTitle(DebtStatusType status) {
    String title;
    IconData icon;
    
    switch (status) {
      case DebtStatusType.almostDone:
        title = '¡Casi lo logras! 🎯';
        icon = Iconsax.medal_star;
        break;
      case DebtStatusType.onTrack:
        title = 'Progreso Sólido 💪';
        icon = Iconsax.trend_up;
        break;
      case DebtStatusType.needsAttention:
        title = 'Mantén el Control ⚡';
        icon = Iconsax.flash_1;
        break;
      case DebtStatusType.paid:
        title = '¡DEUDA ELIMINADA! 🎉';
        icon = Iconsax.tick_circle;
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Mi Estado Financiero',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmotionalIllustration(DebtStatusType status, double progress) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo de progreso animado
          SizedBox(
            width: 320,
            height: 320,
            child: CustomPaint(
              painter: _ProgressCirclePainter(
                progress: progress,
                color: _getStatusColor(status),
              ),
            ),
          ),
          
          // Ícono central
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getStatusColor(status).withOpacity(0.3),
                  _getStatusColor(status).withOpacity(0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(status).withOpacity(0.4),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
            child: Icon(
              _getStatusIcon(status),
              size: 100,
              color: Colors.white,
            ),
          ),
          
          // Porcentaje
          Positioned(
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDataCard(double remaining, double progress, DebtStatusType status) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    
    return Container(
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          // Nombre de la deuda
            // Nombre de la deuda y persona involucrada
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Alinea al inicio si el texto ocupa varias líneas
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  debt.type == DebtType.debt ? Iconsax.card_remove : Iconsax.card_tick,
                  color: _getStatusColor(status),
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título de la deuda
                    Text(
                      debt.name,
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2, // Ajusta el interlineado
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Solo muestra la sección de la persona si el nombre existe
                    if (debt.entityName != null && debt.entityName!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              debt.type == DebtType.debt ? 'Acreedor: ' : 'Deudor: ',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                debt.entityName!,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Monto restante (hero number)
          Column(
            children: [
              Text(
                'Monto Restante',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                currencyFormat.format(remaining),
                style: GoogleFonts.poppins(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                  letterSpacing: -3,
                  shadows: [
                    Shadow(
                      color: _getStatusColor(status).withOpacity(0.5),
                      blurRadius: 30,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Barra de progreso premium
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Fondo animado
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ShimmerPainter(),
                    ),
                  ),
                  // Progreso
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getStatusColor(status),
                            _getStatusColor(status).withOpacity(0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getStatusColor(status).withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Stats secundarios
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Pagado', currencyFormat.format(debt.paidAmount)),
              Container(
                width: 2,
                height: 60,
                color: Colors.white.withOpacity(0.2),
              ),
              _buildStatItem('Total', currencyFormat.format(debt.initialAmount)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.white.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMotivationalMessage(DebtStatusType status, double progress) {
    final message = _getMotivationalMessage(status, progress);
    
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getStatusColor(status).withOpacity(0.2),
            _getStatusColor(status).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _getStatusColor(status),
                  _getStatusColor(status).withOpacity(0.7),
                ],
              ),
            ),
            child: const Icon(
              Iconsax.magic_star,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Separador elegante
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
        
        // CTA
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Controla tus finanzas con',
              style: GoogleFonts.inter(
                fontSize: 22,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'SasPer',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF0EA5A5)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.mobile, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Descarga la app',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HELPERS ====================

  DebtStatusType _getDebtStatus(double progress) {
    if (progress >= 1.0) return DebtStatusType.paid;
    if (progress >= 0.75) return DebtStatusType.almostDone;
    if (progress >= 0.4) return DebtStatusType.onTrack;
    return DebtStatusType.needsAttention;
  }

  List<Color> _getBackgroundGradient(DebtStatusType status, bool isDark) {
    switch (status) {
      case DebtStatusType.paid:
        return [const Color(0xFF065F46), const Color(0xFF0D9488)];
      case DebtStatusType.almostDone:
        return [const Color(0xFF1E3A8A), const Color(0xFF3B82F6)];
      case DebtStatusType.onTrack:
        return [const Color(0xFF7C2D12), const Color(0xFFEA580C)];
      case DebtStatusType.needsAttention:
        return [const Color(0xFF7C2D12), const Color(0xFFDC2626)];
    }
  }

  Color _getStatusColor(DebtStatusType status) {
    switch (status) {
      case DebtStatusType.paid:
        return const Color(0xFF10B981);
      case DebtStatusType.almostDone:
        return const Color(0xFF60A5FA);
      case DebtStatusType.onTrack:
        return const Color(0xFFFB923C);
      case DebtStatusType.needsAttention:
        return const Color(0xFFEF4444);
    }
  }

  IconData _getStatusIcon(DebtStatusType status) {
    switch (status) {
      case DebtStatusType.paid:
        return Iconsax.cup;
      case DebtStatusType.almostDone:
        return Iconsax.medal_star;
      case DebtStatusType.onTrack:
        return Iconsax.chart_success;
      case DebtStatusType.needsAttention:
        return Iconsax.flash_1;
    }
  }

  String _getMotivationalMessage(DebtStatusType status, double progress) {
    switch (status) {
      case DebtStatusType.paid:
        return '¡Increíble! Has eliminado esta deuda completamente. ¡Libertad financiera desbloqueada! 🎉';
      case DebtStatusType.almostDone:
        final remaining = ((1 - progress) * 100).toStringAsFixed(0);
        return '¡Solo un $remaining% más! Estás a punto de conquistar esta meta financiera. ¡No pares ahora! 🚀';
      case DebtStatusType.onTrack:
        return 'Vas por buen camino. Mantén la disciplina y verás los resultados pronto. ¡Tú puedes! 💪';
      case DebtStatusType.needsAttention:
        return 'Cada pequeño pago cuenta. Da el siguiente paso hoy y verás cómo crece tu progreso. 🌱';
    }
  }
}

// ==================== ENUMS ====================

enum DebtStatusType {
  paid,
  almostDone,
  onTrack,
  needsAttention,
}

// ==================== CUSTOM PAINTERS ====================

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 80.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressCirclePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ProgressCirclePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Círculo de fondo
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    canvas.drawCircle(center, radius, bgPaint);

    // Círculo de progreso
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withOpacity(0.7)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressCirclePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ShimmerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.05),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}