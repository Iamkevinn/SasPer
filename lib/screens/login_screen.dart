// lib/screens/login_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Login — Apple-first redesign
//
// Eliminado:
// · _AnimatedGradientBackground (Color.lerp 8s sobre grises) → fondo estático
// · _AnimatedBlob × 2 (círculos pulsantes) → eliminados completamente
// · BackdropFilter sigmaX:60 sobre fondo estático → innecesario
// · Lottie.asset 140×140 + RadialGradient glow → logotipo tipográfico
// · Hero(tag:'app_logo') sin pantalla destino → eliminado
// · ShaderMask LinearGradient en subtítulo y en link de registro → _kBlue simple
// · _buildFormCard con Border.all + BoxShadow(blur:40) → campos directos
// · AnimatedContainer Border.all width:1→2 + glow en focus → underline sutil
// · flutter_animate delays 200ms…1200ms escalonados → fade único <250ms
// · LinearGradient teal + BoxShadow(blur:20) en botón → _PillBtn limpio
// · Stack de 5 capas para loading → un solo spinner
// · TextButton Material → GestureDetector con press state
// · Color(0xFF0D9488) teal hardcodeado × 8 → _kBlue paleta iOS
// · letterSpacing:0.5 y Icon flecha en botón → eliminados
// · GoogleFonts.poppins por todas partes → _T tokens DM Sans
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:ui';

import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/screens/register_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Tokens ─────────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s, fontWeight: w, color: c,
          letterSpacing: -0.5, height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF0A84FF);
