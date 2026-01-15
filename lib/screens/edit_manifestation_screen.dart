import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sasper/data/manifestation_repository.dart';
import 'package:sasper/models/manifestation_model.dart';

class EditManifestationScreen extends StatefulWidget {
  final Manifestation manifestation;

  const EditManifestationScreen({super.key, required this.manifestation});

  @override
  State<EditManifestationScreen> createState() =>
      _EditManifestationScreenState();
}

class _EditManifestationScreenState extends State<EditManifestationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _reflectionController = TextEditingController();

  final _manifestationRepository = ManifestationRepository();

  XFile? _newSelectedImage;
  bool _isLoading = false;
  bool _showReflection = false;
  bool _imageChanged = false;

  // Controladores de animación
  late AnimationController _cosmicController;
  late AnimationController _imageGlowController;
  late AnimationController _sectionController;
  late AnimationController _energyController;

  // Animaciones
  late Animation<double> _cosmicAnimation;
  late Animation<double> _imageGlowAnimation;
  late Animation<double> _sectionFadeAnimation;
  late Animation<Offset> _sectionSlideAnimation;

  // Frases inspiradoras
  final List<String> _renewalPhrases = [
    "Tu energía está alineada con tu nueva visión 🌟",
    "El universo ha recibido tu actualización 🌌",
    "Tu sueño evoluciona contigo ✨",
    "Has renovado el pacto con tu deseo 💫",
    "La manifestación se fortalece con tu atención 🌠",
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.manifestation.title);
    _descriptionController =
        TextEditingController(text: widget.manifestation.description);
    _setupAnimations();
    _playEntryAnimation();
  }

  void _setupAnimations() {
    // Animación cósmica del fondo
    _cosmicController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    _cosmicAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cosmicController, curve: Curves.easeInOut),
    );

    // Animación de brillo de imagen
    _imageGlowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _imageGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _imageGlowController, curve: Curves.easeOut),
    );

    // Animación de entrada de secciones
    _sectionController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _sectionFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sectionController, curve: Curves.easeOut),
    );
    _sectionSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _sectionController, curve: Curves.easeOutCubic),
    );

    // Animación de energía (para el botón)
    _energyController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();
  }

  void _playEntryAnimation() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _sectionController.forward();
    });
  }

  @override
  void dispose() {
    _cosmicController.dispose();
    _imageGlowController.dispose();
    _sectionController.dispose();
    _energyController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      HapticFeedback.lightImpact();

      final image = await _manifestationRepository.pickImage();
      if (image != null && mounted) {
        setState(() {
          _newSelectedImage = image;
          _imageChanged = true;
        });
        _imageGlowController.forward(from: 0.0);

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() => _imageChanged = false);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al seleccionar imagen: $e');
      }
    }
  }

  Future<void> saveManifestationsToWidget(
      List<Manifestation> manifestations) async {
    if (manifestations.isEmpty) return;
    final idsString = manifestations.map((m) => m.id).join(',');
    await HomeWidget.saveWidgetData<String>('manifestation_ids', idsString);
    await HomeWidget.saveWidgetData<int>(
        'manifestation_count', manifestations.length);
    await HomeWidget.saveWidgetData<int>('manifestation_index', 0);
    await HomeWidget.updateWidget(
      androidName: 'ManifestationWidgetProvider',
      iOSName: 'ManifestationWidget',
    );
  }

  Future<void> _submit() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await _manifestationRepository.updateManifestation(
        manifestationId: widget.manifestation.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        newImageFile: _newSelectedImage,
        oldImageUrl: widget.manifestation.imageUrl,
      );

      final allManifestations =
          await _manifestationRepository.getManifestations();
      await saveManifestationsToWidget(allManifestations);

      if (mounted) {
        HapticFeedback.heavyImpact();
        await _showRenewalDialog();
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.mediumImpact();
        _showErrorSnackBar('Error al actualizar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showRenewalDialog() async {
    final randomPhrase =
        _renewalPhrases[math.Random().nextInt(_renewalPhrases.length)];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RenewalDialog(phrase: randomPhrase),
    );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _toggleReflection() {
    setState(() => _showReflection = !_showReflection);
    HapticFeedback.selectionClick();
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
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showReflection ? Icons.edit_note : Icons.lightbulb_outline,
              color:
                  isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
            ),
            tooltip: 'Reflexión',
            onPressed: _toggleReflection,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo cósmico animado
          _CosmicBackground(
            cosmicAnimation: _cosmicAnimation,
            isDark: isDark,
          ),

          // Nebulosa de partículas
          AnimatedBuilder(
            animation: _cosmicAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: _NebulaPainter(
                  animation: _cosmicAnimation,
                  isDark: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Contenido principal
          SafeArea(
            child: FadeTransition(
              opacity: _sectionFadeAnimation,
              child: SlideTransition(
                position: _sectionSlideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // Encabezado emocional
                        _buildEmotionalHeader(theme, isDark),

                        const SizedBox(height: 40),

                        // Sección 1: Imagen con microinteracciones
                        _buildSection(
                          theme: theme,
                          isDark: isDark,
                          title: '🌌 Tu Visión',
                          subtitle: 'La imagen que inspira tu manifestación',
                          child: _buildImagePicker(theme, isDark),
                        ),

                        const SizedBox(height: 32),

                        // Sección 2: Título
                        _buildSection(
                          theme: theme,
                          isDark: isDark,
                          title: '💭 El Nombre',
                          subtitle: 'Nombrar es reafirmar tu poder',
                          child: _buildTitleField(theme, isDark),
                        ),

                        const SizedBox(height: 24),

                        // Sección 3: Descripción
                        _buildSection(
                          theme: theme,
                          isDark: isDark,
                          title: '✨ Tu Intención',
                          subtitle: 'Cómo ha evolucionado tu sueño',
                          child: _buildDescriptionField(theme, isDark),
                        ),

                        // Sección de reflexión (opcional)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          child: _showReflection
                              ? Column(
                                  children: [
                                    const SizedBox(height: 24),
                                    _buildSection(
                                      theme: theme,
                                      isDark: isDark,
                                      title: '🧘 Reflexión',
                                      subtitle:
                                          '¿Qué has aprendido en este camino?',
                                      child: _buildReflectionField(theme, isDark),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 40),

                        // Botón de guardar con energía
                        _buildEnergyButton(theme, isDark),

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

  Widget _buildEmotionalHeader(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isDark
                            ? [
                                Colors.amber.shade300.withOpacity(0.3),
                                Colors.deepPurple.shade700.withOpacity(0.1),
                              ]
                            : [
                                Colors.deepPurple.shade300.withOpacity(0.3),
                                Colors.purple.shade100.withOpacity(0.1),
                              ],
                      ),
                    ),
                    child: Icon(
                      Icons.autorenew_rounded,
                      size: 48,
                      color: isDark
                          ? Colors.amber.shade300
                          : Colors.deepPurple.shade400,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Renueva tu Manifestación',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: (isDark
                      ? Colors.deepPurple.shade900
                      : Colors.purple.shade50)
                  .withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark
                        ? Colors.amber.shade300
                        : Colors.deepPurple.shade300)
                    .withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Text(
              'A veces, actualizar tu sueño es volver a creer en él 💫',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.4,
                color: isDark
                    ? Colors.amber.shade200
                    : Colors.deepPurple.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? Colors.amber.shade300
                    : Colors.deepPurple.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildImagePicker(ThemeData theme, bool isDark) {
    final hasImage = _newSelectedImage != null ||
        (widget.manifestation.imageUrl?.isNotEmpty ?? false);

    return AnimatedBuilder(
      animation: _imageGlowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _pickImage,
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (_imageChanged)
                      BoxShadow(
                        color: (isDark ? Colors.amber : Colors.deepPurple)
                            .withOpacity(0.6 * _imageGlowAnimation.value),
                        blurRadius: 30 * _imageGlowAnimation.value,
                        spreadRadius: 5 * _imageGlowAnimation.value,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Imagen
                      if (_newSelectedImage != null)
                        Image.file(
                          File(_newSelectedImage!.path),
                          fit: BoxFit.cover,
                        )
                      else if (widget.manifestation.imageUrl != null &&
                          widget.manifestation.imageUrl!.isNotEmpty)
                        Image.network(
                          widget.manifestation.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      Colors.deepPurple.shade900
                                          .withOpacity(0.3),
                                      Colors.indigo.shade900.withOpacity(0.3),
                                    ]
                                  : [
                                      Colors.purple.shade100.withOpacity(0.5),
                                      Colors.blue.shade100.withOpacity(0.5),
                                    ],
                            ),
                          ),
                        ),

                      // Overlay con texto
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasImage
                                    ? Icons.edit_rounded
                                    : Icons.add_photo_alternate_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasImage
                                    ? 'Toca para cambiar la imagen'
                                    : 'Toca para añadir una imagen',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Botón flotante de cámara
              if (hasImage)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.amber.shade400,
                                Colors.amber.shade600,
                              ]
                            : [
                                Colors.deepPurple.shade400,
                                Colors.deepPurple.shade600,
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isDark ? Colors.amber : Colors.deepPurple)
                              .withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(30),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
        hintText: 'El nombre de tu sueño',
        prefixIcon: Icon(
          Icons.stars_rounded,
          color: isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
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
            color: isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
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
        hintText: 'Describe cómo ha cambiado tu visión...',
        helperText: 'Las palabras actualizan la energía 💫',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(
            Icons.auto_fix_high_rounded,
            color: isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
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
            color: isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
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

  Widget _buildReflectionField(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              (isDark ? Colors.amber.shade300 : Colors.deepPurple.shade300)
                  .withOpacity(0.3),
          width: 2,
        ),
        color: (isDark
                ? Colors.deepPurple.shade900
                : Colors.purple.shade50)
            .withOpacity(0.3),
      ),
      child: TextFormField(
        controller: _reflectionController,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Comparte tu aprendizaje en este camino...',
          hintStyle: TextStyle(
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildEnergyButton(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _energyController,
      builder: (context, child) {
        final pulse =
            math.sin(_energyController.value * 2 * math.pi) * 0.5 + 0.5;

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
              backgroundColor:
                  isDark ? Colors.amber.shade400 : Colors.deepPurple.shade500,
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
                        'Renovando energía...',
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
                        Icons.energy_savings_leaf_rounded,
                        size: 28,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Renovar Manifestación',
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

class _CosmicBackground extends StatelessWidget {
  final Animation<double> cosmicAnimation;
  final bool isDark;

  const _CosmicBackground({
    required this.cosmicAnimation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cosmicAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Color.lerp(
                          const Color(0xFF1C1B2F),
                          const Color(0xFF3A2D55),
                          0.3 + (cosmicAnimation.value * 0.2))!,
                      Color.lerp(const Color(0xFF1C1B2F),
                          const Color(0xFF2A1F3D),
                          0.2 + (cosmicAnimation.value * 0.15))!,
                    ]
                  : [
                      Color.lerp(const Color(0xFFF3E5F5),
                          const Color(0xFFE1BEE7), cosmicAnimation.value)!,
                      Color.lerp(const Color(0xFFE8EAF6),
                          const Color(0xFFC5CAE9), cosmicAnimation.value)!,
                    ],
            ),
          ),
        );
      },
    );
  }
}

class _NebulaPainter extends CustomPainter {
  final Animation<double> animation;
  final bool isDark;

  _NebulaPainter({required this.animation, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.amber.shade300 : Colors.deepPurple.shade300)
          .withOpacity(0.15)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final random = math.Random(123);

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = 30 + random.nextDouble() * 60;
      final y = (baseY + (animation.value * speed)) % size.height;
      final radius = 2 + random.nextDouble() * 4;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_NebulaPainter oldDelegate) => true;
}

class _RenewalDialog extends StatefulWidget {
  final String phrase;

  const _RenewalDialog({required this.phrase});

  @override
  State<_RenewalDialog> createState() => _RenewalDialogState();
}

class _RenewalDialogState extends State<_RenewalDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    _scaleController.forward();
    _rotationController.repeat();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
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
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono animado con rotación
              AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Container(
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
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? Colors.amber.shade300
                                    : Colors.deepPurple.shade300)
                                .withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.autorenew_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              Text(
                '🌟 Energía Renovada 🌟',
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
                  elevation: 8,
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