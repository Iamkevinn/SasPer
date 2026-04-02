import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:sasper/screens/edit_manifestation_screen.dart';

/// Misma paleta que [ManifestationsScreen] para coherencia premium.
abstract class _DetailTokens {
  static const Color ink = Color(0xFF0A0A0F);
  static const Color surfaceElevated = Color(0xFF1C1C28);
  static const Color border = Color(0xFF2A2A38);
  static const Color primary = Color(0xFFE8D5B7);
  static const Color accent = Color(0xFFC9A96E);
  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFF8A8699);
  static const String fontDisplay = 'Georgia';
}

class ManifestationDetailScreen extends StatelessWidget {
  final Manifestation manifestation;

  const ManifestationDetailScreen({super.key, required this.manifestation});

  Future<void> _openEdit(BuildContext context) async {
    HapticFeedback.lightImpact();
    final updated = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditManifestationScreen(manifestation: manifestation),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
    if (updated == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = manifestation.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: _DetailTokens.ink,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: hasImage ? 320 : 120,
            pinned: true,
            backgroundColor: _DetailTokens.ink,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: _DetailTokens.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? Hero(
                      tag: 'manifestation_image_${manifestation.id}',
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _DetailTokens.surfaceElevated,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: _DetailTokens.textSecondary,
                                size: 48,
                              ),
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _DetailTokens.ink.withOpacity(0.2),
                                  _DetailTokens.ink.withOpacity(0.85),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: _DetailTokens.surfaceElevated,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.auto_awesome_outlined,
                        color: _DetailTokens.accent,
                        size: 40,
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    manifestation.title,
                    style: const TextStyle(
                      fontFamily: _DetailTokens.fontDisplay,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _DetailTokens.textPrimary,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (manifestation.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      manifestation.description!.trim(),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: _DetailTokens.textSecondary,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const _SectionLabel(
                    label: 'Resultado',
                    step: 'WOOP · 2',
                  ),
                  const SizedBox(height: 8),
                  _WoopBodyText(
                    text: manifestation.outcome?.trim(),
                    emptyHint:
                        'Aún no definiste el mejor resultado. Edita para completar tu plan.',
                  ),
                  const SizedBox(height: 24),
                  const _SectionLabel(
                    label: 'Obstáculo interno',
                    step: 'WOOP · 3',
                  ),
                  const SizedBox(height: 8),
                  _WoopBodyText(
                    text: manifestation.obstacle?.trim(),
                    emptyHint:
                        'Nombrar el obstáculo te da poder sobre él. Complétalo al editar.',
                  ),
                  const SizedBox(height: 24),
                  const _SectionLabel(
                    label: 'Plan si — entonces',
                    step: 'WOOP · 4',
                  ),
                  const SizedBox(height: 8),
                  _WoopBodyText(
                    text: manifestation.plan?.trim(),
                    emptyHint:
                        'Tu regla «si… entonces…» aparecerá aquí cuando la escribas.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            onPressed: () => _openEdit(context),
            style: FilledButton.styleFrom(
              backgroundColor: _DetailTokens.primary,
              foregroundColor: _DetailTokens.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Editar manifestación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final String step;

  const _SectionLabel({required this.label, required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: _DetailTokens.accent,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _DetailTokens.border),
            color: _DetailTokens.surfaceElevated,
          ),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: _DetailTokens.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _WoopBodyText extends StatelessWidget {
  final String? text;
  final String emptyHint;

  const _WoopBodyText({required this.text, required this.emptyHint});

  @override
  Widget build(BuildContext context) {
    final t = text?.trim();
    if (t == null || t.isEmpty) {
      return Text(
        emptyHint,
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          fontStyle: FontStyle.italic,
          color: _DetailTokens.textSecondary.withOpacity(0.85),
        ),
      );
    }
    return Text(
      t,
      style: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: _DetailTokens.textPrimary,
        letterSpacing: 0.1,
      ),
    );
  }
}
