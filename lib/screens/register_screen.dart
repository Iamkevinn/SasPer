// lib/screens/register_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Registro — Apple-first redesign
//
// Eliminado:
// · _AnimatedGradientBackground + 3 _AnimatedBlob → fondo estático
// · BackdropFilter sigmaX:60 → eliminado
// · BoxShape.circle + LinearGradient teal en header icon → _LogoMark patrón
// · ShaderMask en subtítulo → texto simple opacity
// · _gradientController (10s) + _glowController (1500ms loop) → eliminados
// · flutter_animate delays 200ms…1400ms → fade único 320ms
// · _buildPersonalInfoSection + _buildSecuritySection cards con BoxShadow
//   → campos directos en pantalla con grupo iOS (rounded rect unificado)
// · AnimatedContainer Border glow en focus → mismo fix que login
// · .animate().scale(elasticOut) en tick de validación → fade sutil
// · TextDecoration.lineThrough en requisitos cumplidos → checkmark simple
// · _buildPasswordStrengthMeter con scale animation → barra estática animada
// · Stack multicapa en _buildLoadingIndicator → un spinner
// · AnimatedBuilder(glowAnimation) en botón → _PillBtn limpio
// · _buildSuccessScreen con LinearGradient + confetti → NotificationHelper + pop
// · _ConfettiPainter (5 puntos estáticos) → eliminado
// · "Paso 1 de 2" falso + barra de progreso gamificada → eliminados
// · Requisitos siempre visibles → solo al tener focus en campo contraseña
// · GoogleFonts.poppins → _T tokens DM Sans
// · Color(0xFF0D9488) teal × 12 → _kBlue paleta iOS
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:ui';

