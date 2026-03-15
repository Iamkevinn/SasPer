// lib/screens/settings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Ajustes — Apple-first redesign
//
// Eliminado:
// • AppBar estándar → header blur sticky
// • BoxShadow en tarjetas → opacity-based surface sin sombra
// • InkWell + ripple Material → GestureDetector con press state escala
// • LinearGradient + BoxShadow en avatar → inicial simple
// • Dialog centrado para tema → bottom sheet iOS con blur
// • Dialog centrado para logout → _ConfirmLogoutSheet blur
// • GoogleFonts.poppins inline → _T.label / _T.display (DM Sans)
// • Color hex hardcoded mezclado con colorScheme → opacity-based puro
// • Border.all + outlineVariant → separación por tono
// • "Probar Notificación" en sección PERFIL → sección NOTIFICACIONES
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/screens/categories_screen.dart';
import 'package:sasper/screens/profile_screen.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/preferences_service.dart';
import 'package:sasper/services/theme_provider.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Tokens ──────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s,
          fontWeight: w,
          color: c,
          letterSpacing: -0.4,
          height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);

  static const double h = 20.0;
  static const double r = 18.0;
}

const _kBlue = Color(0xFF0A84FF);
const _kRed = Color(0xFFFF453A);
const _kGreen = Color(0xFF30D158);
const _kTeal = Color(0xFF40C8E0);

// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthRepository.instance;
  bool _biometric = true;
  bool _loadingBio = true;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final v = await PreferencesService.instance.isBiometricLockEnabled();
    if (mounted) {
      setState(() {
        _biometric = v;
        _loadingBio = false;
      });
    }
  }

  Future<void> _setBiometric(bool v) async {
    if (v) {
      final auth = LocalAuthentication();
      final ok =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!ok && mounted) {
        NotificationHelper.show(
          message: 'Tu dispositivo no es compatible con el bloqueo biométrico.',
          type: NotificationType.error,
        );
        return;
      }
    }
    await PreferencesService.instance.setBiometricLock(isEnabled: v);
    if (mounted) setState(() => _biometric = v);
    HapticFeedback.selectionClick();
  }

  void _openThemeSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ThemeSheet(
          current: Provider.of<ThemeProvider>(context, listen: false).themeMode,
          onSelect: (mode) => Provider.of<ThemeProvider>(context, listen: false)
              .setThemeMode(mode),
        ),
      ),
    );
  }

  void _openLogoutSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmLogoutSheet(onConfirm: () async {
          try {
            await _auth.signOut();
          } catch (e) {
            if (mounted) {
              NotificationHelper.show(
                  message: 'Error al cerrar sesión.',
                  type: NotificationType.error);
            }
          }
        }),
      ),
    );
  }

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
        ThemeMode.system => 'Automático',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;
    final tp = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(children: [
        // ── Header blur sticky ────────────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.93),
              padding: EdgeInsets.only(
                  top: statusH + 10, left: _T.h + 4, right: _T.h, bottom: 14),
              child: Row(children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('SASPER',
                        style: _T.label(10,
                            w: FontWeight.w700, c: onSurf.withOpacity(0.35))),
                    Text('Ajustes', style: _T.display(28, c: onSurf)),
                  ],
                ),
              ]),
            ),
          ),
        ),

        // ── Scroll ───────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(_T.h, 8, _T.h, 100),
            children: [
              _SectionLabel('CUENTA'),
              const SizedBox(height: 8),
              _Card(child: _ProfileRow(user: _user)),
              const SizedBox(height: 28),
              _SectionLabel('PERSONALIZACIÓN'),
              const SizedBox(height: 8),
              _Card(
                  child: Column(children: [
                _SettingsRow(
                  icon: Iconsax.award,
                  label: 'Mi Progreso',
                  sublabel: 'Nivel y logros',
                  color: _kBlue,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Iconsax.moon,
                  label: 'Apariencia',
                  sublabel: _themeLabel(tp.themeMode),
                  color: _kTeal,
                  onTap: _openThemeSheet,
                  trailing: Icon(Icons.chevron_right_rounded,
                      size: 18, color: onSurf.withOpacity(0.22)),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Iconsax.grid_3,
                  label: 'Categorías',
                  sublabel: 'Gestionar categorías',
                  color: _kGreen,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CategoriesScreen())),
                ),
              ])),
              const SizedBox(height: 28),
              _SectionLabel('SEGURIDAD'),
              const SizedBox(height: 8),
              _Card(
                  child: _loadingBio
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()))
                      : _BiometricRow(
                          enabled: _biometric, onChanged: _setBiometric)),
              const SizedBox(height: 28),
              _SectionLabel('NOTIFICACIONES'),
              const SizedBox(height: 8),
              _Card(
                  child: _SettingsRow(
                icon: Iconsax.notification,
                label: 'Probar notificación',
                sublabel: 'Recibirás una en 5 segundos',
                color: _kBlue,
                onTap: () async {
                  HapticFeedback.mediumImpact();

                  // Opcional: Avisar que está procesando
                  NotificationHelper.show(
                    message: 'Iniciando prueba...',
                    type: NotificationType
                        .success, // O el tipo que uses para info
                  );

                  try {
                    // Esperamos a que el servicio termine
                    await NotificationService.instance
                        .testImmediateNotification();

                    if (mounted) {
                      NotificationHelper.show(
                        message: 'Notificación programada (espera 5s)',
                        type: NotificationType.success,
                      );
                    }
                  } catch (e) {
                    // Si el usuario deniega el permiso o hay error, lo capturamos aquí
                    if (mounted) {
                      // Limpiamos el texto del error para que se vea más amigable
                      final errorMsg =
                          e.toString().replaceAll('Exception: ', '');
                      NotificationHelper.show(
                        message: errorMsg,
                        type: NotificationType.error,
                      );
                    }
                  }
                },
              )),
              const SizedBox(height: 28),
              _Card(
                  child: _SettingsRow(
                icon: Iconsax.logout,
                label: 'Cerrar Sesión',
                color: _kRed,
                labelColor: _kRed,
                showChevron: false,
                onTap: _openLogoutSheet,
              )),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: _T.label(11, w: FontWeight.w700, c: onSurf.withOpacity(0.35))),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(_T.r)),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(left: 58),
      child: Container(height: 0.5, color: onSurf.withOpacity(0.08)),
    );
  }
}

