// lib/screens/login_screen.dart

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

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureText = true;

  final AuthRepository _authRepository = AuthRepository.instance;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authRepository.signInWithPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // La navegación ocurrirá automáticamente gracias al AuthGate que escucha los cambios de sesión.
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          message: e.toString(), // El repo ya devuelve un mensaje amigable
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            // Anima todos los widgets hijos en cascada
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Reemplazamos el icono estático por una animación Lottie
                Lottie.asset(
                  'assets/animations/login_animation.json',
                  height: 200, // Ajusta el tamaño como prefieras
                ),
                const SizedBox(height: 16),
                Text('Bienvenido a SasPer', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Toma el control de tus finanzas', style: GoogleFonts.poppins(fontSize: 16, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Iconsax.sms),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || !value.contains('@') || !value.contains('.')) {
                      return 'Por favor, introduce un correo válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Iconsax.key),
                    // 2. Añadimos un botón para mostrar/ocultar la contraseña
                    suffixIcon: IconButton(
                      icon: Icon(_obscureText ? Iconsax.eye_slash : Iconsax.eye),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureText,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // 3. Mejoramos el botón de carga
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _signIn,
                        icon: const Icon(Iconsax.login),
                        label: const Text('Iniciar Sesión'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    ));
                  },
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
              ],
            )
            // 4. Aplicamos las animaciones de entrada a toda la columna
            .animate(delay: 200.ms)
            .slideY(begin: 0.2, duration: 500.ms, curve: Curves.easeOutCubic)
            .fadeIn(duration: 500.ms),
          ),
        ),
      ),
    );
  }
}