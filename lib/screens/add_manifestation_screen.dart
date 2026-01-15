import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/manifestation_repository.dart';

class AddManifestationScreen extends StatefulWidget {
  const AddManifestationScreen({super.key});

  @override
  State<AddManifestationScreen> createState() => _AddManifestationScreenState();
}

class _AddManifestationScreenState extends State<AddManifestationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _manifestationRepository = ManifestationRepository();

  XFile? _selectedImage;
  bool _isLoading = false;
  bool _imageJustSelected = false;

  // Controladores de animación
  late AnimationController _breathingController;
  late AnimationController _particlesController;
  late AnimationController _imageGlowController;
  late AnimationController _buttonController;
  late AnimationController _formController;

  // Animaciones
  late Animation<double> _breathingAnimation;
  late Animation<double> _particlesAnimation;
  late Animation<double> _imageGlowAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  // Frases inspiradoras
  final List<String> _inspirationalPhrases = [
    "El universo ha escuchado tu intención 🌌",
    "Tu energía se expande hacia tu deseo ✨",
    "Lo que visualizas, se materializa 🌟",
    "El cosmos conspira a tu favor 💫",
    "Tu sueño ya está en camino 🌠",
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playEntryAnimation();
  }

  void _setupAnimations() {
    // Animación de respiración del fondo
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _breathingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Animación de partículas
    _particlesController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _particlesAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      _particlesController,
    );

    // Animación de brillo de imagen
    _imageGlowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _imageGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _imageGlowController, curve: Curves.easeOut),
    );

    // Animación del botón
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    // Animación de entrada del formulario
    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOut),
    );
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );
  }

  void _playEntryAnimation() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _particlesController.dispose();
    _imageGlowController.dispose();
    _buttonController.dispose();
    _formController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      // Vibración suave
      HapticFeedback.lightImpact();

      final image = await _manifestationRepository.pickImage();
      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          _imageJustSelected = true;
        });
        _imageGlowController.forward(from: 0.0);

        // Resetear el flag después de la animación
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _imageJustSelected = false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error al seleccionar imagen: $e')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || _selectedImage == null) {
      if (_selectedImage == null && mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.image_outlined, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Selecciona una imagen que inspire tu sueño ✨'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.deepPurple.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await _manifestationRepository.createManifestation(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        imageFile: _selectedImage!,
      );

      // Actualizar widget
      final allManifestations =
          await _manifestationRepository.getManifestations();

      if (allManifestations.isNotEmpty) {
        final idsString = allManifestations.map((m) => m.id).join(',');
        await HomeWidget.saveWidgetData<String>(
            'manifestation_ids', idsString);
        await HomeWidget.saveWidgetData<int>(
            'manifestation_count', allManifestations.length);
        await HomeWidget.saveWidgetData<int>('manifestation_index', 0);
      }

      await HomeWidget.saveWidgetData<String>(
          'manifestation_title', _titleController.text.trim());

      final directory = await getExternalStorageDirectory();
      final newImagePath =
          path.join(directory!.path, path.basename(_selectedImage!.path));
      await File(_selectedImage!.path).copy(newImagePath);
      await HomeWidget.saveWidgetData<String>(
          'manifestation_image_path', newImagePath);

      await HomeWidget.updateWidget(
        androidName: 'ManifestationWidgetProvider',
        iOSName: 'ManifestationWidget',
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        await _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error al guardar: $e')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    final randomPhrase = _inspirationalPhrases[
        math.Random().nextInt(_inspirationalPhrases.length)];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SuccessDialog(phrase: randomPhrase),
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Fondo con gradiente animado
          _AnimatedBackground(
            breathingAnimation: _breathingAnimation,
            isDark: isDark,
          ),

          // Partículas flotantes
          AnimatedBuilder(
            animation: _particlesAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlesPainter(
                  animation: _particlesAnimation,
                  isDark: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Contenido principal
          SafeArea(
            child: FadeTransition(
              opacity: _formFadeAnimation,
              child: SlideTransition(
                position: _formSlideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // Título místico
                        _buildMysticTitle(theme),

                        const SizedBox(height: 12),

                        // Texto inspirador
                        _buildInspirationalText(theme, isDark),

                        const SizedBox(height: 40),

                        // Selector de imagen mágico
                        _buildImagePicker(theme, isDark),

                        const SizedBox(height: 32),

                        // Campo de título
                        _buildTitleField(theme, isDark),

                        const SizedBox(height: 20),

                        // Campo de descripción
                        _buildDescriptionField(theme, isDark),

                        const SizedBox(height: 40),

                        // Botón de manifestar mágico
                        _buildManifestButton(theme, isDark),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMysticTitle(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 40,
            color: theme.brightness == Brightness.dark
                ? Colors.amber.shade300
                : Colors.deepPurple.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Manifiesta tu Sueño',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInspirationalText(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.deepPurple.shade900 : Colors.purple.shade50)
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              (isDark ? Colors.amber.shade300 : Colors.deepPurple.shade300)
                  .withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        '✨ Visualiza tu sueño, siéntelo con cada célula de tu ser, y déjalo fluir hacia el universo',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          height: 1.5,
          color: isDark ? Colors.amber.shade200 : Colors.deepPurple.shade700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildImagePicker(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _imageGlowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (_imageJustSelected)
                  BoxShadow(
                    color: (isDark ? Colors.amber : Colors.deepPurple)
                        .withOpacity(0.6 * _imageGlowAnimation.value),
                    blurRadius: 30 * _imageGlowAnimation.value,
                    spreadRadius: 5 * _imageGlowAnimation.value,
                  ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Imagen o placeholder
                  if (_selectedImage != null)
                    Positioned.fill(
                      child: Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  Colors.deepPurple.shade900.withOpacity(0.3),
                                  Colors.indigo.shade900.withOpacity(0.3),
                                ]
                              : [
                                  Colors.purple.shade100.withOpacity(0.5),
                                  Colors.blue.shade100.withOpacity(0.5),
                                ],
                        ),
                      ),
                    ),

                  // Overlay cuando no hay imagen
                  if (_selectedImage == null)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: (isDark
                                    ? Colors.amber.shade300
                                    : Colors.deepPurple.shade300)
                                .withOpacity(0.5),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.8, end: 1.0),
                                duration: const Duration(milliseconds: 1000),
                                curve: Curves.easeInOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: (isDark
                                                ? Colors.amber.shade300
                                                : Colors.deepPurple.shade400)
                                            .withOpacity(0.2),
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 50,
                                        color: isDark
                                            ? Colors.amber.shade300
                                            : Colors.deepPurple.shade400,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Toca para añadir tu visión',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Una imagen que inspire tu meta',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Icono de edición cuando hay imagen
                  if (_selectedImage != null)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleField(ThemeData theme, bool isDark) {
    return TextFormField(
      controller: _titleController,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: 'Nombra tu sueño',
        hintText: 'Ej: Mi viaje a Japón',
        helperText: 'Nombrarlo lo trae al presente ✨',
        prefixIcon: Icon(
          Icons.stars_rounded,
          color:
              isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.amber.shade300.withOpacity(0.3)
                : Colors.deepPurple.shade300.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.2)
                : Colors.black.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color:
                isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Tu sueño necesita un nombre';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField(ThemeData theme, bool isDark) {
    return TextFormField(
      controller: _descriptionController,
      style: theme.textTheme.bodyLarge,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Describe tu visión',
        hintText: 'Cómo te sentirás al lograrlo...',
        helperText: 'Las emociones amplifican la manifestación 💫',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(
            Icons.auto_fix_high_rounded,
            color:
                isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.2)
                : Colors.black.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color:
                isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
      ),
    );
  }

  Widget _buildManifestButton(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _buttonController,
      builder: (context, child) {
        final pulse = math.sin(_buttonController.value * 2 * math.pi) * 0.5 + 0.5;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.amber : Colors.deepPurple)
                    .withOpacity(0.3 + (pulse * 0.2)),
                blurRadius: 20 + (pulse * 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: isDark
                  ? Colors.amber.shade400
                  : Colors.deepPurple.shade500,
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: isDark ? Colors.black : Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Manifestando...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 28,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Manifestar mi Sueño',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ===================================================================
//                    WIDGETS AUXILIARES
// ===================================================================

class _AnimatedBackground extends StatelessWidget {
  final Animation<double> breathingAnimation;
  final bool isDark;

  const _AnimatedBackground({
    required this.breathingAnimation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breathingAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Color.lerp(Colors.black, Colors.deepPurple.shade900,
                          0.2 + (breathingAnimation.value * 0.1))!,
                      Color.lerp(Colors.black, Colors.indigo.shade900,
                          0.15 + (breathingAnimation.value * 0.05))!,
                    ]
                  : [
                      Color.lerp(Colors.purple.shade50, Colors.blue.shade50,
                          breathingAnimation.value)!,
                      Color.lerp(Colors.pink.shade50, Colors.purple.shade100,
                          breathingAnimation.value)!,
                    ],
            ),
          ),
        );
      },
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isDark;

  _ParticlesPainter({required this.animation, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.amber.shade300 : Colors.deepPurple.shade300)
          .withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);

    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 50 + random.nextDouble() * 100;
      final y = (baseY + (animation.value * speed)) % size.height;
      final radius = 1 + random.nextDouble() * 2;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) => true;
}

class _SuccessDialog extends StatefulWidget {
  final String phrase;

  const _SuccessDialog({required this.phrase});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark
              ? Colors.grey.shade900
              : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: isDark
                        ? [
                            Colors.amber.shade300,
                            Colors.amber.shade700,
                          ]
                        : [
                            Colors.deepPurple.shade300,
                            Colors.deepPurple.shade600,
                          ],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '✨ Manifestación Enviada ✨',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.amber.shade300
                      : Colors.deepPurple.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.phrase,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.amber.shade400
                      : Colors.deepPurple.shade500,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}