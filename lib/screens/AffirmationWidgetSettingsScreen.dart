import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sasper/services/affirmation_widget_service.dart';

/// 🎨 Pantalla de configuración del widget de afirmaciones
class AffirmationWidgetSettingsScreen extends StatefulWidget {
  const AffirmationWidgetSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AffirmationWidgetSettingsScreen> createState() =>
      _AffirmationWidgetSettingsScreenState();
}

class _AffirmationWidgetSettingsScreenState
    extends State<AffirmationWidgetSettingsScreen> {
  int _selectedTheme = 0;
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final stats = await AffirmationWidgetService.getFocusStatistics();

    setState(() {
      _statistics = stats;
      _isLoading = false;
    });
  }

  Future<void> _changeTheme(int themeIndex) async {
    HapticFeedback.selectionClick();
    setState(() => _selectedTheme = themeIndex);

    await AffirmationWidgetService.setColorTheme(themeIndex);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.palette, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Tema "${AffirmationWidgetService.colorThemes[themeIndex]['name']}" aplicado',
              ),
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

  Future<void> _refreshWidget() async {
    HapticFeedback.mediumImpact();
    await AffirmationWidgetService.initializeWidget();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Widget actualizado correctamente'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget de Afirmaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar widget',
            onPressed: _refreshWidget,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sección: Cómo funciona
                  _buildInfoCard(theme, isDark),

                  const SizedBox(height: 24),

                  // Sección: Estadísticas
                  _buildStatisticsCard(theme, isDark),

                  const SizedBox(height: 24),

                  // Sección: Temas de color
                  _buildThemesSection(theme, isDark),

                  const SizedBox(height: 24),

                  // Sección: Enfoques de afirmación
                  _buildAffirmationTypesInfo(theme, isDark),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: isDark
                      ? Colors.amber.shade300
                      : Colors.deepPurple.shade400,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Cómo usar el widget',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoItem('◀ ▶', 'Navega entre tus manifestaciones'),
            _buildInfoItem('🔄', 'Cambia el enfoque de la afirmación'),
            _buildInfoItem('✨', 'Toca el texto para "Momento de Enfoque"'),
            _buildInfoItem('📱', 'Abre la app para gestionar manifestaciones'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String icon, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme, bool isDark) {
    final totalFocus = _statistics['total_focus_count'] ?? 0;
    final weeklyFocus = _statistics['weekly_focus_count'] ?? 0;
    final lastFocus = _statistics['last_focus_date'] as String?;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark
          ? Colors.deepPurple.shade900.withOpacity(0.3)
          : Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up_rounded,
                  color: isDark
                      ? Colors.amber.shade300
                      : Colors.deepPurple.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tu Progreso',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    theme,
                    isDark,
                    'Total',
                    totalFocus.toString(),
                    Icons.auto_awesome,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatBox(
                    theme,
                    isDark,
                    'Esta semana',
                    weeklyFocus.toString(),
                    Icons.calendar_today,
                  ),
                ),
              ],
            ),
            if (lastFocus != null) ...[
              const SizedBox(height: 16),
              Text(
                'Último enfoque: $lastFocus',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: weeklyFocus / 7,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              weeklyFocus >= 7
                  ? '🎉 ¡Meta semanal alcanzada!'
                  : 'Meta: 7 enfoques esta semana',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: weeklyFocus >= 7
                    ? (isDark ? Colors.amber.shade300 : Colors.green.shade600)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(
    ThemeData theme,
    bool isDark,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.amber.shade300 : Colors.deepPurple.shade300)
              .withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
                isDark ? Colors.amber.shade300 : Colors.deepPurple.shade400,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color:
                  isDark ? Colors.amber.shade300 : Colors.deepPurple.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildThemesSection(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temas de Color',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2,
          ),
          itemCount: AffirmationWidgetService.colorThemes.length,
          itemBuilder: (context, index) {
            final colorTheme = AffirmationWidgetService.colorThemes[index];
            final isSelected = _selectedTheme == index;

            return GestureDetector(
              onTap: () => _changeTheme(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(int.parse(
                          colorTheme['gradient_start']!.replaceAll('#', '0xFF'))),
                      Color(int.parse(
                          colorTheme['gradient_end']!.replaceAll('#', '0xFF'))),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    colorTheme['name']!,
                    style: TextStyle(
                      color: Color(int.parse(
                          colorTheme['text_color']!.replaceAll('#', '0xFF'))),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAffirmationTypesInfo(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enfoques de Afirmación',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...AffirmationWidgetService.affirmationTemplates.map((template) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.template.replaceAll(
                              '{meta}',
                              '[tu meta]',
                            ),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
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
        }).toList(),
      ],
    );
  }
}