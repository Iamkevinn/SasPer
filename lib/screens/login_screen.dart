// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart'; // <-- ¡IMPORTANTE!

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

  // --- CORRECCIÓN CLAVE: Usamos el Singleton ---
  // Obtenemos la instancia global en lugar de crear una nueva.
  final AuthRepository _authRepository = AuthRepository.instance;

  /// Valida el formulario e intenta iniciar sesión.
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authRepository.signInWithPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      // El AuthGate se encargará de redirigir si el inicio de sesión es exitoso.
    } catch (e) {
      if (mounted) {
       NotificationHelper.show(
            message: e.toString().replaceFirst("Exception: ", ""),
            type: NotificationType.error,
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Valida el formulario e intenta registrar un nuevo usuario.
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authRepository.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        NotificationHelper.show(
            message: 'Registro exitoso. Revisa tu correo para confirmar.',
            type: NotificationType.success,
          );
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
            message: e.toString().replaceFirst("Exception: ", ""),
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
          child: Form( // Envolvemos en un Form
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.wallet_check, size: 80, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Bienvenido a SasPer',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Toma el control de tus finanzas',
                  style: GoogleFonts.poppins(fontSize: 16, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Iconsax.sms),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Por favor, introduce un correo válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Iconsax.key),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                     if (value == null || value.isEmpty || value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: _signIn,
                        icon: const Icon(Iconsax.login),
                        label: const Text('Iniciar Sesión'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)
                        ),
                      ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading ? null : _signUp, // Deshabilitar mientras carga
                  child: const Text('¿No tienes cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}