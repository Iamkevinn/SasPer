import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/screens/categories_screen.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/theme_provider.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/screens/profile_screen.dart';
import 'package:sasper/services/preferences_service.dart';
import 'package:local_auth/local_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final AuthRepository _authRepository = AuthRepository.instance;
  bool _isBiometricLockEnabled = true;
  bool _isLoadingBiometricStatus = true;
  User? _user;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _user = _authRepository.currentUser;
    _loadBiometricStatus();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricStatus() async {
    final isEnabled = await PreferencesService.instance.isBiometricLockEnabled();
    if (mounted) {
      setState(() {
        _isBiometricLockEnabled = isEnabled;
        _isLoadingBiometricStatus = false;
      });
    }
  }

  Future<void> _onBiometricLockChanged(bool newValue) async {
    if (newValue == true) {
      final LocalAuthentication auth = LocalAuthentication();
      final bool canAuthenticate =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate && mounted) {
        NotificationHelper.show(
          message: 'Tu dispositivo no es compatible con el bloqueo biométrico.',
          type: NotificationType.error,
        );
        return;
      }
    }

    await PreferencesService.instance.setBiometricLock(isEnabled: newValue);
    setState(() {
      _isBiometricLockEnabled = newValue;
    });
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              //color: isDark ? const Color(0xFF141922) : Colors.white,
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                //  color: isDark ? const Color(0xFF1E2836) : const Color(0xFFE5E9F0),
                color: colorScheme.outlineVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Iconsax.logout,
                    color: colorScheme.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Confirmar Cierre de Sesión',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFE8EDF4) : const Color(0xFF1A1F2E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Estás seguro de que quieres cerrar tu sesión?',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF8B95A8) : const Color(0xFF5F6B7A),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: isDark 
                              ? const Color(0xFF1A2030) 
                              : const Color(0xFFF0F4F8),
                          foregroundColor: isDark 
                              ? const Color(0xFFE8EDF4) 
                              : const Color(0xFF1A1F2E),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Cerrar Sesión',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      try {
        await _authRepository.signOut();
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al cerrar sesión: "${e.toString()}"',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  void _showThemeDialog() {
        final colorScheme = Theme.of(context).colorScheme;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              //color: isDark ? const Color(0xFF141922) : Colors.white,
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                //color: isDark ? const Color(0xFF1E2836) : const Color(0xFFE5E9F0),
                color: colorScheme.outlineVariant,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleccionar Tema',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFE8EDF4) : const Color(0xFF1A1F2E),
                  ),
                ),
                const SizedBox(height: 20),
                _buildThemeOption(
                  context,
                  themeProvider,
                  ThemeMode.light,
                  'Claro',
                  Iconsax.sun_1,
                ),
                const SizedBox(height: 12),
                _buildThemeOption(
                  context,
                  themeProvider,
                  ThemeMode.dark,
                  'Oscuro',
                  Iconsax.moon,
                ),
                const SizedBox(height: 12),
                _buildThemeOption(
                  context,
                  themeProvider,
                  ThemeMode.system,
                  'Automático (Sistema)',
                  Iconsax.monitor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemeMode mode,
    String label,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = themeProvider.themeMode == mode;
    final accentColor = isDark ? const Color(0xFF0EA5A5) : const Color(0xFF0D9488);

    return InkWell(
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? const Color(0xFF1E2836) : const Color(0xFFE5E9F0)),
            width: isSelected ? 2 : 1,
          ),
          color: isDark ? const Color(0xFF1A2030) : const Color(0xFFF0F4F8),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : (isDark ? const Color(0xFF2A3344) : const Color(0xFFCBD5E1)),
                  width: 2,
                ),
                color: isSelected ? accentColor : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFE8EDF4) : const Color(0xFF1A1F2E),
                ),
              ),
            ),
            Icon(
              icon,
              size: 20,
              color: isDark ? const Color(0xFF8B95A8) : const Color(0xFF5F6B7A),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Automático';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      //backgroundColor: isDark ? const Color(0xFF0A0E14) : const Color(0xFFF5F7FA),
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        //backgroundColor: isDark ? const Color(0xFF141922) : Colors.white,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Ajustes',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: isDark ? const Color(0xFFE8EDF4) : const Color(0xFF1A1F2E),
          ),
        ),
      ),
      body: ListView(
        //padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 60.0),
        children: [
          _buildSectionHeader('PERFIL'),
          const SizedBox(height: 12),
          _buildPremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF0EA5A5), const Color(0xFF0D9488)]
                            : [const Color(0xFF0D9488), const Color(0xFF0EA5A5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? const Color(0xFF0EA5A5) : const Color(0xFF0D9488))
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _user?.email?.substring(0, 1).toUpperCase() ?? '?',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sesión Iniciada como',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF8B95A8) : const Color(0xFF5F6B7A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _user?.email ?? 'No autenticado',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDark ? const Color(0xFFE8EDF4) : const Color(0xFF1A1F2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildPremiumCard(
            child: _buildSettingsTile(
              icon: Iconsax.notification,
              title: 'Probar Notificación Inmediata',
              subtitle: 'Recibirás una notificación en 5 segundos',
              onTap: () {
                NotificationService.instance.testImmediateNotification();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Notificación de prueba programada...',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: isDark ? const Color(0xFF1A2030) : const Color(0xFF1A1F2E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ),
          //const SizedBox(height: 32),
          const SizedBox(height: 80), // O 80 para más espacio
          _buildSectionHeader('PERSONALIZACIÓN'),
          const SizedBox(height: 12),
          _buildPremiumCard(
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Iconsax.award,
                  title: 'Mi Progreso',
                  subtitle: 'Ver tu nivel y logros',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Iconsax.moon,
                  title: 'Modo de la aplicación',
                  subtitle: _getThemeModeString(themeProvider.themeMode),
                  trailing: const Icon(Iconsax.arrow_down_1, size: 18),
                  onTap: _showThemeDialog,
                ),
                _buildDivider(),
                if (_isLoadingBiometricStatus)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _buildBiometricSwitch(),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Iconsax.grid_3,
                  title: 'Gestionar Categorías',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('CUENTA'),
          const SizedBox(height: 12),
          _buildPremiumCard(
            child: _buildSettingsTile(
              icon: Iconsax.logout,
              title: 'Cerrar Sesión',
              iconColor: colorScheme.error,
              titleColor: colorScheme.error,
              onTap: _showLogoutConfirmationDialog,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF8B95A8) : const Color(0xFF5F6B7A),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildPremiumCard({required Widget child}) {
        final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        //color: isDark ? const Color(0xFF141922) : Colors.white,
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          //color: isDark ? const Color(0xFF1E2836) : const Color(0xFFE5E9F0),
          color: colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF0EA5A5) : const Color(0xFF0D9488);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: subtitle != null 
            ? BorderRadius.zero 
            : BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (iconColor ?? accentColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor ?? accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: titleColor ?? 
                            (isDark ? const Color(0xFFE8EDF4) : const Color(0xFF1A1F2E)),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF8B95A8) : const Color(0xFF5F6B7A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Iconsax.arrow_right_3,
                  size: 18,
                  color: isDark ? const Color(0xFF8B95A8) : const Color(0xFF5F6B7A),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricSwitch() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF0EA5A5) : const Color(0xFF0D9488);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Iconsax.finger_scan,
              size: 22,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bloqueo de la aplicación',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFE8EDF4) : const Color(0xFF1A1F2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Requerir PIN o huella al abrir',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF8B95A8) : const Color(0xFF5F6B7A),
                  ),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _isBiometricLockEnabled ? 1 : 0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return GestureDetector(
                onTap: () => _onBiometricLockChanged(!_isBiometricLockEnabled),
                child: Container(
                  width: 56,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Color.lerp(
                      isDark ? const Color(0xFF2A3344) : const Color(0xFFCBD5E1),
                      accentColor,
                      value,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Align(
                      alignment: Alignment.lerp(
                        Alignment.centerLeft,
                        Alignment.centerRight,
                        value,
                      )!,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
        final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      //color: isDark ? const Color(0xFF1E2836) : const Color(0xFFE5E9F0),
      color: colorScheme.outlineVariant,
    );
  }
}