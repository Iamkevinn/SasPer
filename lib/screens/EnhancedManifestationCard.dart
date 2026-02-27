// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:sasper/services/manifestation_widget_service.dart';

/// Card mejorado con botón de manifestar directo
class EnhancedManifestationCard extends StatefulWidget {
  final Manifestation manifestation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDark;
  final int index;

  const EnhancedManifestationCard({
    super.key,
    required this.manifestation,
    required this.onEdit,
    required this.onDelete,
    required this.isDark,
    required this.index,
  });

  @override
  State<EnhancedManifestationCard> createState() => _EnhancedManifestationCardState();
}

class _EnhancedManifestationCardState extends State<EnhancedManifestationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isManifesting = false;
  int _dailyCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _loadDailyCount();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyCount() async {
    final count = await ManifestationWidgetService.getDailyCount(
      widgetId: null, // o usa el ID específico del widget
    );
    if (mounted) {
      setState(() => _dailyCount = count);
    }
  }

  Future<void> _handleManifestation() async {
    if (_isManifesting) return;

    setState(() => _isManifesting = true);

    // Animación de pulso
    _pulseController.forward(from: 0);

    // Registrar manifestación
    await ManifestationWidgetService.recordManifestationVisualization(
      widgetId: null,
    );

    // Actualizar contador
    await _loadDailyCount();

    // Mostrar feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '✨ ¡Manifestación realizada! Total hoy: ${_dailyCount + 1}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() => _isManifesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.manifestation.imageUrl?.isNotEmpty == true
        ? widget.manifestation.imageUrl!
        : 'https://via.placeholder.com/600x400?text=Sin+imagen';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        elevation: 8,
        shadowColor: (widget.isDark ? Colors.deepPurple : Colors.purple)
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (widget.isDark
                      ? Colors.amber.shade300
                      : Colors.deepPurple.shade200)
                  .withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Imagen principal
              AspectRatio(
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
                            color: widget.isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                color: widget.isDark
                                    ? Colors.amber.shade300
                                    : Colors.deepPurple.shade400,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: widget.isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade200,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: widget.isDark
                                    ? Colors.white30
                                    : Colors.black26,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Overlay
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
                              widget.manifestation.title,
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
                            if (widget.manifestation.description?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.manifestation.description!,
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
                              widget.onEdit();
                            } else if (value == 'delete') {
                              widget.onDelete();
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded,
                                      color: widget.isDark
                                          ? Colors.amber.shade300
                                          : Colors.deepPurple.shade400),
                                  const SizedBox(width: 12),
                                  const Text('Editar',
                                      style:
                                          TextStyle(fontWeight: FontWeight.w500)),
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
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseController.value * 0.3);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (widget.isDark
                                        ? Colors.amber.shade300
                                        : Colors.deepPurple.shade400)
                                    .withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (widget.isDark
                                            ? Colors.amber.shade300
                                            : Colors.deepPurple.shade400)
                                        .withOpacity(0.5 + (_pulseController.value * 0.3)),
                                    blurRadius: 8 + (_pulseController.value * 12),
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.auto_awesome,
                                color: widget.isDark ? Colors.black : Colors.white,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 🆕 Barra de acción inferior
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.grey.shade900.withOpacity(0.8)
                      : Colors.grey.shade100,
                  border: Border(
                    top: BorderSide(
                      color: (widget.isDark
                              ? Colors.amber.shade300
                              : Colors.deepPurple.shade200)
                          .withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Contador diario
                    if (_dailyCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.shade700.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$_dailyCount ${_dailyCount == 1 ? "vez" : "veces"} hoy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Botón de manifestar
                    FilledButton.icon(
                      onPressed: _isManifesting ? null : _handleManifestation,
                      icon: _isManifesting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _isManifesting ? 'Manifestando...' : 'Manifestar',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.isDark
                            ? Colors.amber.shade400
                            : Colors.deepPurple.shade500,
                        foregroundColor:
                            widget.isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}