// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/data/profile_repository.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/models/profile_model.dart';
import 'package:sasper/data/achievement_repository.dart';
import 'package:sasper/models/achievement_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Progreso', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<Profile>(
        stream: ProfileRepository.instance.getUserProfileStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return _buildProfileContent(context, profile);
        },
      ),
    );
  }

  // Modifica el _buildProfileContent para añadir la nueva sección
  Widget _buildProfileContent(BuildContext context, Profile profile) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileHeader(context, profile),
        const SizedBox(height: 24),
        _buildXpAndLevelCard(context, profile),
        const SizedBox(height: 24),
        _buildAchievementsSection(context), // <--- NUEVA SECCIÓN
        const SizedBox(height: 24),
        _buildCompletedChallenges(context),
      ],
    );
  }

    // --- AÑADE ESTE WIDGET COMPLETAMENTE NUEVO ---
    Widget _buildAchievementsSection(BuildContext context) {
    final achievementRepo = AchievementRepository.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medallas y Logros',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        
        FutureBuilder<List<Achievement>>(
          future: achievementRepo.getAllAchievements(),
          builder: (context, snapshotAll) {
            // --- ¡CORRECCIÓN CLAVE AQUÍ! ---
            // Si estamos cargando, mostramos un contenedor con un tamaño FIJO.
            if (snapshotAll.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100, // Le damos una altura fija
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshotAll.hasError || !snapshotAll.hasData || snapshotAll.data!.isEmpty) {
              return const Center(child: Text('No hay logros disponibles.'));
            }
            
            final allAchievements = snapshotAll.data!;

            return StreamBuilder<Set<String>>(
              stream: achievementRepo.getUnlockedAchievementIdsStream(),
              builder: (context, snapshotUnlocked) {
                final unlockedIds = snapshotUnlocked.data ?? {};

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: allAchievements.length,
                  itemBuilder: (context, index) {
                    final achievement = allAchievements[index];
                    final isUnlocked = unlockedIds.contains(achievement.id);

                    // Mapeo simple de nombre a icono (puedes expandir esto)
                    final IconData iconData = achievement.iconName.contains('level') 
                        ? Iconsax.level 
                        : achievement.iconName.contains('streak')
                            ? Iconsax.flash_1
                            : Iconsax.award;
                    
                    final iconColor = isUnlocked ? Colors.amber : Colors.grey.shade600;

                    return Tooltip(
                      message: "${achievement.title}\n${achievement.description}",
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconData, size: 32, color: iconColor),
                          const SizedBox(height: 4),
                          Text(
                            achievement.title,
                            textAlign: TextAlign.center,
                            maxLines: 2, // Para evitar desbordamientos con títulos largos
                            style: TextStyle(
                              fontSize: 10,
                              color: isUnlocked ? Theme.of(context).colorScheme.onSurface : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }


  Widget _buildProfileHeader(BuildContext context, Profile profile) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            profile.fullName?.isNotEmpty == true ? profile.fullName![0].toUpperCase() : 'U',
            style: TextStyle(fontSize: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.fullName ?? 'Usuario',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              'Nivel Financiero ${profile.level}',
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildXpAndLevelCard(BuildContext context, Profile profile) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progreso del Nivel ${profile.level}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: profile.levelProgress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${profile.xpInCurrentLevel} XP'),
                Text('${profile.xpForNextLevel} XP para Nv. ${profile.level + 1}'),
              ],
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompletedChallenges(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logros Obtenidos',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Reutilizamos la lógica de la pantalla de retos
        StreamBuilder<List<UserChallenge>>(
          stream: ChallengeRepository.instance.getUserChallengesStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final completed = snapshot.data!.where((c) => c.status == 'completed').toList();

            if (completed.isEmpty) {
              return const Text('¡Completa tu primer reto para ganar un logro!');
            }
            
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completed.length,
              itemBuilder: (context, index) {
                final userChallenge = completed[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: ListTile(
                    leading: const Icon(Iconsax.award, color: Colors.amber),
                    title: Text(userChallenge.challengeDetails.title),
                    subtitle: Text('Completado el ${userChallenge.endDate.day}/${userChallenge.endDate.month}'),
                    trailing: Text('+${userChallenge.challengeDetails.rewardXp} XP'),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}