// lib/widgets/shared/shareable_profile_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/achievement_model.dart';
import 'package:sasper/models/profile_model.dart';

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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final secondaryColor = Theme.of(context).colorScheme.secondary;

    return Material(
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor.withOpacity(0.9), secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ... (Sección del Perfil se mantiene igual)
            Text(
              'SasPer',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.white,
              child: Text(
                'Nivel ${profile.level}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: primaryColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile.fullName ?? 'Usuario',
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${profile.xpPoints} XP',
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 24),

            // Sección de Logros
            Text('Mis Medallas',
                style:
                    TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // <-- Reducimos a 4 para dar más espacio al texto
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8, // <-- Hacemos las celdas un poco más altas que anchas
              ),
              itemCount: allAchievements.length,
              itemBuilder: (context, index) {
                final achievement = allAchievements[index];
                final isUnlocked = unlockedAchievementIds.contains(achievement.id);

                // --- ¡NUEVA LÓGICA CON ICONO Y TEXTO! ---
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // El icono circular que ya teníamos
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isUnlocked ? Colors.amber.withOpacity(0.2) : Colors.black.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUnlocked ? Colors.amber : Colors.grey.shade700,
                          width: 1.5
                        )
                      ),
                      child: Icon(
                        Iconsax.award,
                        size: 28,
                        color: isUnlocked ? Colors.amber : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // El texto del título
                    Text(
                      achievement.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        // El texto es blanco para que sea legible, un poco más opaco si está bloqueado
                        color: isUnlocked ? Colors.white : Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Pie de página
            Text(
              '¡Mira cuánto he logrado con SasPer!',
              style: TextStyle(
                  fontStyle: FontStyle.italic, color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }
}