// lib/screens/profile_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sasper/data/achievement_repository.dart';
import 'package:sasper/data/profile_repository.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/models/achievement_model.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/models/profile_model.dart';
import 'package:sasper/widgets/shared/shareable_profile_card.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;
  bool _isUploading = false;

  /// Captura el widget de perfil y abre el diálogo para compartirlo.
  Future<void> _shareProfile(
    Profile profile,
    List<Achievement> allAchievements,
    Set<String> unlockedIds,
  ) async {
    setState(() => _isSharing = true);
    try {
      final Uint8List imageBytes =
          await _screenshotController.captureFromLongWidget(
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
        pixelRatio: 2.0,
      );

      if (imageBytes == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final imagePath =
          await File('${directory.path}/sasper_progress.png').create();
      await imagePath.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: '¡Mira mi progreso en SasPer! #FinanzasPersonales #SasPerApp',
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error al compartir: $e");
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mi Progreso',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          // StreamBuilder anidado para dar acceso a los datos al botón de compartir
          StreamBuilder<Profile>(
            stream: ProfileRepository.instance.getUserProfileStream(),
            builder: (context, profileSnapshot) {
              if (!profileSnapshot.hasData) return const SizedBox.shrink();
              return FutureBuilder<List<Achievement>>(
                future: AchievementRepository.instance.getAllAchievements(),
                builder: (context, achievementsSnapshot) {
                  if (!achievementsSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  return StreamBuilder<Set<String>>(
                    stream: AchievementRepository.instance
                        .getUnlockedAchievementIdsStream(),
                    builder: (context, unlockedSnapshot) {
                      if (!unlockedSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      return _isSharing
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
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
          // Widget invisible para la captura, no interfiere con la UI
          Screenshot(
              controller: _screenshotController,
              child: const SizedBox.shrink()),

          StreamBuilder<Profile>(
            stream: ProfileRepository.instance.getUserProfileStream(),
            builder: (context, snapshot) {
              // --- ¡CORRECCIÓN! ---
              // Esta es una forma más robusta y estándar de manejar los estados de un StreamBuilder.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('No se encontró el perfil.'));
              }

              // Si llegamos aquí, tenemos datos.
              final profile = snapshot.data!;
              return _buildProfileContent(context, profile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, Profile profile) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileHeader(context, profile),
        const SizedBox(height: 24),
        _buildXpAndLevelCard(context, profile),
        const SizedBox(height: 24),
        _buildAchievementsSection(context),
        const SizedBox(height: 24),
        _buildCompletedChallenges(context),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, Profile profile) {
    final displayName = profile.fullName ?? 'Usuario';

    return Row(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl == null
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                          fontSize: 32,
                          color: Theme.of(context).colorScheme.onSurface),
                    )
                  : null,
            ),
            GestureDetector(
              onTap: _isUploading
                  ? null
                  : () async {
                      setState(() => _isUploading = true);
                      try {
                        await ProfileRepository.instance.uploadAvatar();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error al subir imagen: $e'),
                                backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isUploading = false);
                      }
                    },
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Iconsax.edit, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                'Nivel Financiero ${profile.level}',
                style: TextStyle(
                    fontSize: 16, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildXpAndLevelCard(BuildContext context, Profile profile) {
    // ... (Este widget no necesita cambios)
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progreso del Nivel ${profile.level}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
                Text(
                    '${profile.xpForNextLevel} XP para Nv. ${profile.level + 1}'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context) {
    // ... (Este widget no necesita cambios, ya lo corregimos antes)
    final achievementRepo = AchievementRepository.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medallas y Logros',
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        FutureBuilder<List<Achievement>>(
          future: achievementRepo.getAllAchievements(),
          builder: (context, snapshotAll) {
            if (snapshotAll.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (snapshotAll.hasError ||
                !snapshotAll.hasData ||
                snapshotAll.data!.isEmpty) {
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
                      childAspectRatio: 0.8),
                  itemCount: allAchievements.length,
                  itemBuilder: (context, index) {
                    final achievement = allAchievements[index];
                    final isUnlocked = unlockedIds.contains(achievement.id);
                    final iconData = achievement.iconName.contains('level')
                        ? Iconsax.level
                        : achievement.iconName.contains('streak')
                            ? Iconsax.flash_1
                            : Iconsax.award;
                    final iconColor =
                        isUnlocked ? Colors.amber : Colors.grey.shade600;
                    return Tooltip(
                      message:
                          "${achievement.title}\n${achievement.description}",
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(iconData, size: 32, color: iconColor),
                          const SizedBox(height: 4),
                          Text(
                            achievement.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(
                                fontSize: 10,
                                color: isUnlocked
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.grey.shade600),
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

  Widget _buildCompletedChallenges(BuildContext context) {
    // ... (Este widget no necesita cambios)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de Retos',
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        StreamBuilder<List<UserChallenge>>(
          stream: ChallengeRepository.instance.getUserChallengesStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final completed =
                snapshot.data!.where((c) => c.status == 'completed').toList();
            if (completed.isEmpty) {
              return const Text(
                  '¡Completa tu primer reto para ganar un logro!');
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
                    leading: const Icon(Iconsax.check, color: Colors.green),
                    title: Text(userChallenge.challengeDetails.title),
                    subtitle: Text(
                        'Completado el ${userChallenge.endDate.day}/${userChallenge.endDate.month}'),
                    trailing:
                        Text('+${userChallenge.challengeDetails.rewardXp} XP'),
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