import 'package:sasper/data/auth_repository.dart';
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

  static TextStyle mono(double s,
          {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

const _kBlue  = Color(0xFF0A84FF);
const _kGreen = Color(0xFF30D158);
const _kRed   = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl   = TextEditingController();
  final _usernameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();

  final _fullNameFocus  = FocusNode();
  final _usernameFocus  = FocusNode();
  final _emailFocus     = FocusNode();
  final _passwordFocus  = FocusNode();
  final _confirmFocus   = FocusNode();

  bool _loading        = false;
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  // Focus state
  bool _fullNameFocused  = false;
  bool _usernameFocused  = false;
  bool _emailFocused     = false;
  bool _passwordFocused  = false;
  bool _confirmFocused   = false;

  // Validación contraseña en tiempo real
  bool _hasMinLength    = false;
  bool _hasUppercase    = false;
  bool _hasLowercase    = false;
  bool _hasSpecialChar  = false;

  // Fade-in único — sin escalonado agresivo
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();

    _passwordCtrl.addListener(_updatePasswordReqs);

    _fullNameFocus.addListener(()  =>
        setState(() => _fullNameFocused  = _fullNameFocus.hasFocus));
    _usernameFocus.addListener(()  =>
        setState(() => _usernameFocused  = _usernameFocus.hasFocus));
    _emailFocus.addListener(()     =>
        setState(() => _emailFocused     = _emailFocus.hasFocus));
    _passwordFocus.addListener(()  =>
        setState(() => _passwordFocused  = _passwordFocus.hasFocus));
    _confirmFocus.addListener(()   =>
        setState(() => _confirmFocused   = _confirmFocus.hasFocus));
  }

  void _updatePasswordReqs() {
    final p = _passwordCtrl.text;
    setState(() {
      _hasMinLength   = p.length >= 8;
      _hasUppercase   = p.contains(RegExp(r'[A-Z]'));
      _hasLowercase   = p.contains(RegExp(r'[a-z]'));
      _hasSpecialChar = p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  double get _passwordStrength {
    int s = 0;
    if (_hasMinLength)   s++;
    if (_hasUppercase)   s++;
    if (_hasLowercase)   s++;
    if (_hasSpecialChar) s++;
    return s / 4;
  }

  Color get _strengthColor {
    if (_passwordStrength >= 0.75) return _kGreen;
    if (_passwordStrength >= 0.50) return _kBlue;
    if (_passwordStrength >= 0.25) return _kOrange;
    return _kRed;
  }

  String get _strengthLabel {
    if (_passwordStrength >= 0.75) return 'Muy segura';
    if (_passwordStrength >= 0.50) return 'Segura';
    if (_passwordStrength >= 0.25) return 'Débil';
    return 'Muy débil';
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl
      ..removeListener(_updatePasswordReqs)
      ..dispose();
    _confirmCtrl.dispose();

    _fullNameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();

    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthRepository.instance.signUp(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        fullName: _fullNameCtrl.text.trim(),
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: '¡Cuenta creada! Revisa tu correo para confirmar.',
            type: NotificationType.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
            message: e.toString().replaceFirst('Exception: ', ''),
            type: NotificationType.error);
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final isDark  = theme.brightness == Brightness.dark;
    final size    = MediaQuery.of(context).size;
    final bottomP = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(children: [
            // ── Header blur sticky con back ──────────────────────────────
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: theme.scaffoldBackgroundColor.withOpacity(0.93),
                  padding: const EdgeInsets.only(
                      left: 8, right: 20, top: 6, bottom: 6),
                  child: Row(children: [
                    // Back — press state
                    _BackBtn(),
                    const SizedBox(width: 4),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('SASPER',
                            style: _T.label(10,
                                w: FontWeight.w700,
                                c: onSurf.withOpacity(0.35))),
                        Text('Crear cuenta',
                            style: _T.display(20, c: onSurf)),
                      ],
                    )),
                  ]),
                ),
              ),
            ),

            // ── Formulario ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left:   size.width > 600 ? size.width * 0.20 : 20,
                  right:  size.width > 600 ? size.width * 0.20 : 20,
                  top:    24,
                  bottom: bottomP > 0 ? bottomP + 16 : 40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Headline
                      Text('Empieza tu viaje\nfinanciero.',
                          style: _T.display(30, c: onSurf)),
                      const SizedBox(height: 8),
                      Text(
                        'Completa los campos para crear tu cuenta.',
                        style: _T.label(15,
                            c: onSurf.withOpacity(0.46),
                            w: FontWeight.w400),
                      ),
                      const SizedBox(height: 32),

                      // ── Grupo: Datos personales ──────────────────────
                      _GroupLabel('DATOS PERSONALES'),
                      const SizedBox(height: 8),
                      _FieldGroup(children: [
                        _InputField(
                          controller:      _fullNameCtrl,
                          focusNode:       _fullNameFocus,
                          label:           'Nombre completo',
                          hint:            'María González',
                          icon:            Iconsax.user_octagon,
                          hasFocus:        _fullNameFocused,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          enabled:         !_loading,
                          onEditingComplete: () =>
                              FocusScope.of(context)
                                  .requestFocus(_usernameFocus),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Nombre requerido' : null,
                        ),
                        _FieldDivider(),
                        _InputField(
                          controller:      _usernameCtrl,
                          focusNode:       _usernameFocus,
                          label:           'Nombre de usuario',
                          hint:            'sin espacios',
                          icon:            Iconsax.user,
                          hasFocus:        _usernameFocused,
                          textInputAction: TextInputAction.next,
                          enabled:         !_loading,
                          onEditingComplete: () =>
                              FocusScope.of(context)
                                  .requestFocus(_emailFocus),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Usuario requerido';
                            }
                            if (v.contains(' ')) return 'Sin espacios';
                            return null;
                          },
                        ),
                        _FieldDivider(),
                        _InputField(
                          controller:      _emailCtrl,
                          focusNode:       _emailFocus,
                          label:           'Correo electrónico',
                          hint:            'tu@email.com',
                          icon:            Iconsax.sms,
                          hasFocus:        _emailFocused,
                          keyboardType:    TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled:         !_loading,
                          onEditingComplete: () =>
                              FocusScope.of(context)
                                  .requestFocus(_passwordFocus),
                          validator: (v) =>
                              (v == null || !v.contains('@') || !v.contains('.'))
                                  ? 'Correo inválido' : null,
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // ── Grupo: Contraseña ────────────────────────────
                      _GroupLabel('SEGURIDAD'),
                      const SizedBox(height: 8),
                      _FieldGroup(children: [
                        _InputField(
                          controller:      _passwordCtrl,
                          focusNode:       _passwordFocus,
                          label:           'Contraseña',
                          hint:            'Mínimo 8 caracteres',
                          icon:            Iconsax.key,
                          hasFocus:        _passwordFocused,
                          obscureText:     _obscurePass,
                          textInputAction: TextInputAction.next,
                          enabled:         !_loading,
                          onEditingComplete: () =>
                              FocusScope.of(context)
                                  .requestFocus(_confirmFocus),
                          suffixIcon: GestureDetector(
                            onTap: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            child: Icon(
                              _obscurePass
                                  ? Iconsax.eye_slash : Iconsax.eye,
                              size: 17,
                              color: onSurf.withOpacity(0.40)),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Contraseña requerida';
                            }
                            if (!_hasMinLength || !_hasUppercase ||
                                !_hasLowercase || !_hasSpecialChar) {
                              return 'Cumple todos los requisitos';
                            }
                            return null;
                          },
                        ),
                        _FieldDivider(),
                        _InputField(
                          controller:      _confirmCtrl,
                          focusNode:       _confirmFocus,
                          label:           'Confirmar contraseña',
                          hint:            'Repite tu contraseña',
                          icon:            Iconsax.password_check,
                          hasFocus:        _confirmFocused,
                          obscureText:     _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          enabled:         !_loading,
                          onEditingComplete: _signUp,
                          suffixIcon: GestureDetector(
                            onTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            child: Icon(
                              _obscureConfirm
                                  ? Iconsax.eye_slash : Iconsax.eye,
                              size: 17,
                              color: onSurf.withOpacity(0.40)),
                          ),
                          validator: (v) =>
                              v != _passwordCtrl.text
                                  ? 'Las contraseñas no coinciden' : null,
                        ),
                      ]),

                      // ── Fortaleza + requisitos — solo si hay texto ───
                      if (_passwordCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _PasswordStrengthCard(
                          strength:     _passwordStrength,
                          color:        _strengthColor,
                          label:        _strengthLabel,
                          hasMinLength: _hasMinLength,
                          hasUppercase: _hasUppercase,
                          hasLowercase: _hasLowercase,
                          hasSpecial:   _hasSpecialChar,
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── Botón registrar ──────────────────────────────
                      _RegisterBtn(loading: _loading, onTap: _signUp),
                      const SizedBox(height: 20),

                      // ── Badge de seguridad ───────────────────────────
                      _SecurityBadge(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIELD GROUP — patrón iOS Settings/Apple ID
// ─────────────────────────────────────────────────────────────────────────────
// Todos los campos de un grupo dentro de un Container único con
// borderRadius compartido y separadores internos — como iOS Settings.
// Sin card por campo individual. Sin border individual por campo.

class _FieldGroup extends StatelessWidget {
  final List<Widget> children;
  const _FieldGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);

    return Container(
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// Separador interno del grupo — igual que iOS Settings
class _FieldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      // Indent izquierdo: 44px (icon) + 14px (padding) + 14px (gap) = 72px
      padding: const EdgeInsets.only(left: 44 + 28),
      child: Container(height: 0.5, color: onSurf.withOpacity(0.08)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT FIELD — dentro del FieldGroup (sin background propio)
// ─────────────────────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final IconData icon;
  final bool hasFocus;
  final bool obscureText, enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
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
    this.obscureText          = false,
    this.enabled              = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization   = TextCapitalization.none,
    this.onEditingComplete,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return TextFormField(
      controller:            controller,
      focusNode:             focusNode,
      keyboardType:          keyboardType,
      textInputAction:       textInputAction,
      textCapitalization:    textCapitalization,
      obscureText:           obscureText,
      enabled:               enabled,
      onEditingComplete:     onEditingComplete,
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
        border:              InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        errorStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kRed),
        errorBorder:        InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
      validator: validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PASSWORD STRENGTH CARD
// ─────────────────────────────────────────────────────────────────────────────
// Aparece solo cuando el usuario empieza a escribir la contraseña.
// Sin animación de entrada agresiva — fade sutil via AnimatedOpacity.
// Sin tachado en requisitos cumplidos — checkmark simple.
// Barra de fortaleza: 4px, un color, animación de ancho.

class _PasswordStrengthCard extends StatelessWidget {
  final double strength;
  final Color color;
  final String label;
  final bool hasMinLength, hasUppercase, hasLowercase, hasSpecial;

  const _PasswordStrengthCard({
    required this.strength,
    required this.color,
    required this.label,
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasSpecial,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra + label en la misma fila
            Row(children: [
              Expanded(child: _ProgressBar(
                  value: strength, color: color)),
              const SizedBox(width: 10),
              Text(label,
                  style: _T.label(11,
                      c: color, w: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),

            // Requisitos — grid 2×2 para compactar
            Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Expanded(child: Column(children: [
                _Req(label: '8+ caracteres',     met: hasMinLength),
                const SizedBox(height: 6),
                _Req(label: 'Minúscula (a-z)',   met: hasLowercase),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(children: [
                _Req(label: 'Mayúscula (A-Z)',   met: hasUppercase),
                const SizedBox(height: 6),
                _Req(label: 'Carácter especial', met: hasSpecial),
              ])),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Req extends StatelessWidget {
  final String label;
  final bool met;
  const _Req({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color  = met ? _kGreen : onSurf.withOpacity(0.35);

    return Row(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 14, height: 14,
        decoration: BoxDecoration(
          color: met ? _kGreen.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Icon(
            met ? Icons.check_rounded : Icons.remove_rounded,
            size: 10,
            color: color,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(child: Text(label,
          style: _T.label(11, c: color))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _RegisterBtn({required this.loading, required this.onTap});
  @override State<_RegisterBtn> createState() => _RegisterBtnState();
}

class _RegisterBtnState extends State<_RegisterBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.loading) {
          _c.forward(); HapticFeedback.mediumImpact();
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
                  : Text('Crear cuenta',
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
// COMPONENTES COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: _T.label(11,
            w: FontWeight.w700,
            c: onSurf.withOpacity(0.35)));
  }
}

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
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        height: 4,
        width: c.maxWidth * value.clamp(0.0, 1.0),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2))),
    ]));
  }
}

class _BackBtn extends StatefulWidget {
  @override State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn>
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
      onTapUp: (_) {
        _c.reverse(); Navigator.of(context).pop(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _kBlue),
          ),
        ),
      ),
    );
  }
}

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
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, 0.50, _c.value)!,
          child: Text(widget.label,
              style: _T.label(14, c: _kBlue, w: FontWeight.w600)),
        ),
      ),
    );
  }
}