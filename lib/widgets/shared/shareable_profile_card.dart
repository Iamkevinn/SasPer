import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // <-- Eliminamos esta importación
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/achievement_model.dart';
import 'package:sasper/models/profile_model.dart';
import 'dart:math' as math;

class ShareableProfileCard extends StatelessWidget {
  final Profile profile;
  final List<Achievement> allAchievements;
  final Set<String> unlockedAchievementIds;

  const ShareableProfileCard({
    super.key,
    required this.profile,
    required this.allAchievements,
    required this.unlockedAchievementIds,
  });

  @override
  Widget build(BuildContext context) {
    final progress = _calculateLevelProgress(profile.level, profile.xpPoints);
    final unlockedCount = unlockedAchievementIds.length;

    return Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getBackgroundGradient(),
        ),
      ),
      child: Stack(
        children: [
          _buildBackgroundPattern(),
          Padding(
            padding: const EdgeInsets.all(60.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Spacer(flex: 1),
                _buildHeroTitle(),
                const SizedBox(height: 80),
                Center(child: _buildLevelIllustration(progress)),
                const SizedBox(height: 80),
                _buildAchievementsCard(unlockedCount),
                const SizedBox(height: 60),
                _buildMotivationalMessage(unlockedCount),
                const Spacer(flex: 2),
                _buildFooter(),
              ],
            ),
          ),
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899).withOpacity(0.2),
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
          // --- CAMBIO ---
          style: const TextStyle(
            fontFamily: 'Poppins', // Opcional, si tienes la fuente localmente
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroTitle() {
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
              const Icon(Iconsax.user, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Perfil de Progreso',
                // --- CAMBIO ---
                style: TextStyle(
                  fontFamily: 'Inter', // Opcional
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
          profile.fullName ?? 'Usuario de SasPer',
          // --- CAMBIO ---
          style: const TextStyle(
            fontFamily: 'Poppins', // Opcional
            fontSize: 56,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLevelIllustration(double progress) {
    const levelColor = Color(0xFFF59E0B);

    return Container(
      width: 450,
      height: 450,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [levelColor.withOpacity(0.15), Colors.transparent],
          stops: const [0.5, 1.0],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 380,
            height: 380,
            child: CustomPaint(
              painter: _ProgressCirclePainter(
                progress: progress,
                color: levelColor,
              ),
            ),
          ),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 60),
                BoxShadow(
                    color: levelColor.withOpacity(0.3),
                    blurRadius: 80,
                    spreadRadius: 10),
              ],
              border: Border.all(color: levelColor.withOpacity(0.5), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NIVEL',
                  // --- CAMBIO ---
                  style: TextStyle(
                    fontFamily: 'Poppins', // Opcional
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: levelColor.withOpacity(0.8),
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  '${profile.level}',
                  // --- CAMBIO ---
                  style: const TextStyle(
                    fontFamily: 'Poppins', // Opcional
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Text(
                '${profile.xpPoints} XP',
                // --- CAMBIO ---
                style: const TextStyle(
                  fontFamily: 'Poppins', // Opcional
                  fontSize: 36,
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

  Widget _buildAchievementsCard(int unlockedCount) {
    const achievementColor = Color(0xFFF59E0B);

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
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis Medallas',
                // --- CAMBIO ---
                style: const TextStyle(
                  fontFamily: 'Poppins', // Opcional
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: achievementColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: achievementColor.withOpacity(0.5), width: 1),
                ),
                child: Text(
                  '$unlockedCount / ${allAchievements.length}',
                  // --- CAMBIO ---
                  style: const TextStyle(
                    fontFamily: 'Poppins', // Opcional
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: achievementColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 30,
              mainAxisSpacing: 30,
            ),
            itemCount: math.min(allAchievements.length, 10),
            itemBuilder: (context, index) {
              final achievement = allAchievements[index];
              final isUnlocked =
                  unlockedAchievementIds.contains(achievement.id);
              return _buildAchievementBadge(
                  achievement, isUnlocked, achievementColor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementBadge(
      Achievement achievement, bool isUnlocked, Color color) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUnlocked
                  ? LinearGradient(
                      colors: [color, color.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUnlocked ? null : Colors.black.withOpacity(0.3),
              border: Border.all(
                  color: isUnlocked ? color : Colors.white.withOpacity(0.3),
                  width: 2),
            ),
            child: Icon(
              Iconsax.award,
              size: 40,
              color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            // --- CAMBIO ---
            style: const TextStyle(
              fontFamily: 'Inter', // Opcional
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalMessage(int unlockedCount) {
    final message = _getMotivationalMessageForProfile(
        unlockedCount, allAchievements.length);
    const accentColor = Color(0xFFEC4899);

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.2),
            accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accentColor.withOpacity(0.4), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.magic_star, color: accentColor, size: 40),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              message,
              // --- CAMBIO ---
              style: const TextStyle(
                fontFamily: 'Inter', // Opcional
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Generado con',
          // --- CAMBIO ---
          style: TextStyle(
            fontFamily: 'Inter', // Opcional
            fontSize: 22,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'SasPer',
          // --- CAMBIO ---
          style: const TextStyle(
            fontFamily: 'Poppins', // Opcional
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  // El resto de los helpers y painters no necesitan cambios
  List<Color> _getBackgroundGradient() {
    return [const Color(0xFF3730A3), const Color(0xFF312E81)];
  }

  String _getMotivationalMessageForProfile(int unlockedCount, int totalCount) {
    if (unlockedCount == 0) return '¡El primer paso de un gran viaje! Tu próxima medalla te espera. ✨';
    if (unlockedCount >= totalCount) return '¡Maestría Total! Has desbloqueado todos los logros. ¡Eres una leyenda! 🏆';
    if (unlockedCount > totalCount / 2) return '¡Ya pasaste la mitad del camino! Sigue así, vas por una racha increíble. 🔥';
    return 'Cada medalla es un paso hacia la maestría financiera. ¡A por la siguiente! 🚀';
  }

  double _calculateLevelProgress(int level, int currentXp) {
    final xpForCurrentLevel = (level * level) * 100;
    final xpForNextLevel = ((level + 1) * (level + 1)) * 100;
    final currentLevelXp = currentXp - xpForCurrentLevel;
    final neededXp = xpForNextLevel - xpForCurrentLevel;
    if (neededXp <= 0) return 1.0;
    return (currentLevelXp / neededXp).clamp(0.0, 1.0);
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1;
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
    final bgPaint = Paint()..color = Colors.white.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 20;
    canvas.drawCircle(center, radius, bgPaint);
    final progressPaint = Paint()..shader = LinearGradient(colors: [color, color.withOpacity(0.7)]).createShader(Rect.fromCircle(center: center, radius: radius))..style = PaintingStyle.stroke..strokeWidth = 20..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, progressPaint);
  }
  @override
  bool shouldRepaint(_ProgressCirclePainter oldDelegate) => oldDelegate.progress != progress;
}