// ── Fila de perfil ────────────────────────────────────────────────────────────
class _ProfileRow extends StatelessWidget {
  final User? user;
  const _ProfileRow({required this.user});
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final email = user?.email ?? 'No autenticado';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        // Avatar — inicial simple, sin gradiente ni sombra coloreada
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _kBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(child: Text(initial, style: _T.display(22, c: _kBlue))),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesión iniciada',
                style: _T.label(11, c: onSurf.withOpacity(0.40))),
            const SizedBox(height: 3),
            Text(email,
                style: _T.label(14, w: FontWeight.w600, c: onSurf),
                overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    );
  }
}

// ── Fila de ajuste con press state iOS ───────────────────────────────────────
class _SettingsRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color color;
  final Color? labelColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.sublabel,
    this.labelColor,
    this.trailing,
    this.showChevron = true,
  });
  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _c.reverse();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.985, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Icon(widget.icon, size: 17, color: widget.color)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: _T.label(14,
                          w: FontWeight.w600, c: widget.labelColor ?? onSurf)),
                  if (widget.sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.sublabel!,
                        style: _T.label(12, c: onSurf.withOpacity(0.42))),
                  ],
                ],
              )),
              widget.trailing ??
                  (widget.showChevron
                      ? Icon(Icons.chevron_right_rounded,
                          size: 18, color: onSurf.withOpacity(0.22))
                      : const SizedBox()),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Fila biométrico ───────────────────────────────────────────────────────────
class _BiometricRow extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _BiometricRow({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _kBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Center(child: Icon(Iconsax.finger_scan, size: 17, color: _kBlue)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bloqueo biométrico',
                style: _T.label(14, w: FontWeight.w600, c: onSurf)),
            const SizedBox(height: 2),
            Text('Huella o PIN al abrir',
                style: _T.label(12, c: onSurf.withOpacity(0.42))),
          ],
        )),
        _IOSSwitch(value: enabled, onChanged: onChanged),
      ]),
    );
  }
}

