import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey _shareBoundaryKey = GlobalKey();
  bool _isSharing = false;
  bool _isUploading = false;

  // Variables para almacenar temporalmente los datos para la captura
  Profile? _profileToShare;
  List<Achievement>? _allAchievementsToShare;
  Set<String>? _unlockedIdsToShare;

  /// Captura el widget de perfil usando el método nativo y lo comparte.
  Future<void> _shareProfile() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);
    await Future.delayed(
        const Duration(milliseconds: 300)); // Espera a que la UI se pinte

    try {
      final boundary = _shareBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se pudo encontrar el widget a capturar.');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('No se pudieron obtener los bytes de la imagen.');
      }

      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/sasper_progress.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '¡Mira mi progreso en SasPer! 🚀 #FinanzasPersonales #SasPerApp',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al compartir la imagen: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _profileToShare = null;
          _allAchievementsToShare = null;
          _unlockedIdsToShare = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Usamos Stack para poder renderizar el widget de captura fuera de la pantalla
      body: Stack(
        children: [
          // Widget a capturar (invisible para el usuario)
          if (_profileToShare != null &&
              _allAchievementsToShare != null &&
              _unlockedIdsToShare != null)
            Positioned(
              // Posicionamos el widget muy arriba, fuera del área visible.
              top: -1921, // Un valor mayor que la altura de la tarjeta (1920)
              left: 0,
              child: RepaintBoundary(
                key: _shareBoundaryKey,
                // ¡LA SOLUCIÓN! Envolvemos todo en un Theme explícito.
                // Esto asegura que la tarjeta tenga acceso a todos los datos del
                // tema principal de la app, sin importar dónde se renderice.
                child: Theme(
                  data: Theme.of(context), // Copiamos el tema actual
                  child: Material(
                    type: MaterialType.transparency,
                    child: ShareableProfileCard(
                      profile: _profileToShare!,
                      allAchievements: _allAchievementsToShare!,
                      unlockedAchievementIds: _unlockedIdsToShare!,
                    ),
                  ),
                ),
              ),
            ),

          // UI principal visible de la pantalla
          StreamBuilder<Profile>(
            stream: ProfileRepository.instance.getUserProfileStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('No se encontró el perfil.'));
              }

              final profile = snapshot.data!;
              return _buildProfileUI(context, profile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileUI(BuildContext context, Profile profile) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280.0,
          pinned: true,
          stretch: true,
          backgroundColor: colorScheme.surface,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            // La propiedad 'title' ha sido eliminada.
            background: _buildProfileHeaderSliver(context, profile),
          ),
          actions: [
            _buildShareButton(),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                // Cada sección es un widget separado para mayor claridad
                _buildXpAndLevelCard(context, profile)
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 32),
                _buildAchievementsSection(context)
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 32),
                _buildCompletedChallenges(context)
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .slideY(begin: 0.2),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShareButton() {
    return StreamBuilder<Profile>(
      stream: ProfileRepository.instance.getUserProfileStream(),
      builder: (context, profileSnapshot) {
        return FutureBuilder<List<Achievement>>(
          future: AchievementRepository.instance.getAllAchievements(),
          builder: (context, achievementsSnapshot) {
            return StreamBuilder<Set<String>>(
              stream: AchievementRepository.instance
                  .getUnlockedAchievementIdsStream(),
              builder: (context, unlockedSnapshot) {
                final canShare = profileSnapshot.hasData &&
                    achievementsSnapshot.hasData &&
                    unlockedSnapshot.hasData;

                if (_isSharing) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }

                return IconButton(
                  icon: const Icon(Iconsax.share),
                  tooltip: 'Compartir Progreso',
                  onPressed: !canShare
                      ? null
                      : () {
                          setState(() {
                            _profileToShare = profileSnapshot.data!;
                            _allAchievementsToShare =
                                achievementsSnapshot.data!;
                            _unlockedIdsToShare = unlockedSnapshot.data!;
                          });
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) => _shareProfile());
                        },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileHeaderSliver(BuildContext context, Profile profile) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = profile.fullName ?? 'Usuario';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.1),
            colorScheme.surface,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.7],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: kToolbarHeight), // Espacio para la AppBar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: profile.avatarUrl != null
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                            fontSize: 40, color: colorScheme.onSurface),
                      )
                    : null,
              ),
              GestureDetector(
                onTap: _isUploading
                    ? null
                    : () async {
                        if (!mounted) return;
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        setState(() => _isUploading = true);
                        try {
                          await ProfileRepository.instance.uploadAvatar();

                          if (mounted) {
                            scaffoldMessenger.showSnackBar(const SnackBar(
                                content: Text('Avatar actualizado con éxito.'),
                                backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          if (mounted) {
                            // 3. Usa la referencia guardada. ¡Esto es 100% seguro!
                            scaffoldMessenger.showSnackBar(SnackBar(
                                content: Text('Error al subir imagen: $e'),
                                backgroundColor: Colors.red));
                          }
                        } finally {
                          if (mounted) setState(() => _isUploading = false);
                        }
                      },
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary,
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
          const SizedBox(height: 16),
          Text(
            displayName,
            style:
                GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Nivel Financiero ${profile.level}',
            style: GoogleFonts.inter(
                fontSize: 16,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3),
    );
  }

  Widget _buildXpAndLevelCard(BuildContext context, Profile profile) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainer,
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progreso del Nivel',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _ShinyProgressBar(progress: profile.levelProgress),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${profile.xpInCurrentLevel} XP',
                  style: GoogleFonts.inter(
                      color: colorScheme.primary, fontWeight: FontWeight.w600)),
              Text('${profile.xpForNextLevel} XP para Nv. ${profile.level + 1}',
                  style:
                      GoogleFonts.inter(color: colorScheme.onSurfaceVariant)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAchievementsSection(BuildContext context) {
    final achievementRepo = AchievementRepository.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Medallas y Logros',
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FutureBuilder<List<Achievement>>(
          future: achievementRepo.getAllAchievements(),
          builder: (context, snapshotAll) {
            if (snapshotAll.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()));
            }
            if (!snapshotAll.hasData || snapshotAll.data!.isEmpty) {
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
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: allAchievements.length,
                  itemBuilder: (context, index) {
                    final achievement = allAchievements[index];
                    final isUnlocked = unlockedIds.contains(achievement.id);
                    return _buildAchievementBadge(achievement, isUnlocked);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAchievementBadge(Achievement achievement, bool isUnlocked) {
    final colorScheme = Theme.of(context).colorScheme;
    const achievementColor = Colors.amber;

    return Tooltip(
      message: "${achievement.title}\n${achievement.description}",
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.5,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? achievementColor.withOpacity(0.15)
                    : colorScheme.surfaceContainer,
                border: Border.all(
                    color: isUnlocked
                        ? achievementColor
                        : colorScheme.outlineVariant.withOpacity(0.5)),
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                            color: achievementColor.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2)
                      ]
                    : null,
              ),
              child: Icon(
                achievement.iconName.contains('level')
                    ? Iconsax.level
                    : (achievement.iconName.contains('streak')
                        ? Iconsax.flash_1
                        : Iconsax.award),
                size: 28,
                color: isUnlocked
                    ? achievementColor
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedChallenges(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de Retos',
            style:
                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        StreamBuilder<List<UserChallenge>>(
          stream: ChallengeRepository.instance.getUserChallengesStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final completed =
                snapshot.data!.where((c) => c.status == 'completed').toList();
            if (completed.isEmpty) {
              return const Center(
                  child: Text('Completa retos para ver tu historial.'));
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final userChallenge = completed[index];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colorScheme.surfaceContainer,
                    border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.withOpacity(0.1)),
                        child: const Icon(Iconsax.check,
                            color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userChallenge.challengeDetails.title,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                'Completado el ${userChallenge.endDate.day}/${userChallenge.endDate.month}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Text('+${userChallenge.challengeDetails.rewardXp} XP',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary)),
                    ],
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

// Widget personalizado para la barra de progreso animada y brillante
class _ShinyProgressBar extends StatelessWidget {
  final double progress;
  const _ShinyProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: FractionallySizedBox(
          widthFactor: progress,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.tertiary,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
