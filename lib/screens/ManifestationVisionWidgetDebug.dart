import 'package:flutter/material.dart';
import 'package:sasper/services/manifestation_widget_service.dart';

/// Widget de debug para ver estadísticas del widget de manifestaciones
class ManifestationWidgetDebug extends StatefulWidget {
  final String? widgetId;
  
  const ManifestationWidgetDebug({
    Key? key,
    this.widgetId,
  }) : super(key: key);

  @override
  State<ManifestationWidgetDebug> createState() => _ManifestationWidgetDebugState();
}

class _ManifestationWidgetDebugState extends State<ManifestationWidgetDebug> {
  int _dailyCount = 0;
  int _totalCount = 0;
  Map<String, int> _history = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    
    try {
      final dailyCount = await ManifestationWidgetService.getDailyCount(
        widgetId: widget.widgetId,
      );
      
      final totalCount = await ManifestationStats.getTotalManifestations(
        widgetId: widget.widgetId,
      );
      
      final history = await ManifestationStats.getManifestationHistory(
        widgetId: widget.widgetId,
        daysBack: 7,
      );
      
      setState(() {
        _dailyCount = dailyCount;
        _totalCount = totalCount;
        _history = history;
        _loading = false;
      });
    } catch (e) {
      print('Error cargando estadísticas: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _triggerManifestation() async {
    await ManifestationWidgetService.recordManifestationVisualization(
      widgetId: widget.widgetId,
    );
    await _loadStats();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ ¡Manifestación realizada!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _resetCounter() async {
    await ManifestationWidgetService.resetDailyCount(
      widgetId: widget.widgetId,
    );
    await _loadStats();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Contador reseteado'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '📊 Estadísticas del Widget',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Contador del día
                  _StatRow(
                    icon: '✨',
                    label: 'Manifestaciones hoy',
                    value: '$_dailyCount',
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 8),
                  
                  // Total últimos 30 días
                  _StatRow(
                    icon: '📈',
                    label: 'Total (30 días)',
                    value: '$_totalCount',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  
                  // Historial de 7 días
                  Text(
                    'Últimos 7 días',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  
                  ..._history.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: entry.value > 0 
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: entry.value > 0 
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _triggerManifestation,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Manifestar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetCounter,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadStats,
                      icon: const Icon(Icons.sync),
                      label: const Text('Actualizar Estadísticas'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}