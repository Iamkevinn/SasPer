// lib/screens/profile_screen.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/data/profile_repository.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/models/profile_model.dart';
import 'package:sasper/data/achievement_repository.dart';
import 'package:sasper/models/achievement_model.dart';
import 'package:sasper/widgets/shared/shareable_profile_card.dart';
import 'package:screenshot/screenshot.dart'; // <-- Importa el paquete
import 'package:share_plus/share_plus.dart'; 

// Convertimos a StatefulWidget para manejar el estado de "compartiendo"
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controlador para el widget que vamos a capturar
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  /// Función principal que captura el widget y lo comparte
  Future<void> _shareProfile(
    Profile profile,
    List<Achievement> allAchievements,
    Set<String> unlockedIds,
  ) async {
    // 1. Mostramos un indicador de carga
    setState(() => _isSharing = true);

    try {
      // 2. Capturamos el widget usando el controlador. El 'pixelRatio' mejora la calidad.
      final Uint8List? imageBytes = await _screenshotController.captureFromLongWidget(
        InheritedTheme.captureAll(
          context, 
          ShareableProfileCard(
            profile: profile,
            allAchievements: allAchievements,
            unlockedAchievementIds: unlockedIds,
          ),
        ),
        delay: const Duration(milliseconds: 100),
        context: context,
        pixelRatio: 2.0, // Aumenta la resolución de la imagen
      );
      
      if (imageBytes == null) return;

      // 3. Guardamos la imagen en un archivo temporal
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = await File('${directory.path}/sasper_progress.png').create();
      await imagePath.writeAsBytes(imageBytes);

      // 4. Usamos share_plus para abrir el diálogo nativo de compartir
      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: '¡Mira mi progreso en SasPer! #FinanzasPersonales #SasPerApp',
      );
    } catch (e) {
      print("Error al compartir: $e");
    } finally {
      // 5. Ocultamos el indicador de carga, incluso si hay un error
      setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Progreso', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          // Añadimos un StreamBuilder para que el botón de compartir tenga acceso a los datos
          StreamBuilder<Profile>(
            stream: ProfileRepository.instance.getUserProfileStream(),
            builder: (context, profileSnapshot) {
              if (!profileSnapshot.hasData) return const SizedBox.shrink();
              return FutureBuilder<List<Achievement>>(
                future: AchievementRepository.instance.getAllAchievements(),
                builder: (context, achievementsSnapshot) {
                  if (!achievementsSnapshot.hasData) return const SizedBox.shrink();
                  return StreamBuilder<Set<String>>(
                    stream: AchievementRepository.instance.getUnlockedAchievementIdsStream(),
                    builder: (context, unlockedSnapshot) {
                      if (!unlockedSnapshot.hasData) return const SizedBox.shrink();
                      
                      // Botón de compartir
                      return _isSharing
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator()),
                            )
                          : IconButton(
                              icon: const Icon(Iconsax.share),
                              tooltip: 'Compartir Progreso',
                              onPressed: () => _shareProfile(
                                profileSnapshot.data!,
                                achievementsSnapshot.data!,
                                unlockedSnapshot.data!,
                              ),
                            );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // El 'Screenshot' widget es invisible, solo sirve para capturar su hijo.
          // NO usamos Offstage para que los temas se capturen correctamente.
          Screenshot(
             controller: _screenshotController,
             child: const SizedBox.shrink() // No es necesario, el widget se pasa directamente en captureFromLongWidget
          ),
          
          // La UI visible para el usuario se mantiene igual
          StreamBuilder<Profile>(
            stream: ProfileRepository.instance.getUserProfileStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final profile = snapshot.data!;
              return _buildProfileContent(context, profile);
            },
          ),
        ],
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