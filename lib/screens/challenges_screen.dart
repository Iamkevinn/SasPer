// lib/screens/challenges_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Centro de Hábitos — Apple-first redesign
//
// Eliminado:
// · NestedScrollView + SliverAppBar expandedHeight:200 → header blur sticky
// · LinearGradient en summary card → opacity-based surface
// · Border.all(width:2) colorido → sin border
// · _buildSectionHeader con ícono + color → _SectionLabel uppercase
// · LinearProgressIndicator Material → barra iOS 4px borderRadius
// · LinearGradient en tarjetas activas/completadas → opacity surface
// · BoxShape.circle decorativo → borderRadius
// · FlexibleSpaceBar + Gradient background → eliminado
// · ScaffoldMessenger.showSnackBar → NotificationHelper
// · AlertDialog cancelar → _ConfirmCancelSheet blur
// · flutter_animate .slideX .scale → solo fade sutil
// · FilledButton.icon Material → _ActionBtn / _PillBtn con press state
// · GoogleFonts mezclados → _T tokens DM Sans
// · TabBar con indicatorWeight:3 → segmented control iOS
// · text-decoration: lineThrough en completados → opacity 0.45
// · Racha "suma total" → racha máxima del reto más activo
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

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

  static const double h = 20.0;
  static const double r = 18.0;
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kOrange = Color(0xFFFF9F0A);
const _kRed    = Color(0xFFFF453A);
const _kGrey   = Color(0xFF8E8E93);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});
  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with TickerProviderStateMixin {
  final _repo = ChallengeRepository.instance;

  // Segmented control — 0: Mis Retos, 1: Disponibles
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _repo.checkUserChallengesStatus().then((_) {
      if (mounted) setState(() {});
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(children: [
        // ── Header blur sticky ───────────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.93),
              padding: EdgeInsets.only(
                  top: statusH + 10, left: _T.h + 4,
                  right: _T.h, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SASPER',
                      style: _T.label(10, w: FontWeight.w700,
                          c: onSurf.withOpacity(0.35))),
                  Text('Hábitos',
                      style: _T.display(28, c: onSurf)),
                  const SizedBox(height: 12),
                  // Segmented control iOS
                  _SegmentedControl(
                    selected: _tab,
                    labels: const ['Mis Retos', 'Disponibles'],
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _tab = i);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Contenido ────────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _tab == 0
                ? _MyRetos(
                    key: const ValueKey('mine'),
                    repo: _repo,
                    onGoToAvailable: () =>
                        setState(() => _tab = 1),
                    onCancel: _confirmCancel,
                  )
                : _AvailableRetos(
                    key: const ValueKey('available'),
                    repo: _repo,
                    onAccept: _acceptChallenge,
                  ),
          ),
        ),
      ]),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _acceptChallenge(Challenge c) async {
    try {
      await _repo.startChallenge(c);
      if (!mounted) return;
      NotificationHelper.show(
          message: '¡Reto aceptado!',
          type: NotificationType.success);
      setState(() => _tab = 0);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
          message: 'Error al aceptar el reto',
          type: NotificationType.error);
    }
  }

  Future<void> _confirmCancel(UserChallenge uc) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmCancelSheet(
            challengeTitle: uc.challengeDetails.title),
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.cancelUserChallenge(uc.id);
      if (!mounted) return;
      NotificationHelper.show(
          message: 'Reto cancelado',
          type: NotificationType.info);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
          message: 'Error al cancelar',
          type: NotificationType.error);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 0 — MIS RETOS
// ─────────────────────────────────────────────────────────────────────────────

class _MyRetos extends StatelessWidget {
  final ChallengeRepository repo;
  final VoidCallback onGoToAvailable;
  final Future<void> Function(UserChallenge) onCancel;

