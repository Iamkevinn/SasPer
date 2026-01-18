import 'package:flutter/material.dart';
import 'package:sasper/data/manifestation_repository.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:sasper/screens/add_manifestation_screen.dart';
import 'package:sasper/screens/edit_manifestation_screen.dart';
import 'package:sasper/screens/ManifestationVisionWidgetDebug.dart';
import 'package:sasper/services/widget_service.dart';
import 'dart:math' as math;
import 'package:sasper/services/manifestation_widget_service.dart';

class ManifestationsScreen extends StatefulWidget {
  const ManifestationsScreen({super.key});

  @override
  _ManifestationsScreenState createState() => _ManifestationsScreenState();
}

class _ManifestationsScreenState extends State<ManifestationsScreen>
    with TickerProviderStateMixin {
  final _repository = ManifestationRepository();
  late Future<List<Manifestation>> _manifestationsFuture;
  late AnimationController _sparkleController;
  late AnimationController _fabController;
  
  // 🆕 Variable para mostrar/ocultar el panel de debug
  bool _showDebugPanel = false;

  @override
  void initState() {
    super.initState();
    _loadManifestations();
    
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadManifestations() async {
    setState(() {
      _manifestationsFuture = _repository.getManifestations();
    });

    final manifestations = await _manifestationsFuture;
    await ManifestationWidgetService.saveManifestationsToWidget(manifestations);
    await saveManifestationsToWidget(manifestations);
  }

  void _navigateToAddScreen() async {
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AddManifestationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (result != null) {
      _loadManifestations();
    }
  }

  void _navigateToEditScreen(Manifestation manifestation) async {
    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditManifestationScreen(manifestation: manifestation),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    if (result == true) {
      _loadManifestations();
    }
  }

  Future<void> _showDeleteConfirmation(Manifestation manifestation) async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.amber.shade700, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Confirmar Eliminación',
                  style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${manifestation.title}"? Esta acción no se puede deshacer.',
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteManifestation(
          manifestationId: manifestation.id,
          imageUrl: manifestation.imageUrl ?? '',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('"${manifestation.title}" ha sido eliminado.'),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.green.shade600,
            ),
          );
        }
        _loadManifestations();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error al eliminar: $e')),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  // 🆕 Mostrar panel de debug en modal
  void _showDebugModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle del modal
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Título
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bug_report,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Panel de Debug',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Contenido del debug
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: const ManifestationWidgetDebug(
                      widgetId: null, // null = global, o usa '0' para el primer widget
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            AnimatedBuilder(
              animation: _sparkleController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _sparkleController.value * 2 * math.pi,
                  child: Icon(
                    Icons.auto_awesome,
                    color: isDark
                        ? Colors.amber.shade300
                        : Colors.deepPurple.shade400,
                    size: 26,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            const Text(
              'Mis Manifestaciones',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        // 🆕 Botón de debug en el AppBar
        actions: [
          IconButton(
            icon: Icon(
              Icons.bug_report,
              color: isDark ? Colors.amber.shade300 : Colors.white,
            ),
            tooltip: 'Panel de Debug del Widget',
            onPressed: _showDebugModal,
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.deepPurple.shade900.withOpacity(0.95),
                      Colors.indigo.shade900.withOpacity(0.95),
                    ]
                  : [
                      Colors.deepPurple.shade400.withOpacity(0.95),
                      Colors.purple.shade300.withOpacity(0.95),
                    ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Fondo con gradiente animado
          _AnimatedBackground(isDark: isDark),
          
          // Contenido principal
          SafeArea(
            child: Column(
              children: [
                // Frase inspiradora
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Text(
                    '"Lo que imaginas, puedes crear"',
                    style: TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? Colors.amber.shade200
                          : Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // 🆕 Panel de debug expandible (opcional, como alternativa al modal)
                if (_showDebugPanel)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: ManifestationWidgetDebug(widgetId: null),
                  ),
                
                // Lista de manifestaciones
                Expanded(
                  child: FutureBuilder<List<Manifestation>>(
                    future: _manifestationsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: isDark
                                    ? Colors.amber.shade300
                                    : Colors.deepPurple.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Cargando tus manifestaciones...',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 64, color: Colors.red.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'Error al cargar los datos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final manifestations = snapshot.data!;
                      if (manifestations.isEmpty) {
                        return _buildEmptyState(isDark);
                      }
                      return RefreshIndicator(
                        onRefresh: _loadManifestations,
                        color: isDark
                            ? Colors.amber.shade300
                            : Colors.deepPurple.shade400,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: manifestations.length,
                          itemBuilder: (context, index) {
                            final manifestation = manifestations[index];
                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 300 + (index * 100)),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: _ManifestationCard(
                                manifestation: manifestation,
                                onEdit: () => _navigateToEditScreen(manifestation),
                                onDelete: () =>
                                    _showDeleteConfirmation(manifestation),
                                isDark: isDark,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark
                          ? Colors.amber.shade300
                          : Colors.deepPurple.shade400)
                      .withOpacity(0.4 + (_fabController.value * 0.2)),
                  blurRadius: 20 + (_fabController.value * 10),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: _navigateToAddScreen,
              icon: const Icon(Icons.add_rounded, size: 28),
              label: const Text(
                'Nueva',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: isDark
                  ? Colors.amber.shade400
                  : Colors.deepPurple.shade500,
              foregroundColor: isDark ? Colors.black : Colors.white,
              elevation: 8,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _sparkleController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (math.sin(_sparkleController.value * 2 * math.pi) * 0.1),
                  child: Container(
                    width: 120,
                    height: 120,
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
                      Icons.auto_awesome,
                      size: 64,
                      color: isDark
                          ? Colors.amber.shade300
                          : Colors.deepPurple.shade400,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              'Comienza a Manifestar',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Visualiza tus sueños y metas.\nConecta tus deseos con tu propósito.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.black54,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _navigateToAddScreen,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Crear mi primera manifestación',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: isDark
                    ? Colors.amber.shade400
                    : Colors.deepPurple.shade500,
                foregroundColor: isDark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  final bool isDark;

  const _AnimatedBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/Images/LaCondicionHumana.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(isDark ? 0.8 : 0.5),
            BlendMode.darken,
          ),
        ),
      ),
    );
  }
}

class _ManifestationCard extends StatelessWidget {
  final Manifestation manifestation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDark;

  const _ManifestationCard({
    super.key,
    required this.manifestation,
    required this.onEdit,
    required this.onDelete,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final String imageUrl = manifestation.imageUrl?.isNotEmpty == true
        ? manifestation.imageUrl!
        : 'https://via.placeholder.com/600x400?text=Sin+imagen';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        elevation: 8,
        shadowColor: (isDark ? Colors.deepPurple : Colors.purple)
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark
                      ? Colors.amber.shade300
                      : Colors.deepPurple.shade200)
                  .withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                // Imagen de fondo
                Positioned.fill(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.deepPurple.shade400,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade200,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 48,
                            color: isDark
                                ? Colors.white30
                                : Colors.black26,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Overlay con glassmorphism
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                
                // Título y descripción
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manifestation.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                blurRadius: 8.0,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (manifestation.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            manifestation.description!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              letterSpacing: 0.3,
                              shadows: const [
                                Shadow(
                                  blurRadius: 4.0,
                                  color: Colors.black38,
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Botón de menú
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded,
                                  color: isDark
                                      ? Colors.amber.shade300
                                      : Colors.deepPurple.shade400),
                              const SizedBox(width: 12),
                              const Text('Editar',
                                  style: TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded,
                                  color: Colors.red.shade400),
                              const SizedBox(width: 12),
                              Text(
                                'Eliminar',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Icono de manifestación
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? Colors.amber.shade300
                              : Colors.deepPurple.shade400)
                          .withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isDark
                                  ? Colors.amber.shade300
                                  : Colors.deepPurple.shade400)
                              .withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: isDark ? Colors.black : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}