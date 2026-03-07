// lib/screens/profile_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Perfil — Apple-first redesign
//
// Eliminado:
// · SliverAppBar + FlexibleSpaceBar + LinearGradient → header blur + avatar limpio
// · CircleAvatar + badge de edit encima → área tappable completa con overlay sutil
// · flutter_animate .slideY() → _FadeInSlide propio
// · colorScheme.surfaceContainer + Border.all + outlineVariant → opacity-based surface
// · _ShinyProgressBar LinearGradient → _ProgressBar 4px unificado
// · GridView badges con BoxShape.circle + Border + BoxShadow → horizontal scroll limpio
// · Tooltip en badges → _AchievementDetailSheet on tap
// · 3×StreamBuilder anidados para share button → lógica separada
// · ListView retos completados duplicado → link "Ver en Hábitos →"
// · GoogleFonts.poppins + .inter → _T tokens DM Sans
// · ScaffoldMessenger SnackBar → NotificationHelper
// · XP row spaceBetween con dos números → barra + un dato clave
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sasper/data/achievement_repository.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/data/profile_repository.dart';
import 'package:sasper/models/achievement_model.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/models/profile_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/shareable_profile_card.dart';

// ── Tokens ─────────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s, fontWeight: w, color: c,
          letterSpacing: -0.4, height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);

  static TextStyle mono(double s,
          {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);

  static const double h  = 20.0;
  static const double r  = 18.0;
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kOrange = Color(0xFFFF9F0A);
const _kPurple = Color(0xFFBF5AF2);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey _shareBoundaryKey = GlobalKey();

  bool _isSharing    = false;
  bool _isUploading  = false;

  // Datos para captura de pantalla
  Profile?          _profileToShare;
  List<Achievement>? _achToShare;
  Set<String>?      _unlockedToShare;

  // Cache local para evitar reconstrucciones innecesarias del share button
  Profile?           _cachedProfile;
  List<Achievement>? _cachedAchievements;
  Set<String>?       _cachedUnlocked;

  // ── Share ────────────────────────────────────────────────────────────────
  Future<void> _shareProfile() async {
    if (_isSharing) return;
    // Necesitamos los tres datos listos
    if (_cachedProfile == null ||
        _cachedAchievements == null ||
        _cachedUnlocked == null) {
      return;
    }

    setState(() {
      _isSharing         = true;
      _profileToShare    = _cachedProfile;
      _achToShare        = _cachedAchievements;
      _unlockedToShare   = _cachedUnlocked;
    });

    // Espera un frame para que el RepaintBoundary se pinte
    await Future.delayed(const Duration(milliseconds: 350));

    try {
      final boundary = _shareBoundaryKey.currentContext
              ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Widget de captura no encontrado.');

      final image     = await boundary.toImage(pixelRatio: 2.0);
      final byteData  = await image.toByteData(
          format: ImageByteFormat.png);
      if (byteData == null) throw Exception('No se pudo convertir la imagen.');

      final pngBytes  = byteData.buffer.asUint8List();
      final tempDir   = await getTemporaryDirectory();
      final file      = await File(
              '${tempDir.path}/sasper_progress.png').create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '¡Mira mi progreso en SasPer! 🚀 #FinanzasPersonales',
      );
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al compartir: $e',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing        = false;
          _profileToShare   = null;
          _achToShare       = null;
          _unlockedToShare  = null;
        });
      }
    }
  }

  // ── Avatar upload ────────────────────────────────────────────────────────
  Future<void> _uploadAvatar() async {
    if (_isUploading) return;
    HapticFeedback.selectionClick();
    setState(() => _isUploading = true);
    try {
      await ProfileRepository.instance.uploadAvatar();
      if (mounted) {
        NotificationHelper.show(
            message: 'Foto actualizada',
            type: NotificationType.success);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al subir imagen',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(children: [
        // ── Widget invisible para captura ────────────────────────────────
        if (_profileToShare != null &&
            _achToShare != null &&
            _unlockedToShare != null)
          Positioned(
            top: -1921, left: 0,
            child: RepaintBoundary(
              key: _shareBoundaryKey,
              child: Theme(
                data: Theme.of(context),
                child: Material(
                  type: MaterialType.transparency,
                  child: ShareableProfileCard(
                    profile:              _profileToShare!,
                    allAchievements:      _achToShare!,
                    unlockedAchievementIds: _unlockedToShare!,
                  ),
                ),
              ),
            ),
          ),

        // ── UI principal ─────────────────────────────────────────────────
        StreamBuilder<Profile>(
          stream: ProfileRepository.instance.getUserProfileStream(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData) {
              return const Center(child: Text('Sin perfil.'));
            }

            final profile = snap.data!;
            // Cache para el share
            _cachedProfile = profile;

            return _ProfileBody(
              profile:      profile,
              isUploading:  _isUploading,
              isSharing:    _isSharing,
              onUpload:     _uploadAvatar,
              onShare:      () {
                HapticFeedback.selectionClick();
                _shareProfile();
              },
              onAchLoaded: (ach, unlocked) {
                _cachedAchievements = ach;
                _cachedUnlocked     = unlocked;
              },
            );
          },
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY — separado del Screen para claridad
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final Profile profile;
  final bool isUploading, isSharing;
  final VoidCallback onUpload, onShare;
  final void Function(List<Achievement>, Set<String>) onAchLoaded;

  const _ProfileBody({
    required this.profile,
    required this.isUploading,
    required this.isSharing,
    required this.onUpload,
    required this.onShare,
    required this.onAchLoaded,
  });

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;

    return Column(children: [
      // ── Header blur sticky ──────────────────────────────────────────────
      ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: theme.scaffoldBackgroundColor.withOpacity(0.93),
            padding: EdgeInsets.only(
                top: statusH + 10, left: _T.h + 4,
                right: 8, bottom: 14),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SASPER',
                      style: _T.label(10,
                          w: FontWeight.w700,
                          c: onSurf.withOpacity(0.35))),
                  Text('Perfil',
                      style: _T.display(28, c: onSurf)),
                ],
              )),
              // Compartir
              if (isSharing)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kBlue)),
                )
              else
                _HeaderBtn(
                    icon: Iconsax.share, onTap: onShare),
              const SizedBox(width: 4),
            ]),
          ),
        ),
      ),

      // ── Scroll ──────────────────────────────────────────────────────────
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(_T.h, 24, _T.h, 100),
          children: [
            // Avatar + nombre + nivel
            _AvatarSection(
              profile:     profile,
              isUploading: isUploading,
              onTap:       onUpload,
            ),
            const SizedBox(height: 28),

            // XP / Nivel
            _FadeInSlide(delay: const Duration(milliseconds: 60),
                child: _XpCard(profile: profile)),
            const SizedBox(height: 24),

            // Estadísticas rápidas
            _FadeInSlide(delay: const Duration(milliseconds: 100),
                child: _StatsRow(profile: profile)),
            const SizedBox(height: 28),

            // Logros — scroll horizontal
            _FadeInSlide(delay: const Duration(milliseconds: 140),
                child: _AchievementsSection(
                    onLoaded: onAchLoaded)),
            const SizedBox(height: 28),

            // Historial de retos — link compacto
            _FadeInSlide(delay: const Duration(milliseconds: 180),
                child: _ChallengeHistory()),
          ],
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR SECTION
// ─────────────────────────────────────────────────────────────────────────────
// Toda el área es tappable. Sin badge encima.
// Overlay sutil "Editar foto" aparece en un Container semitransparente
// en la mitad inferior del avatar — patrón iOS Camera.