  const _MyRetos({
    super.key,
    required this.repo,
    required this.onGoToAvailable,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserChallenge>>(
      stream: repo.getUserChallengesStream(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final all       = snap.data ?? [];
        final active    = all.where((c) => c.status == 'active').toList();
        final completed = all.where((c) => c.status == 'completed').toList();

        if (all.isEmpty) {
          return _EmptyMine(onGoToAvailable: onGoToAvailable);
        }

        return RefreshIndicator(
          onRefresh: () async {
            await repo.checkUserChallengesStatus();
          },
          child: ListView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(
                _T.h, 16, _T.h, 100),
            children: [
              // Resumen de racha — solo si hay retos con streak
              if (active.any((c) => c.challengeDetails.resetsDaily &&
                  c.currentStreak > 0)) ...[
                _StreakSummary(active: active),
                const SizedBox(height: 24),
              ],

              // Activos
              if (active.isNotEmpty) ...[
                _SectionLabel('EN PROGRESO'),
                const SizedBox(height: 10),
                ...active.asMap().entries.map((e) =>
                    _ActiveCard(
                      uc: e.value,
                      onCancel: () => onCancel(e.value),
                    )),
                const SizedBox(height: 24),
              ],

              // Completados
              if (completed.isNotEmpty) ...[
                _SectionLabel('COMPLETADOS'),
                const SizedBox(height: 10),
                ...completed.map((uc) => _CompletedCard(uc: uc)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Resumen de racha ──────────────────────────────────────────────────────────
// Muestra la racha del reto activo con mayor streak.
// No suma rachas — eso confunde al usuario.

class _StreakSummary extends StatelessWidget {
  final List<UserChallenge> active;
  const _StreakSummary({required this.active});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    // Reto con mayor racha activa
    final best = active
        .where((c) => c.challengeDetails.resetsDaily)
        .fold<UserChallenge?>(null, (prev, c) =>
            prev == null || c.currentStreak > prev.currentStreak ? c : prev);

    if (best == null) return const SizedBox.shrink();

    final streak = best.currentStreak;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Row(children: [
        // Emoji racha — sin contenedor decorativo
        Text('🔥', style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mejor racha activa',
                style: _T.label(12, c: onSurf.withOpacity(0.42))),
            const SizedBox(height: 2),
            Row(children: [
              Text('$streak',
                  style: _T.display(32,
                      c: _kOrange)),
              const SizedBox(width: 6),
              Text('días',
                  style: _T.label(16,
                      c: onSurf.withOpacity(0.50))),
            ]),
            const SizedBox(height: 2),
            Text(best.challengeDetails.title,
                style: _T.label(12,
                    c: onSurf.withOpacity(0.42))),
          ],
        )),
        // Indicador de retos activos totales
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${active.length}',
              style: _T.display(22, c: onSurf)),
          Text('activos',
              style: _T.label(11,
                  c: onSurf.withOpacity(0.38))),
        ]),
      ]),
    );
  }
}

// ── Tarjeta de reto activo ─────────────────────────────────────────────────────

class _ActiveCard extends StatefulWidget {
  final UserChallenge uc;
  final VoidCallback onCancel;
  const _ActiveCard({required this.uc, required this.onCancel});
  @override State<_ActiveCard> createState() => _ActiveCardState();
}

class _ActiveCardState extends State<_ActiveCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final bg        = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final uc        = widget.uc;
    final challenge = uc.challengeDetails;
    final daysLeft  = uc.endDate.difference(DateTime.now()).inDays;

