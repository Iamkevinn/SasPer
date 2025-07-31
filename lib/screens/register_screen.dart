// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  // Variables para seguir los requisitos de la contraseña en tiempo real
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasSpecialChar = false;

  final AuthRepository _authRepository = AuthRepository.instance;

  @override
  void initState() {
    super.initState();
    // Añadimos un listener al campo de contraseña para actualizar la UI de los requisitos
    _passwordController.addListener(_updatePasswordRequirements);
  }

  void _updatePasswordRequirements() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
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
        NotificationHelper.show(
          message: '¡Registro exitoso! Revisa tu correo electrónico para confirmar la cuenta.',
          type: NotificationType.success,
        );
        Navigator.of(context).pop();
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
    _passwordController.removeListener(_updatePasswordRequirements);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Nueva Cuenta', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Sección de Datos Personales ---
              _buildSectionCard([
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Nombre Completo', prefixIcon: Icon(Iconsax.user_octagon)),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Nombre de Usuario', prefixIcon: Icon(Iconsax.user)),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'El nombre de usuario es obligatorio.';
                    if (value.contains(' ')) return 'No puede contener espacios.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Iconsax.sms)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || !value.contains('@')) ? 'Introduce un correo válido.' : null,
                ),
              ]),
              const SizedBox(height: 24),
              
              // --- Sección de Contraseña ---
              _buildSectionCard([
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordObscured,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Iconsax.key),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Iconsax.eye_slash : Iconsax.eye),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'La contraseña es obligatoria.';
                    if (!_hasMinLength) return 'Debe tener al menos 8 caracteres.';
                    if (!_hasUppercase) return 'Debe contener una mayúscula.';
                    if (!_hasLowercase) return 'Debe contener una minúscula.';
                    if (!_hasSpecialChar) return 'Debe contener un carácter especial.';
                    if (_usernameController.text.isNotEmpty && value.toLowerCase().contains(_usernameController.text.toLowerCase())) {
                      return 'No debe contener tu nombre de usuario.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _isConfirmPasswordObscured,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    prefixIcon: const Icon(Iconsax.password_check),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordObscured ? Iconsax.eye_slash : Iconsax.eye),
                      onPressed: () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) return 'Las contraseñas no coinciden.';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _PasswordRequirement(label: 'Mínimo 8 caracteres', isValid: _hasMinLength),
                _PasswordRequirement(label: 'Una letra mayúscula (A-Z)', isValid: _hasUppercase),
                _PasswordRequirement(label: 'Una letra minúscula (a-z)', isValid: _hasLowercase),
                _PasswordRequirement(label: 'Un carácter especial (!@#\$...)', isValid: _hasSpecialChar),
              ]),
              const SizedBox(height: 32),
              
              // --- Botón de Registro ---
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: _signUp,
                      icon: const Icon(Iconsax.user_add),
                      label: const Text('Completar Registro'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget helper para agrupar campos en una tarjeta con estilo.
  Widget _buildSectionCard(List<Widget> children) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface.withAlpha(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

// Widget auxiliar para mostrar los requisitos de la contraseña.
class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool isValid;

  const _PasswordRequirement({required this.label, required this.isValid});

  @override
  Widget build(BuildContext context) {
    final successColor = Colors.green.shade600;
    final defaultColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            isValid ? Iconsax.tick_circle : Iconsax.close_circle,
            color: isValid ? successColor : defaultColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isValid ? successColor : defaultColor,
              decoration: isValid ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}