class _AvatarSection extends StatefulWidget {
  final Profile profile;
  final bool isUploading;
  final VoidCallback onTap;
  const _AvatarSection({
    required this.profile,
    required this.isUploading,
    required this.onTap,
  });
  @override
  State<_AvatarSection> createState() => _AvatarSectionState();
}

class _AvatarSectionState extends State<_AvatarSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final profile = widget.profile;
    final name    = profile.fullName ?? 'Usuario';

    return Column(children: [
      // Avatar tappable
      GestureDetector(
        onTapDown: (_) {
          _c.forward(); HapticFeedback.selectionClick(); },
        onTapUp:   (_) { _c.reverse(); widget.onTap(); },
        onTapCancel: () => _c.reverse(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Transform.scale(
            scale: lerpDouble(1.0, 0.96, _c.value)!,
            child: SizedBox(
              width: 88, height: 88,
              child: Stack(children: [
                // Foto o inicial
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: profile.avatarUrl != null
                      ? Image.network(
                          profile.avatarUrl!,
                          width: 88, height: 88,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 88, height: 88,
                          color: _kBlue.withOpacity(0.12),
                          child: Center(
                            child: Text(
                              name.isNotEmpty
                                  ? name[0].toUpperCase() : 'U',
                              style: _T.display(36, c: _kBlue),
                            ),
                          ),
                        ),
                ),

                // Overlay "editar" en la mitad inferior
                if (!widget.isUploading)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(26)),
                      child: Container(
                        height: 28,
                        color: Colors.black.withOpacity(0.35),
                        child: Center(
                          child: Icon(Iconsax.camera,
                              size: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                // Loading spinner durante upload
                if (widget.isUploading)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),

      const SizedBox(height: 14),

      // Nombre
      Text(name, style: _T.display(24, c: onSurf)),
      const SizedBox(height: 4),

      // Nivel — badge compacto
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kPurple.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Nivel ${profile.level}',
          style: _T.label(12,
              c: _kPurple, w: FontWeight.w700)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// XP CARD
// ─────────────────────────────────────────────────────────────────────────────
// Un solo dato clave: XP restante para el siguiente nivel.
// La barra comunica el progreso visualmente — el número lo refuerza.

class _XpCard extends StatelessWidget {
  final Profile profile;
  const _XpCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final remaining = profile.xpForNextLevel - profile.xpInCurrentLevel;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kPurple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(child: Icon(
                  Iconsax.level, size: 16, color: _kPurple)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nivel ${profile.level}',
                    style: _T.label(13,
                        w: FontWeight.w700, c: onSurf)),
                Text('Faltan $remaining XP para Nivel ${profile.level + 1}',
                    style: _T.label(11,
                        c: onSurf.withOpacity(0.42))),
              ],
            )),
            Text(
              '${(profile.levelProgress * 100).toStringAsFixed(0)}%',
              style: _T.mono(15, c: _kPurple)),
          ]),
          const SizedBox(height: 14),
          _ProgressBar(
              value: profile.levelProgress, color: _kPurple),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW — 3 números clave en formato compacto
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Profile profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final stats = <(String, String, Color)>[
    ];

    return Row(children: stats.indexed.map((e) {
      final (i, (label, value, color)) = e;
      final isLast = i == stats.length - 1;
      return Expanded(
        child: Container(
          margin: EdgeInsets.only(right: isLast ? 0 : 10),
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: _T.label(11,
                      c: onSurf.withOpacity(0.40))),
              const SizedBox(height: 4),
              Text(value, style: _T.mono(18, c: onSurf)),
              const SizedBox(height: 3),
              Container(width: 16, height: 2,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  )),
            ],
          ),
        ),
      );
    }).toList());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACHIEVEMENTS — scroll horizontal
