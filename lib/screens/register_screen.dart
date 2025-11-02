// lib/screens/register_screen.dart
// VERSIÓN PREMIUM ELITE - Onboarding aspiracional con gamificación

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();

  final _fullNameFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;
  bool _showSuccessAnimation = false;

  // Validación en tiempo real
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasSpecialChar = false;
  bool _fullNameValid = false;
  bool _usernameValid = false;
  bool _emailValid = false;

  // Focus states
  bool _fullNameHasFocus = false;
  bool _usernameHasFocus = false;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;
  bool _confirmPasswordHasFocus = false;

  // Progreso del formulario (0-100)
  double _formProgress = 0.0;

  final AuthRepository _authRepository = AuthRepository.instance;

  late AnimationController _gradientController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _passwordController.addListener(_updatePasswordRequirements);
    _fullNameController.addListener(_updateFormProgress);
    _usernameController.addListener(_updateFormProgress);
    _emailController.addListener(_updateFormProgress);
    _confirmPasswordController.addListener(_updateFormProgress);

    // Focus listeners
    _fullNameFocusNode.addListener(() {
      setState(() => _fullNameHasFocus = _fullNameFocusNode.hasFocus);
    });
    _usernameFocusNode.addListener(() {
      setState(() => _usernameHasFocus = _usernameFocusNode.hasFocus);
    });
    _emailFocusNode.addListener(() {
      setState(() => _emailHasFocus = _emailFocusNode.hasFocus);
    });
    _passwordFocusNode.addListener(() {
      setState(() => _passwordHasFocus = _passwordFocusNode.hasFocus);
    });
    _confirmPasswordFocusNode.addListener(() {
      setState(() => _confirmPasswordHasFocus = _confirmPasswordFocusNode.hasFocus);
    });

    // Animación de gradiente de fondo
    _gradientController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    // Animación de glow para botón
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  void _updatePasswordRequirements() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
    _updateFormProgress();
  }

  void _updateFormProgress() {
    int totalSteps = 0;
    int completedSteps = 0;

    // Nombre completo
    if (_fullNameController.text.isNotEmpty) {
      totalSteps++;
      _fullNameValid = _fullNameController.text.length >= 3;
      if (_fullNameValid) completedSteps++;
    } else {
      totalSteps++;
      _fullNameValid = false;
    }

    // Username
    if (_usernameController.text.isNotEmpty) {
      totalSteps++;
      _usernameValid = _usernameController.text.length >= 3 && 
                       !_usernameController.text.contains(' ');
      if (_usernameValid) completedSteps++;
    } else {
      totalSteps++;
      _usernameValid = false;
    }

    // Email
    if (_emailController.text.isNotEmpty) {
      totalSteps++;
      _emailValid = _emailController.text.contains('@') && 
                    _emailController.text.contains('.');
      if (_emailValid) completedSteps++;
    } else {
      totalSteps++;
      _emailValid = false;
    }

    // Password
    totalSteps += 4;
    if (_hasMinLength) completedSteps++;
    if (_hasUppercase) completedSteps++;
    if (_hasLowercase) completedSteps++;
    if (_hasSpecialChar) completedSteps++;

    // Confirm password
    if (_confirmPasswordController.text.isNotEmpty) {
      totalSteps++;
      if (_confirmPasswordController.text == _passwordController.text) {
        completedSteps++;
      }
    } else {
      totalSteps++;
    }

    setState(() {
      _formProgress = (completedSteps / totalSteps * 100).clamp(0, 100);
    });
  }

  double _getPasswordStrength() {
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasUppercase) strength++;
    if (_hasLowercase) strength++;
    if (_hasSpecialChar) strength++;
    return strength / 4;
  }

  Color _getPasswordStrengthColor() {
    final strength = _getPasswordStrength();
    if (strength >= 0.75) return Colors.green;
    if (strength >= 0.5) return Colors.blue;
    if (strength >= 0.25) return Colors.orange;
    return Colors.red;
  }

  String _getPasswordStrengthLabel() {
    final strength = _getPasswordStrength();
    if (strength >= 0.75) return 'Muy Segura';
    if (strength >= 0.5) return 'Segura';
    if (strength >= 0.25) return 'Débil';
    return 'Muy Débil';
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authRepository.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _showSuccessAnimation = true;
        });

        // Mostrar animación de éxito y luego navegar
        await Future.delayed(const Duration(milliseconds: 2000));

        if (mounted) {
          NotificationHelper.show(
            message: '¡Cuenta creada! Revisa tu correo para confirmar.',
            type: NotificationType.success,
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          message: e.toString().replaceFirst("Exception: ", ""),
          type: NotificationType.error,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.removeListener(_updatePasswordRequirements);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();

    _fullNameFocusNode.dispose();
    _usernameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    _gradientController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    if (_showSuccessAnimation) {
      return _buildSuccessScreen(colorScheme);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Fondo animado
          _AnimatedGradientBackground(
            controller: _gradientController,
            isDark: isDark,
          ),

          // Glassmorphism overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surface.withOpacity(0.7),
                      colorScheme.surface.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Contenido
          SafeArea(
            child: Column(
              children: [
                // Header con progreso
                _buildHeader(colorScheme),

                // Formulario scrollable
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width > 600 ? size.width * 0.25 : 24.0,
                      vertical: 24.0,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Título y subtítulo aspiracional
                          _buildAspiratinalHeader(colorScheme),

                          const SizedBox(height: 32),

                          // Sección de datos personales
                          _buildPersonalInfoSection(colorScheme, isDark),

                          const SizedBox(height: 24),

                          // Sección de seguridad
                          _buildSecuritySection(colorScheme, isDark),

                          const SizedBox(height: 32),

                          // Botón de registro
                          _buildRegisterButton(colorScheme, isDark),

                          const SizedBox(height: 20),

                          // Indicador de seguridad
                          _buildSecurityIndicator(colorScheme),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Iconsax.arrow_left_2),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Paso 1 de 2',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formProgress.toInt()}% completado',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _formProgress / 100,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF0D9488),
              ),
            ),
          )
              .animate()
              .shimmer(
                duration: 2000.ms,
                color: Colors.white.withOpacity(0.3),
              ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.2, curve: Curves.easeOut);
  }

  Widget _buildAspiratinalHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        // Logo o icono
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Iconsax.user_add,
            color: Colors.white,
            size: 36,
          ),
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 600.ms)
            .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut),

        const SizedBox(height: 24),

        Text(
          'Crea tu cuenta y toma el control\nde tu futuro financiero',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 500.ms)
            .slideY(begin: 0.3, curve: Curves.easeOutCubic),

        const SizedBox(height: 12),

        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
          ).createShader(bounds),
          child: Text(
            'Tu nueva vida financiera comienza con un solo paso',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 500.ms)
            .slideY(begin: 0.3, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildPersonalInfoSection(ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.4)
            : colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.profile_circle,
                color: const Color(0xFF0D9488),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Información Personal',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildPremiumTextField(
            controller: _fullNameController,
            focusNode: _fullNameFocusNode,
            label: 'Nombre Completo',
            hint: 'Ej: María González',
            icon: Iconsax.user_octagon,
            isValid: _fullNameValid,
            hasFocus: _fullNameHasFocus,
            colorScheme: colorScheme,
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Nombre requerido' : null,
          ),

          const SizedBox(height: 16),

          _buildPremiumTextField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            label: 'Nombre de Usuario',
            hint: 'sin espacios',
            icon: Iconsax.user,
            isValid: _usernameValid,
            hasFocus: _usernameHasFocus,
            colorScheme: colorScheme,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Usuario requerido';
              if (value.contains(' ')) return 'Sin espacios';
              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildPremiumTextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            label: 'Correo Electrónico',
            hint: 'tu@email.com',
            icon: Iconsax.sms,
            isValid: _emailValid,
            hasFocus: _emailHasFocus,
            colorScheme: colorScheme,
            keyboardType: TextInputType.emailAddress,
            validator: (value) => (value == null ||
                    !value.contains('@') ||
                    !value.contains('.'))
                ? 'Email inválido'
                : null,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 500.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildSecuritySection(ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.4)
            : colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.shield_tick,
                color: const Color(0xFF0D9488),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Seguridad de Cuenta',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildPremiumTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            label: 'Contraseña',
            hint: 'Mínimo 8 caracteres',
            icon: Iconsax.key,
            hasFocus: _passwordHasFocus,
            colorScheme: colorScheme,
            obscureText: _isPasswordObscured,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordObscured ? Iconsax.eye_slash : Iconsax.eye,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () {
                setState(() => _isPasswordObscured = !_isPasswordObscured);
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Contraseña requerida';
              if (!_hasMinLength ||
                  !_hasUppercase ||
                  !_hasLowercase ||
                  !_hasSpecialChar) {
                return 'Cumple todos los requisitos';
              }
              return null;
            },
          ),

          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPasswordStrengthMeter(colorScheme),
          ],

          const SizedBox(height: 20),

          _buildPasswordRequirements(colorScheme),

          const SizedBox(height: 20),

          _buildPremiumTextField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            label: 'Confirmar Contraseña',
            hint: 'Repite tu contraseña',
            icon: Iconsax.password_check,
            hasFocus: _confirmPasswordHasFocus,
            colorScheme: colorScheme,
            obscureText: _isConfirmPasswordObscured,
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordObscured ? Iconsax.eye_slash : Iconsax.eye,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () {
                setState(() =>
                    _isConfirmPasswordObscured = !_isConfirmPasswordObscured);
              },
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 500.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildPasswordStrengthMeter(ColorScheme colorScheme) {
    final strength = _getPasswordStrength();
    final color = _getPasswordStrengthColor();
    final label = _getPasswordStrengthLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fortaleza de contraseña',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: strength,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .scale(begin: const Offset(0.8, 1.0), curve: Curves.easeOut),
      ],
    );
  }

  Widget _buildPasswordRequirements(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu contraseña debe contener:',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _PasswordRequirement(
            label: 'Mínimo 8 caracteres',
            isValid: _hasMinLength,
          ),
          _PasswordRequirement(
            label: 'Una letra mayúscula (A-Z)',
            isValid: _hasUppercase,
          ),
          _PasswordRequirement(
            label: 'Una letra minúscula (a-z)',
            isValid: _hasLowercase,
          ),
          _PasswordRequirement(
            label: 'Un carácter especial (!@#\$...)',
            isValid: _hasSpecialChar,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms)
        .slideX(begin: -0.1, curve: Curves.easeOut);
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool hasFocus,
    required ColorScheme colorScheme,
    bool isValid = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFocus
              ? const Color(0xFF0D9488)
              : colorScheme.outline.withOpacity(0.2),
          width: hasFocus ? 2 : 1,
        ),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: const Color(0xFF0D9488).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        enabled: !_isLoading,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: hasFocus
                ? const Color(0xFF0D9488)
                : colorScheme.onSurfaceVariant,
          ),
          hintStyle: GoogleFonts.poppins(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          prefixIcon: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              icon,
              color: hasFocus
                  ? const Color(0xFF0D9488)
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          suffixIcon: isValid && !hasFocus
              ? Icon(
                  Iconsax.tick_circle,
                  color: Colors.green,
                  size: 20,
                )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut)
              : suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          errorStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.error,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildRegisterButton(ColorScheme colorScheme, bool isDark) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(_glowAnimation.value * 0.5),
                blurRadius: 30,
                spreadRadius: _glowAnimation.value * 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _signUp,
              borderRadius: BorderRadius.circular(20),
              child: Center(
                child: _isLoading
                    ? _buildLoadingIndicator()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Iconsax.user_add,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Completar Registro',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    )
        .animate()
        .fadeIn(delay: 1200.ms, duration: 500.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic)
        .then()
        .shimmer(
          delay: 2000.ms,
          duration: 2000.ms,
          color: Colors.white.withOpacity(0.3),
        );
  }

  Widget _buildLoadingIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Barra de progreso horizontal
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.3),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.5)),
          ),
        ),
        // Texto de carga
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Creando tu cuenta...',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityIndicator(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Iconsax.security_safe,
          size: 16,
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          'Protegido con seguridad bancaria y cifrado avanzado',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 1400.ms, duration: 500.ms);
  }

  Widget _buildSuccessScreen(ColorScheme colorScheme) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D9488),
              const Color(0xFF14B8A6),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animación de éxito
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Iconsax.tick_circle5,
                      color: Color(0xFF0D9488),
                      size: 80,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1000.ms, color: Colors.white.withOpacity(0.5)),

              const SizedBox(height: 40),

              Text(
                '¡Cuenta Creada!',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 500.ms)
                  .slideY(begin: 0.3),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48.0),
                child: Text(
                  'Tu viaje hacia la libertad financiera\ncomienza ahora',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 500.ms)
                    .slideY(begin: 0.3),
              ),

              const SizedBox(height: 24),

              // Partículas de celebración sutiles
              SizedBox(
                width: 300,
                height: 100,
                child: CustomPaint(
                  painter: _ConfettiPainter(),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .fadeIn(duration: 1000.ms)
                  .then()
                  .shimmer(duration: 2000.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PASSWORD REQUIREMENT WIDGET CON ANIMACIÓN
// ============================================================================

class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool isValid;

  const _PasswordRequirement({
    required this.label,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    final successColor = Colors.green.shade600;
    final defaultColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        begin: defaultColor,
        end: isValid ? successColor : defaultColor,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, color, child) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isValid
                      ? successColor.withOpacity(0.2)
                      : defaultColor.withOpacity(0.1),
                  border: Border.all(
                    color: color!,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isValid ? Iconsax.tick_circle5 : Iconsax.close_circle,
                    color: color,
                    size: 12,
                  ),
                ),
              )
                  .animate(target: isValid ? 1 : 0)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isValid ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                    decoration: isValid ? TextDecoration.lineThrough : null,
                    decorationColor: color.withOpacity(0.5),
                    decorationThickness: 2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// FONDO ANIMADO CON GRADIENTE
// ============================================================================

class _AnimatedGradientBackground extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;

  const _AnimatedGradientBackground({
    required this.controller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Color.lerp(
                        const Color(0xFF0F172A),
                        const Color(0xFF1E293B),
                        controller.value,
                      )!,
                      Color.lerp(
                        const Color(0xFF1E293B),
                        const Color(0xFF0F172A),
                        controller.value,
                      )!,
                    ]
                  : [
                      Color.lerp(
                        const Color(0xFFF8FAFC),
                        const Color(0xFFE2E8F0),
                        controller.value,
                      )!,
                      Color.lerp(
                        const Color(0xFFE2E8F0),
                        const Color(0xFFF8FAFC),
                        controller.value,
                      )!,
                    ],
            ),
          ),
          child: Stack(
            children: [
              // Círculos decorativos animados
              Positioned(
                top: -100,
                right: -100,
                child: _AnimatedBlob(
                  controller: controller,
                  size: 300,
                  color: const Color(0xFF0D9488).withOpacity(0.1),
                ),
              ),
              Positioned(
                bottom: -150,
                left: -150,
                child: _AnimatedBlob(
                  controller: controller,
                  size: 400,
                  color: const Color(0xFF14B8A6).withOpacity(0.08),
                  reverse: true,
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.3,
                left: -80,
                child: _AnimatedBlob(
                  controller: controller,
                  size: 250,
                  color: const Color(0xFF0D9488).withOpacity(0.06),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final Color color;
  final bool reverse;

  const _AnimatedBlob({
    required this.controller,
    required this.size,
    required this.color,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final value = reverse ? 1 - controller.value : controller.value;
        return Transform.scale(
          scale: 1.0 + (value * 0.2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color,
                  color.withOpacity(0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// CONFETTI PAINTER PARA CELEBRACIÓN SUTIL
// ============================================================================

class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Partículas doradas y verdes sutiles
    final particles = [
      {'x': size.width * 0.2, 'y': size.height * 0.3, 'color': const Color(0xFFFFD700)},
      {'x': size.width * 0.5, 'y': size.height * 0.1, 'color': const Color(0xFF0D9488)},
      {'x': size.width * 0.8, 'y': size.height * 0.4, 'color': const Color(0xFFFFD700)},
      {'x': size.width * 0.3, 'y': size.height * 0.7, 'color': const Color(0xFF14B8A6)},
      {'x': size.width * 0.7, 'y': size.height * 0.8, 'color': const Color(0xFFFFD700)},
    ];

    for (var particle in particles) {
      paint.color = (particle['color'] as Color).withOpacity(0.6);
      canvas.drawCircle(
        Offset(particle['x'] as double, particle['y'] as double),
        4,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}