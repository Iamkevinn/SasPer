// lib/widgets/dashboard/ai_analysis_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/services/ai_analysis_service.dart';

// 1. Enum para representar los estados de forma explícita
enum AiAnalysisState { initial, loading, success, error }

class AiAnalysisSection extends StatefulWidget {
  const AiAnalysisSection({super.key});

  @override
  State<AiAnalysisSection> createState() => _AiAnalysisSectionState();
}

class _AiAnalysisSectionState extends State<AiAnalysisSection> {
  // 2. Inyectaríamos la dependencia idealmente, pero la instanciamos aquí por ahora.
  final AiAnalysisService _aiService = AiAnalysisService();

  // 3. El estado ahora se gestiona con el enum y dos variables de datos.
  AiAnalysisState _currentState = AiAnalysisState.initial;
  String? _analysisResult;
  String? _aiErrorMessage;

  Future<void> _fetchAnalysis() async {
    setState(() => _currentState = AiAnalysisState.loading);

    try {
      final result = await _aiService.getFinancialAnalysis();
      if (mounted) {
        setState(() {
          _analysisResult = result;
          _currentState = AiAnalysisState.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiErrorMessage = e.toString().replaceFirst("Exception: ", "");
          _currentState = AiAnalysisState.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu Asistente IA',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // 4. El AnimatedSwitcher da una transición suave entre estados.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCardForCurrentState(),
          ),
        ],
      ),
    );
  }

  // 5. Un único método que devuelve el widget correcto según el estado.
  Widget _buildCardForCurrentState() {
    switch (_currentState) {
      case AiAnalysisState.loading:
        return _buildLoadingCard();
      case AiAnalysisState.error:
        return _buildErrorCard();
      case AiAnalysisState.success:
        return _buildResultCard();
      case AiAnalysisState.initial:
        return _buildInitialPromptCard();
    }
  }

  // --- MÉTODOS BUILDER PARA CADA ESTADO ---

  Widget _buildInitialPromptCard() {
    return Card(
      key: const ValueKey('initial'), // Key para el AnimatedSwitcher
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Iconsax.magic_star, color: Theme.of(context).colorScheme.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              "¿Quieres un resumen inteligente de tus finanzas?",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchAnalysis,
              icon: const Icon(Iconsax.flash_1),
              label: const Text('Generar Análisis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      key: const ValueKey('loading'),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Analizando tus finanzas...", textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      key: const ValueKey('error'),
      elevation: 0,
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Iconsax.warning_2, color: Theme.of(context).colorScheme.onErrorContainer, size: 32),
            const SizedBox(height: 8),
            Text(
              _aiErrorMessage ?? "Ocurrió un error desconocido.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchAnalysis,
              child: Text(
                "Intentar de nuevo",
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      key: const ValueKey('result'),
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Iconsax.magic_star, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  "Análisis Financiero AI",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Iconsax.refresh, size: 20),
                  onPressed: _fetchAnalysis,
                  tooltip: 'Generar nuevo análisis',
                )
              ],
            ),
            const Divider(height: 16),
            MarkdownBody(
              data: _analysisResult!,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, height: 2.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}