    // Progreso: para retos de racha usa streak/duración,
    // para otros usa días transcurridos
    final rawProgress = challenge.resetsDaily
        ? uc.currentStreak / challenge.durationDays
        : (challenge.durationDays - daysLeft) / challenge.durationDays;
    final progress = rawProgress.clamp(0.0, 1.0);
    final isUrgent = daysLeft <= 7;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.scale(
        scale: lerpDouble(1.0, 0.985, _c.value)!,
        child: GestureDetector(
          onTapDown: (_) => _c.forward(),
          onTapUp:   (_) => _c.reverse(),
          onTapCancel: () => _c.reverse(),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(_T.r)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fila principal ─────────────────────────────────────
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Icon(Iconsax.flash_1,
                        color: _kBlue, size: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(challenge.title,
                          style: _T.label(14,
                              w: FontWeight.w700, c: onSurf)),
                      const SizedBox(height: 2),
                      Text(challenge.description,
                          style: _T.label(12,
                              c: onSurf.withOpacity(0.45),
                              w: FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  // Botón cancelar — icono sutil
                  _IconBtn(
                    icon: Iconsax.close_circle,
                    color: _kGrey,
                    onTap: widget.onCancel,
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Progreso o streak ──────────────────────────────────
                if (challenge.resetsDaily) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Racha actual',
                          style: _T.label(12,
                              c: onSurf.withOpacity(0.42))),
                      Row(children: [
                        Text('🔥',
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text('${uc.currentStreak} días',
                            style: _T.mono(15, c: _kOrange)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Progreso',
                          style: _T.label(12,
                              c: onSurf.withOpacity(0.42))),
                      Text('${(progress * 100).toStringAsFixed(0)}%',
                          style: _T.mono(14, c: _kBlue)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Barra de progreso iOS — 4px, borderRadius, sin Material
                _ProgressBar(
                  value: progress,
                  color: challenge.resetsDaily ? _kOrange : _kBlue,
                ),

                const SizedBox(height: 14),

                // ── Fila de fecha + días restantes ─────────────────────
                Row(children: [
                  Icon(Iconsax.calendar_1, size: 12,
                      color: onSurf.withOpacity(0.35)),
                  const SizedBox(width: 5),
                  Text(
                    'Finaliza el ${DateFormat("d MMM", "es_CO").format(uc.endDate)}',
                    style: _T.label(12,
                        c: onSurf.withOpacity(0.42))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isUrgent ? _kOrange : _kGreen)
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$daysLeft d',
                      style: _T.label(11,
                          c: isUrgent ? _kOrange : _kGreen,
                          w: FontWeight.w700)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de reto completado ────────────────────────────────────────────────
// En iOS los completados no tienen tachado — tienen opacity reducida.
// El checkmark verde comunica "hecho" sin ser ruidoso.

class _CompletedCard extends StatelessWidget {
  final UserChallenge uc;
  const _CompletedCard({required this.uc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.03);

    return Opacity(
      opacity: 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(_T.r)),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(child: Icon(Iconsax.verify5,
                color: _kGreen, size: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(uc.challengeDetails.title,
              style: _T.label(14,
                  w: FontWeight.w600, c: onSurf))),
          // Puntos ganados
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kOrange.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('+100 pts',
                style: _T.mono(11, c: _kOrange)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — DISPONIBLES
// ─────────────────────────────────────────────────────────────────────────────

class _AvailableRetos extends StatelessWidget {
  final ChallengeRepository repo;
  final Future<void> Function(Challenge) onAccept;

  const _AvailableRetos({
    super.key,
    required this.repo,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Challenge>>(
      future: repo.getAvailableChallenges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final challenges = snap.data ?? [];
        if (challenges.isEmpty) return const _EmptyAvailable();

        return ListView.builder(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(
              _T.h, 16, _T.h, 100),
          itemCount: challenges.length,
          itemBuilder: (_, i) => _AvailableCard(
            challenge: challenges[i],
            onAccept: () => onAccept(challenges[i]),
          ),
        );
      },
    );
  }
}

// ── Tarjeta disponible ────────────────────────────────────────────────────────

class _AvailableCard extends StatefulWidget {
  final Challenge challenge;
  final VoidCallback onAccept;
  const _AvailableCard({required this.challenge, required this.onAccept});
  @override State<_AvailableCard> createState() => _AvailableCardState();
}

class _AvailableCardState extends State<_AvailableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final bg        = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final challenge = widget.challenge;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(Iconsax.cup,
                  color: _kBlue, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(challenge.title,
                    style: _T.label(14,
                        w: FontWeight.w700, c: onSurf)),
                const SizedBox(height: 2),
                Text('${challenge.durationDays} días',
                    style: _T.label(12,
                        c: _kBlue, w: FontWeight.w600)),
              ],
            )),
            // Puntos — badge sutil
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _kOrange.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('+100',
                  style: _T.mono(12, c: _kOrange)),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Descripción ──────────────────────────────────────────────
          Text(challenge.description,
              style: _T.label(13,
                  c: onSurf.withOpacity(0.50),
                  w: FontWeight.w400)),

          const SizedBox(height: 14),

          // Divisor
          Container(height: 0.5, color: onSurf.withOpacity(0.07)),
          const SizedBox(height: 14),

          // ── Acción ───────────────────────────────────────────────────
          _ActionBtn(
            label: 'Aceptar reto',
            icon: Iconsax.add_circle,
            color: _kBlue,
            onTap: widget.onAccept,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMine extends StatelessWidget {
  final VoidCallback onGoToAvailable;
  const _EmptyMine({required this.onGoToAvailable});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏆', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text('Comienza tu viaje',
                style: _T.display(24, c: onSurf)),
            const SizedBox(height: 8),
            Text(
              'Acepta retos para desarrollar\nhábitos financieros saludables.',
              style: _T.label(14,
                  c: onSurf.withOpacity(0.45), w: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _PillBtn(
                label: 'Explorar retos',
                icon: Iconsax.cup,
                onTap: onGoToAvailable),
          ],
        ),
      ),
    );
  }
}

class _EmptyAvailable extends StatelessWidget {
  const _EmptyAvailable();

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✅', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text('Todo completado',
                style: _T.display(24, c: onSurf)),
            const SizedBox(height: 8),
            Text('No hay retos nuevos disponibles por ahora.',
                style: _T.label(14,
                    c: onSurf.withOpacity(0.45), w: FontWeight.w400),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET — CONFIRMAR CANCELACIÓN
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmCancelSheet extends StatelessWidget {
  final String challengeTitle;
  const _ConfirmCancelSheet({required this.challengeTitle});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: const Icon(Iconsax.close_circle,
                    color: _kRed, size: 24),
              ),
              const SizedBox(height: 12),
              Text('Cancelar reto',
                  style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text(
                '"$challengeTitle"\nTu progreso se perderá para siempre.',
                textAlign: TextAlign.center,
                style: _T.label(14,
                    c: onSurf.withOpacity(0.48),
                    w: FontWeight.w400)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _InlineBtn(
                    label: 'Continuar', color: onSurf,
                    onTap: () => Navigator.pop(context, false))),
                const SizedBox(width: 10),
                Expanded(child: _InlineBtn(
                    label: 'Cancelar', color: _kRed, impact: true,
                    onTap: () => Navigator.pop(context, true))),
              ]),
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

// Segmented control — reemplaza TabBar Material
class _SegmentedControl extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _SegmentedControl({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final trackBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final thumbBg = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.white;

    return Container(
      height: 36,
      decoration: BoxDecoration(
          color: trackBg, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(3),
      child: Row(children: [
        ...labels.indexed.map((e) {
          final (i, label) = e;
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: isSelected ? thumbBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Center(
                  child: Text(label,
                      style: _T.label(13,
                          w: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          c: isSelected
                              ? onSurf
                              : onSurf.withOpacity(0.45))),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }
}

// Barra de progreso iOS — sin Material, sin elevation
class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return LayoutBuilder(builder: (_, constraints) {
      return Container(
        height: 4,
        width: double.infinity,
        decoration: BoxDecoration(
          color: onSurf.withOpacity(0.08),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            width: constraints.maxWidth * value,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    });
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: _T.label(11, w: FontWeight.w700,
              c: onSurf.withOpacity(0.35))),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.onTap});
  @override State<_IconBtn> createState() => _IconBtnState();
}
class _IconBtnState extends State<_IconBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.80, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(widget.icon, size: 18,
                color: widget.color.withOpacity(0.60)),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label; final IconData icon;
  final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override State<_ActionBtn> createState() => _ActionBtnState();
}
class _ActionBtnState extends State<_ActionBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.95, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(isDark ? 0.14 : 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 15, color: widget.color),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: _T.label(13,
                      c: widget.color, w: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PillBtn extends StatefulWidget {
  final String label; final IconData? icon; final VoidCallback onTap;
  const _PillBtn({required this.label, required this.onTap, this.icon});
  @override State<_PillBtn> createState() => _PillBtnState();
}
class _PillBtnState extends State<_PillBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.mediumImpact(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: _kBlue,
                borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.icon != null) ...[
                Icon(widget.icon!, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: _T.label(16,
                      c: Colors.white, w: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
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
      onTapUp: (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
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