// ── Switch iOS ────────────────────────────────────────────────────────────────
class _IOSSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _IOSSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: value ? 1.0 : 0.0, end: value ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        builder: (_, v, __) => Container(
          width: 50,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Color.lerp(Colors.grey.withOpacity(0.30), _kGreen, v),
          ),
          padding: const EdgeInsets.all(2),
          child: Align(
            alignment:
                Alignment.lerp(Alignment.centerLeft, Alignment.centerRight, v)!,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeSheet extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;
  const _ThemeSheet({required this.current, required this.onSelect});

  static const _opts = <ThemeMode, (String, IconData)>{
    ThemeMode.light: ('Claro', Iconsax.sun_1),
    ThemeMode.dark: ('Oscuro', Iconsax.moon),
    ThemeMode.system: ('Automático', Iconsax.monitor),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final entries = _opts.entries.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: onSurf.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2))),
          Text('Apariencia',
              style: _T.label(13,
                  c: onSurf.withOpacity(0.42), w: FontWeight.w400)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: sheetBg, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              for (var i = 0; i < entries.length; i++) ...[
                _ThemeRow(
                  label: entries[i].value.$1,
                  icon: entries[i].value.$2,
                  selected: current == entries[i].key,
                  isFirst: i == 0,
                  isLast: i == entries.length - 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onSelect(entries[i].key);
                    Navigator.pop(context);
                  },
                ),
              ],
            ]),
          ),
          const SizedBox(height: 10),
          _CancelRow(),
        ]),
      ),
    );
  }
}

class _ThemeRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected, isFirst, isLast;
  final VoidCallback onTap;
  const _ThemeRow(
      {required this.label,
      required this.icon,
      required this.onTap,
      required this.selected,
      required this.isFirst,
      required this.isLast});
  @override
  State<_ThemeRow> createState() => _ThemeRowState();
}

class _ThemeRowState extends State<_ThemeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final topR = widget.isFirst ? const Radius.circular(16) : Radius.zero;
    final botR = widget.isLast ? const Radius.circular(16) : Radius.zero;
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: _c.value > 0.01
                ? onSurf.withOpacity(0.04 * _c.value)
                : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: topR,
              topRight: topR,
              bottomLeft: botR,
              bottomRight: botR,
            ),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(children: [
                Icon(widget.icon, size: 18, color: onSurf.withOpacity(0.55)),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(widget.label, style: _T.label(15, c: onSurf))),
                if (widget.selected)
                  Icon(Icons.check_rounded, size: 18, color: _kBlue),
              ]),
            ),
            if (!widget.isLast)
              Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child:
                      Container(height: 0.5, color: onSurf.withOpacity(0.07))),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM LOGOUT SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmLogoutSheet extends StatelessWidget {
  final Future<void> Function() onConfirm;
  const _ConfirmLogoutSheet({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: onSurf.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2))),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: sheetBg, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Iconsax.logout, color: _kRed, size: 24),
              ),
              const SizedBox(height: 12),
              Text('Cerrar sesión', style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text('¿Seguro que quieres cerrar tu sesión?',
                  textAlign: TextAlign.center,
                  style: _T.label(14,
                      c: onSurf.withOpacity(0.48), w: FontWeight.w400)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                    child: _InlineBtn(
                        label: 'Cancelar',
                        color: onSurf,
                        onTap: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(
                    child: _InlineBtn(
                        label: 'Cerrar sesión',
                        color: _kRed,
                        impact: true,
                        onTap: () async {
                          Navigator.pop(context);
                          await onConfirm();
                        })),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InlineBtn extends StatefulWidget {
  final String label;
  final Color color;
  final bool impact;
  final VoidCallback onTap;
  const _InlineBtn(
      {required this.label,
      required this.color,
      required this.onTap,
      this.impact = false});
  @override
  State<_InlineBtn> createState() => _InlineBtnState();
}

class _InlineBtnState extends State<_InlineBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        widget.impact
            ? HapticFeedback.mediumImpact()
            : HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
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
            child: Center(
                child: Text(widget.label,
                    style: _T.label(15, w: FontWeight.w600, c: widget.color))),
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatefulWidget {
  @override
  State<_CancelRow> createState() => _CancelRowState();
}

class _CancelRowState extends State<_CancelRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        Navigator.pop(context);
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(16)),
            child: Center(
                child: Text('Cancelar',
                    style: _T.label(16, w: FontWeight.w600, c: _kBlue))),
          ),
        ),
      ),
    );
  }
}
