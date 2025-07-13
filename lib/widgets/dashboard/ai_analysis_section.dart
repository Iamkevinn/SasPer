import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/ai_analysis_service.dart'; // Asegúrate de que la ruta sea correcta

class AiAnalysisSection extends StatefulWidget {
  const AiAnalysisSection({super.key});

  @override
  State<AiAnalysisSection> createState() => _AiAnalysisSectionState();
}

class _AiAnalysisSectionState extends State<AiAnalysisSection> {
  final AiAnalysisService _aiService = AiAnalysisService();
  String? _analysisResult;
  bool _isAiLoading = false;
  String? _aiErrorMessage;

  void _fetchAnalysis() async {
    setState(() {
      _isAiLoading = true;
      _aiErrorMessage = null;
      _analysisResult = null;
    });

    try {
      final result = await _aiService.getFinancialAnalysis();
      if (mounted) {
        setState(() => _analysisResult = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiErrorMessage = 'Error al obtener análisis: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
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
          if (_analysisResult == null)
            _buildAiPromptCard()
          else
            _buildAiResultCard(),
        ],
      ),
    );
  }

  Widget _buildAiPromptCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            if (_isAiLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Analizando tus finanzas...", textAlign: TextAlign.center),
                ],
              )
            else if (_aiErrorMessage != null)
              Column(
                children: [
                  Icon(Iconsax.warning_2, color: Theme.of(context).colorScheme.error, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    _aiErrorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _fetchAnalysis, child: const Text("Intentar de nuevo")),
                ],
              )
            else
              Column(
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
          ],
        ),
      ),
    );
  }

  Widget _buildAiResultCard() {
    return Card(
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
              ],
            ),
            const Divider(height: 24),
            MarkdownBody(
              data: _analysisResult!,
              styleSheet: MarkdownStyleSheet(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, height: 2.0),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                listBullet: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}