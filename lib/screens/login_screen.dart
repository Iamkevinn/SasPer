// lib/screens/login_screen.dart
// VERSIÓN PREMIUM ELITE - Estilo bancario top-tier

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/screens/register_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _obscureText = true;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;

  final AuthRepository _authRepository = AuthRepository.instance;
  
  late AnimationController _gradientController;
  late AnimationController _buttonPressController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animación de gradiente de fondo
    _gradientController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    
    // Animación de presión del botón
    _buttonPressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonPressController, curve: Curves.easeInOut),
    );
    
    // Listeners para efectos de focus
    _emailFocusNode.addListener(() {
      setState(() {
        _emailHasFocus = _emailFocusNode.hasFocus;
      });
    });
    
    _passwordFocusNode.addListener(() {
      setState(() {
        _passwordHasFocus = _passwordFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _gradientController.dispose();
    _buttonPressController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      _buttonPressController.forward().then((_) {
        _buttonPressController.reverse();
      });
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _authRepository.signInWithPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // La navegación ocurrirá automáticamente gracias al AuthGate
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          message: e.toString(),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onButtonPress() {
    _buttonPressController.forward().then((_) {
      _buttonPressController.reverse();
      _signIn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente animado
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
          
          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: size.width > 600 ? size.width * 0.25 : 24.0,
                  vertical: 24.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo animado
                      _buildLogo(isDark),
                      
                      const SizedBox(height: 32),
                      
                      // Título y subtítulo
                      _buildHeader(colorScheme),
                      
                      const SizedBox(height: 48),
                      
                      // Formulario en card glassmorphic
                      _buildFormCard(
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Botón de inicio de sesión
                      _buildLoginButton(colorScheme, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // Link de registro
                      _buildRegisterLink(colorScheme),
                      
                      const SizedBox(height: 16),
                      
                      // Indicador de seguridad
                      _buildSecurityIndicator(colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Hero(
      tag: 'app_logo',
      child: Container(
        height: 140,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0D9488).withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Lottie animation
            Lottie.asset(
              'assets/animations/login_animation.json',
              height: 140,
              width: 140,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.8, 0.8), curve: Curves.elasticOut);
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          'Bienvenido a SasPer',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 200.ms, duration: 500.ms)
            .slideY(begin: 0.3, curve: Curves.easeOutCubic),
        
        const SizedBox(height: 12),
        
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [
              const Color(0xFF0D9488),
              const Color(0xFF14B8A6),
            ],
          ).createShader(bounds),
          child: Text(
            'Tu camino hacia la libertad financiera',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 500.ms)
            .slideY(begin: 0.3, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildFormCard({
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.4)
            : colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          // Campo de email
          _buildPremiumTextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            label: 'Correo Electrónico',
            hint: 'tu@email.com',
            icon: Iconsax.sms,
            keyboardType: TextInputType.emailAddress,
            hasFocus: _emailHasFocus,
            colorScheme: colorScheme,
            validator: (value) {
              if (value == null || !value.contains('@') || !value.contains('.')) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 20),
          
          // Campo de contraseña
          _buildPremiumTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            label: 'Contraseña',
            hint: 'Mínimo 6 caracteres',
            icon: Iconsax.key,
            obscureText: _obscureText,
            hasFocus: _passwordHasFocus,
            colorScheme: colorScheme,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureText ? Iconsax.eye_slash : Iconsax.eye,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscureText = !_obscureText;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'Mínimo 6 caracteres';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 16),
          
          // Olvidé mi contraseña
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : () {
                NotificationHelper.show(
                  message: 'Función disponible próximamente',
                  type: NotificationType.info,
                );
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D9488),
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 600.ms, duration: 500.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut);
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool hasFocus,
    required ColorScheme colorScheme,
    TextInputType? keyboardType,
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
          suffixIcon: suffixIcon,
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

  Widget _buildLoginButton(ColorScheme colorScheme, bool isDark) {
    return AnimatedBuilder(
      animation: _buttonScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonScaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0D9488),
              Color(0xFF14B8A6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D9488).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _onButtonPress,
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ingresar ahora',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Iconsax.arrow_right_3,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 800.ms, duration: 500.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic);
  }

  Widget _buildLoadingIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Barra de progreso que llena de izquierda a derecha
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
        // Spinner central
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterLink(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '¿No tienes cuenta?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const RegisterScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                    ),
                  );
                },
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF0D9488),
                Color(0xFF14B8A6),
              ],
            ).createShader(bounds),
            child: Text(
              'Crear una cuenta nueva',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 1000.ms, duration: 500.ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic);
  }

  Widget _buildSecurityIndicator(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Iconsax.shield_tick,
          size: 16,
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          'Conexión segura encriptada',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 1200.ms, duration: 500.ms);
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