// lib/widgets/shared/woop_victory_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/manifestation_repository.dart';

class WoopVictorySheet extends StatefulWidget {
  final String manifestationId;
  final String title;

  const WoopVictorySheet({
    super.key,
    required this.manifestationId,
    required this.title,
  });

  static void show(BuildContext context, {required String manifestationId, required String title}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WoopVictorySheet(manifestationId: manifestationId, title: title),
    );
  }

  @override
  State<WoopVictorySheet> createState() => _WoopVictorySheetState();
}

class _WoopVictorySheetState extends State<WoopVictorySheet> {
  final _actionController = TextEditingController();
  bool _isLoading = false;
  bool _isSaved = false;

  Future<void> _saveWin() async {
    if (_actionController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await ManifestationRepository().recordWoopWin(
        manifestationId: widget.manifestationId,
        actionTaken: _actionController.text.trim(),
      );

      setState(() {
        _isLoading = false;
        _isSaved = true;
      });
      HapticFeedback.heavyImpact();

      // Cerrar automáticamente después de celebrar
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.of(context).pop();
      });

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar tu victoria.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF12121A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _isSaved ? _buildCelebration(isDark) : _buildForm(isDark),
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.amber.shade400 : Colors.deepPurple.shade500).withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.emoji_events_rounded,
            size: 40,
            color: isDark ? Colors.amber.shade300 : Colors.deepPurple.shade500,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¡Victoria Registrada!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Venciste el obstáculo para "${widget.title}".\n¿Qué pequeña acción tomaste hoy?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _actionController,
          autofocus: true,
          maxLength: 100,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Ej: Transferí \$20.000 a mi cuenta de ahorros...',
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveWin,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: isDark ? Colors.amber.shade400 : Colors.deepPurple.shade500,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : Text(
                  'Guardar Victoria ✨',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCelebration(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Si tienes una animación de lottie de confeti, úsala aquí. Si no, quita este bloque.
        SizedBox(
          height: 150,
          child: Lottie.asset('assets/animations/confetti_celebration.json', repeat: false),
        ),
        const SizedBox(height: 16),
        Text(
          '¡Diario Actualizado!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.amber.shade300 : Colors.deepPurple.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cada pequeña victoria reconfigura tu cerebro.\nEstás un paso más cerca de tu meta.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}