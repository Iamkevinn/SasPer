import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;

class WidgetPerformanceTracker {
  static const String _logName = 'WidgetPerformance';
  final Map<String, DateTime> _startTimes = {};
  final Map<String, List<Duration>> _measurements = {};

  /// Inicia el seguimiento de una operación
  void start(String operationId) {
    if (!kDebugMode) return;
    _startTimes[operationId] = DateTime.now();
  }

  /// Finaliza el seguimiento y registra la duración
  void stop(String operationId) {
    if (!kDebugMode) return;
    
    final startTime = _startTimes.remove(operationId);
    if (startTime == null) {
      developer.log(
        '⚠️ No se encontró inicio para: $operationId',
        name: _logName,
      );
      return;
    }

    final duration = DateTime.now().difference(startTime);
    _measurements.putIfAbsent(operationId, () => []).add(duration);

    developer.log(
      '⏱️ $operationId: ${duration.inMilliseconds}ms',
      name: _logName,
    );
  }

  /// Obtiene estadísticas de una operación
  PerformanceStats? getStats(String operationId) {
    if (!kDebugMode) return null;
    
    final measurements = _measurements[operationId];
    if (measurements == null || measurements.isEmpty) return null;

    final totalMs = measurements.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );
    final avgMs = totalMs / measurements.length;
    final maxMs = measurements
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a > b ? a : b);
    final minMs = measurements
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a < b ? a : b);

    return PerformanceStats(
      operationId: operationId,
      count: measurements.length,
      averageMs: avgMs,
      maxMs: maxMs,
      minMs: minMs,
    );
  }

  /// Imprime un resumen de todas las mediciones
  void printSummary() {
    if (!kDebugMode) return;

    developer.log('📊 ===== RESUMEN DE RENDIMIENTO =====', name: _logName);
    for (final operationId in _measurements.keys) {
      final stats = getStats(operationId);
      if (stats != null) {
        developer.log(
          '  $operationId: avg=${stats.averageMs.toStringAsFixed(1)}ms, '
          'min=${stats.minMs}ms, max=${stats.maxMs}ms (n=${stats.count})',
          name: _logName,
        );
      }
    }
    developer.log('====================================', name: _logName);
  }

  /// Limpia todas las mediciones
  void clear() {
    _startTimes.clear();
    _measurements.clear();
  }
}

class PerformanceStats {
  final String operationId;
  final int count;
  final double averageMs;
  final int maxMs;
  final int minMs;

  PerformanceStats({
    required this.operationId,
    required this.count,
    required this.averageMs,
    required this.maxMs,
    required this.minMs,
  });
}