const _kRed  = Color(0xFFFF453A);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  final _emailFocus   = FocusNode();
  final _passFocus    = FocusNode();

  bool _loading      = false;
  bool _obscure      = true;
  bool _emailFocused = false;
  bool _passFocused  = false;

  // Fade-in único para toda la pantalla — sin escalonado agresivo
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();

    _emailFocus.addListener(() =>
        setState(() => _emailFocused = _emailFocus.hasFocus));
    _passFocus.addListener(() =>
        setState(() => _passFocused = _passFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthRepository.instance.signInWithPassword(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      // AuthGate maneja la navegación automáticamente
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
            message: e.toString(),
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurf = theme.colorScheme.onSurface;
    final size   = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      // Fondo estático — calidad a través de tipografía y espaciado
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left:   size.width > 600 ? size.width * 0.20 : 28,
              right:  size.width > 600 ? size.width * 0.20 : 28,
              top:    40,
              bottom: bottomPad > 0 ? bottomPad + 16 : 40,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logotipo tipográfico ─────────────────────────────
                  _LogoMark(),
                  const SizedBox(height: 36),

                  // ── Headline ─────────────────────────────────────────
                  Text('Bienvenido\nde vuelta.',
                      style: _T.display(36, c: onSurf)),
                  const SizedBox(height: 10),
                  Text(
                    'Inicia sesión para continuar\ncon tu progreso financiero.',
                    style: _T.label(16,
                        c: onSurf.withOpacity(0.46),
                        w: FontWeight.w400),
                  ),
                  const SizedBox(height: 44),

                  // ── Campos de texto ──────────────────────────────────
                  _InputField(
                    controller: _emailCtrl,
                    focusNode:  _emailFocus,
                    label:      'Correo electrónico',
                    hint:       'tu@email.com',
                    icon:       Iconsax.sms,
                    hasFocus:   _emailFocused,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled:    !_loading,
                    onEditingComplete: () =>
                        FocusScope.of(context).requestFocus(_passFocus),
                    validator: (v) {
                      if (v == null || !v.contains('@') || !v.contains('.')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  _InputField(
                    controller: _passwordCtrl,
                    focusNode:  _passFocus,
                    label:      'Contraseña',
                    hint:       'Mínimo 6 caracteres',
                    icon:       Iconsax.key,
                    hasFocus:   _passFocused,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    enabled:    !_loading,
                    onEditingComplete: _signIn,
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure ? Iconsax.eye_slash : Iconsax.eye,
                        size: 18,
                        color: onSurf.withOpacity(0.40)),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Mínimo 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Olvidé mi contraseña ─────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: _TextLink(
                      label: '¿Olvidaste tu contraseña?',
                      onTap: () => NotificationHelper.show(
                          message: 'Función disponible próximamente',
                          type: NotificationType.info),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Botón de login ───────────────────────────────────
                  _LoginBtn(
                    loading: _loading,
                    onTap:   _signIn,
                  ),
                  const SizedBox(height: 28),

                  // ── Ir a registro ────────────────────────────────────
                  _RegisterRow(loading: _loading),
                  const SizedBox(height: 28),

                  // ── Indicador de seguridad ───────────────────────────
                  _SecurityBadge(),
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
// LOGOTIPO TIPOGRÁFICO
// ─────────────────────────────────────────────────────────────────────────────
// Sin Lottie, sin glow, sin Hero. El nombre de la app en DM Sans bold
// con un punto azul como acento — minimal, reconocible, iOS.

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _kBlue.withOpacity(0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Center(
          child: Icon(Iconsax.chart_2, size: 22, color: _kBlue),
        ),
      ),
      const SizedBox(width: 12),
      Text('SasPer',
          style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: onSurf,
              letterSpacing: -0.5)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT FIELD — iOS style
// ─────────────────────────────────────────────────────────────────────────────
// Sin border card. Sin glow azul al focus. Sin border que cambia de grosor.
// Un Container con fondo opacity-based + acento de color en el label al focus.
// Exactamente como funciona en apps iOS nativas (Notes, Reminders login).

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final bool hasFocus;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.hasFocus,
    this.obscureText   = false,
    this.enabled       = true,
    this.keyboardType,
    this.textInputAction,
    this.onEditingComplete,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        // Focus: un borde de 1.5px en _kBlue — sutil, no invasivo
        border: hasFocus
            ? Border.all(color: _kBlue.withOpacity(0.60), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: TextFormField(
        controller:          controller,
        focusNode:           focusNode,
        keyboardType:        keyboardType,
        textInputAction:     textInputAction,
        obscureText:         obscureText,
        enabled:             enabled,
        onEditingComplete:   onEditingComplete,
        style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: onSurf),
        decoration: InputDecoration(
          labelText:  label,
          hintText:   hint,
          labelStyle: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: hasFocus
                  ? _kBlue
                  : onSurf.withOpacity(0.42)),
          hintStyle: GoogleFonts.dmSans(
              fontSize: 14,
              color: onSurf.withOpacity(0.25)),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon,
                size: 17,
                color: hasFocus
                    ? _kBlue.withOpacity(0.80)
                    : onSurf.withOpacity(0.35)),
          ),
          prefixIconConstraints: const BoxConstraints(
              minWidth: 44, minHeight: 44),
          suffixIcon: suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: suffixIcon)
              : null,
          suffixIconConstraints: const BoxConstraints(
              minWidth: 40, minHeight: 40),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          errorStyle: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kRed),
          errorBorder:         InputBorder.none,
          focusedErrorBorder:  InputBorder.none,
        ),
        validator: validator,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN BUTTON
// ─────────────────────────────────────────────────────────────────────────────
// Sin gradiente. Sin BoxShadow grande. Sin Material + InkWell.
// _PillBtn con press state — exactamente como el resto de la app.

class _LoginBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoginBtn({required this.loading, required this.onTap});
  @override State<_LoginBtn> createState() => _LoginBtnState();
}

class _LoginBtnState extends State<_LoginBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.loading) {
          _c.forward();
          HapticFeedback.mediumImpact();
        }
      },
      onTapUp:     (_) { _c.reverse(); if (!widget.loading) widget.onTap(); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              // Color sólido — sin gradiente
              color: widget.loading
                  ? _kBlue.withOpacity(0.55)
                  : _kBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white))
                  : Text('Iniciar sesión',
                      style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER ROW
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterRow extends StatelessWidget {
  final bool loading;
  const _RegisterRow({required this.loading});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('¿No tienes cuenta?  ',
            style: _T.label(14,
                c: onSurf.withOpacity(0.46),
                w: FontWeight.w400)),
        _TextLink(
          label: 'Crear cuenta',
          onTap: loading ? () {} : () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const RegisterScreen(),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration:
                    const Duration(milliseconds: 260),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Iconsax.shield_tick,
            size: 13, color: onSurf.withOpacity(0.28)),
        const SizedBox(width: 6),
        Text('Conexión segura encriptada',
            style: _T.label(12,
                c: onSurf.withOpacity(0.28),
                w: FontWeight.w400)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT LINK — reemplaza TextButton Material
// ─────────────────────────────────────────────────────────────────────────────

class _TextLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _TextLink({required this.label, required this.onTap});
  @override State<_TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<_TextLink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          // Links usan fade en lugar de scale — más sutil
          opacity: lerpDouble(1.0, 0.50, _c.value)!,
          child: Text(widget.label,
              style: _T.label(14,
                  c: _kBlue, w: FontWeight.w600)),
        ),
      ),
    );
  }
}