// ─────────────────────────────────────────────────────────────────────────────
// Sin grid aplastado. Scroll horizontal como iOS App Store "categorías".
// Tap en cada badge → _AchievementDetailSheet con descripción completa.

class _AchievementsSection extends StatelessWidget {
  final void Function(List<Achievement>, Set<String>) onLoaded;
  const _AchievementsSection({required this.onLoaded});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('LOGROS'),
        const SizedBox(height: 10),
        FutureBuilder<List<Achievement>>(
          future: AchievementRepository.instance.getAllAchievements(),
          builder: (_, snapAll) {
            if (!snapAll.hasData) {
              return const SizedBox(
                  height: 90,
                  child: Center(child: CircularProgressIndicator()));
            }
            final all = snapAll.data!;
            return StreamBuilder<Set<String>>(
              stream: AchievementRepository.instance
                  .getUnlockedAchievementIdsStream(),
              builder: (ctx, snapUnlocked) {
                final unlocked = snapUnlocked.data ?? {};
                // Notificamos al padre para el share
                onLoaded(all, unlocked);

                final unlockedList = all
                    .where((a) => unlocked.contains(a.id))
                    .toList();
                final lockedList = all
                    .where((a) => !unlocked.contains(a.id))
                    .toList();
                // Desbloqueados primero
                final sorted = [...unlockedList, ...lockedList];

                return SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 12),
                    itemBuilder: (ctx, i) => _AchievementBadge(
                      achievement: sorted[i],
                      isUnlocked: unlocked.contains(sorted[i].id),
                    ),
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

class _AchievementBadge extends StatefulWidget {
  final Achievement achievement;
  final bool isUnlocked;
  const _AchievementBadge({
    required this.achievement, required this.isUnlocked});
  @override
  State<_AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<_AchievementBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  IconData get _icon {
    final n = widget.achievement.iconName;
    if (n.contains('level'))  return Iconsax.level;
    if (n.contains('streak')) return Iconsax.flash_1;
    return Iconsax.award;
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final isUnlocked = widget.isUnlocked;
    final bg        = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return GestureDetector(
      onTapDown: (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) {
        _c.reverse();
        _openDetail(context);
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.92, _c.value)!,
          child: Opacity(
            opacity: isUnlocked ? 1.0 : 0.38,
            child: Container(
              width: 76,
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isUnlocked
                    ? _kOrange.withOpacity(0.10)
                    : bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icon,
                      size: 26,
                      color: isUnlocked ? _kOrange : onSurf.withOpacity(0.40)),
                  const SizedBox(height: 6),
                  Text(
                    widget.achievement.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _T.label(10,
                        c: isUnlocked
                            ? onSurf
                            : onSurf.withOpacity(0.40),
                        w: isUnlocked
                            ? FontWeight.w700
                            : FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _AchievementDetailSheet(
          achievement: widget.achievement,
          isUnlocked:  widget.isUnlocked,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORIAL DE RETOS — versión compacta
// ─────────────────────────────────────────────────────────────────────────────
// No duplicamos la lista completa que ya existe en challenges_screen.
// Mostramos los últimos 3 + un "Ver todos →" que navega a Hábitos.

class _ChallengeHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _SectionLabel('RETOS COMPLETADOS')),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<List<UserChallenge>>(
          stream: ChallengeRepository.instance.getUserChallengesStream(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()));
            }

            final completed = snap.data!
                .where((c) => c.status == 'completed')
                .toList();

            if (completed.isEmpty) {
              return _EmptyHistorial();
            }

            // Máximo 3 para no repetir toda la pantalla de hábitos
            final preview = completed.take(3).toList();

            return Column(children: [
              ...preview.asMap().entries.map((e) =>
                  _ChallengeTile(
                      uc: e.value,
                      delay: 40 * e.key)),
              if (completed.length > 3) ...[
                const SizedBox(height: 8),
                _VerTodosBtn(count: completed.length),
              ],
            ]);
          },
        ),
      ],
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final UserChallenge uc;
  final int delay;
  const _ChallengeTile({required this.uc, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return _FadeInSlide(
      delay: Duration(milliseconds: delay),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_T.r)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(child: Icon(
                Iconsax.tick_circle, color: _kGreen, size: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(uc.challengeDetails.title,
                  style: _T.label(14,
                      w: FontWeight.w700, c: onSurf)),
              const SizedBox(height: 2),
              Text(
                DateFormat("d MMM yyyy", "es_CO")
                    .format(uc.endDate),
                style: _T.label(11,
                    c: onSurf.withOpacity(0.40))),
            ],
          )),
          Text(
            '+${uc.challengeDetails.rewardXp} XP',
            style: _T.mono(12, c: _kPurple)),
        ]),
      ),
    );
  }
}

class _EmptyHistorial extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'Completa retos para ver tu historial aquí.',
          style: _T.label(14,
              c: onSurf.withOpacity(0.40),
              w: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _VerTodosBtn extends StatefulWidget {
  final int count;
  const _VerTodosBtn({required this.count});
  @override State<_VerTodosBtn> createState() => _VerTodosBtnState();
}

class _VerTodosBtnState extends State<_VerTodosBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return GestureDetector(
      onTapDown: (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) {
        _c.reverse();
        // El Bottom Nav de la app seleccionará el tab de Hábitos.
        // Si tienes un GlobalKey en el BottomNav, úsalo aquí.
        // Por ahora: notificación informativa.
        NotificationHelper.show(
            message: 'Ve a Hábitos para ver todos',
            type: NotificationType.info);
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(_T.r)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
              Text('Ver los ${widget.count} retos completados',
                  style: _T.label(14,
                      c: _kBlue, w: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: _kBlue),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEETS
// ─────────────────────────────────────────────────────────────────────────────

class _AchievementDetailSheet extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  const _AchievementDetailSheet({
    required this.achievement, required this.isUnlocked});

  IconData get _icon {
    final n = achievement.iconName;
    if (n.contains('level'))  return Iconsax.level;
    if (n.contains('streak')) return Iconsax.flash_1;
    return Iconsax.award;
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final color   = isUnlocked ? _kOrange : onSurf.withOpacity(0.30);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: onSurf.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2))),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Opacity(
                opacity: isUnlocked ? 1.0 : 0.40,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(_icon, size: 36, color: color),
                ),
              ),
              const SizedBox(height: 14),
              Text(achievement.title,
                  style: _T.display(20, c: onSurf),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(achievement.description,
                  style: _T.label(14,
                      c: onSurf.withOpacity(0.50),
                      w: FontWeight.w400),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? _kGreen.withOpacity(0.10)
                      : onSurf.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isUnlocked ? '✓ Desbloqueado' : 'Aún no desbloqueado',
                  style: _T.label(12,
                      c: isUnlocked
                          ? _kGreen
                          : onSurf.withOpacity(0.40),
                      w: FontWeight.w700)),
              ),
              const SizedBox(height: 20),
              _InlineBtn(
                  label: 'Cerrar', color: onSurf,
                  onTap: () => Navigator.pop(context)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return LayoutBuilder(builder: (_, c) => Stack(children: [
      Container(height: 4,
          decoration: BoxDecoration(
            color: onSurf.withOpacity(0.08),
            borderRadius: BorderRadius.circular(2))),
      AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        height: 4,
        width: c.maxWidth * value.clamp(0.0, 1.0),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2))),
    ]));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: _T.label(11,
            w: FontWeight.w700,
            c: onSurf.withOpacity(0.35)));
  }
}

class _HeaderBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});
  @override State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTapDown: (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(widget.icon,
                size: 20, color: onSurf.withOpacity(0.60)),
          ),
        ),
      ),
    );
  }
}

class _FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _FadeInSlide({required this.child, this.delay = Duration.zero});
  @override State<_FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<_FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<double>  _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset>  _slide = Tween<Offset>(
    begin: const Offset(0, 0.05), end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child));
}

class _InlineBtn extends StatefulWidget {
  final String label; final Color color;
  final bool impact; final VoidCallback onTap;
  const _InlineBtn({required this.label, required this.color,
      required this.onTap, this.impact = false});
  @override State<_InlineBtn> createState() => _InlineBtnState();
}

class _InlineBtnState extends State<_InlineBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        widget.impact ? HapticFeedback.mediumImpact()
                      : HapticFeedback.selectionClick();
      },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(widget.label,
                style: _T.label(15,
                    w: FontWeight.w600, c: widget.color))),
          ),
        ),
      ),
    );
  }
}