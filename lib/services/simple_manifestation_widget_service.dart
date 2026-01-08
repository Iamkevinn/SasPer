import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:sasper/data/manifestation_repository.dart';

/// Permite crear claves separadas por widgetId
String _keyFor(String baseKey, String? widgetId) {
  return widgetId != null ? '${baseKey}_$widgetId' : baseKey;
}

/// Servicio para el widget de Manifestaciones (Vision Focus)
class SimpleManifestationWidgetService  {
  static const String _widgetName = 'ManifestationWidgetProvider';

  // Claves principales
  static const String _keyDartLastUpdate = 'simple_last_update_timestamp';
  static const String keyManifestationsList = 'simple_manifestations_list';
  static const String keyCurrentIndex = 'simple_current_manifestation_index';
  static const String keyTotalCount = 'simple_manifestations_total_count';
  static const String keyCurrentTitle = 'simple_current_title';
  static const String keyCurrentDescription = 'simple_current_description';
  static const String keyCurrentImageUrl = 'simple_current_image_url';
  static const String keyAutoRotate = 'simple_auto_rotate_daily';

  // ===============================================================
  //                INICIALIZACIÓN PRINCIPAL DEL WIDGET
  // ===============================================================
  static Future<void> initializeWidget({String? widgetId}) async {
    try {
      final repository = ManifestationRepository();
      final manifestations = await repository.getManifestations();
      
      if (manifestations.isEmpty) {
        await _setEmptyState(widgetId: widgetId);
        return;
      }
      
      // Guardar timestamp de inicialización
      await HomeWidget.saveWidgetData<int>(
        'simple_last_update_timestamp_$widgetId',
        DateTime.now().millisecondsSinceEpoch,
      );
      
      await saveManifestationsToWidget(
        manifestations,
        widgetId: widgetId,
      );
    } catch (e) {
      developer.log('Error al inicializar widget simple: $e', name: 'SimpleWidget');
      await _setEmptyState(widgetId: widgetId);
    }
  }

  // Guarda todas las manifestaciones en SharedPreferences
  static Future<void> saveManifestationsToWidget(
    List<Manifestation> manifestations, {
    String? widgetId,
  }) async {
    if (manifestations.isEmpty) {
      await _setEmptyState(widgetId: widgetId);
      return;
    }

    final data = manifestations.map((m) {
      return {
        'id': m.id,
        'title': m.title,
        'description': m.description ?? '',
        'image_url': m.imageUrl ?? '',
      };
    }).toList();

    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyManifestationsList, widgetId),
      jsonEncode(data),
    );
    await HomeWidget.saveWidgetData<int>(
      _keyFor(keyTotalCount, widgetId),
      manifestations.length,
    );

    final currentIndex = await _getCurrentIndex(widgetId: widgetId);
    final index = currentIndex < manifestations.length ? currentIndex : 0;

    await _showManifestationAtIndex(
      manifestations,
      index,
      widgetId: widgetId,
    );

    await _checkDailyRotation(manifestations, widgetId: widgetId);
  }

  // ===============================================================
  //                      ACCIONES PRINCIPALES
  // ===============================================================
  static Future<void> showNextManifestation({String? widgetId}) async {
    final list = await _getStoredManifestations(widgetId: widgetId);
    if (list.isEmpty) return;

    final currentIndex = await _getCurrentIndex(widgetId: widgetId);
    final nextIndex = (currentIndex + 1) % list.length;

    await _showManifestationAtIndex(list, nextIndex, widgetId: widgetId);
    
    // 🔥 CAMBIO CRÍTICO: Solo actualizar el widget específico
    await _updateWidget(specificWidgetId: widgetId);
  }

  static Future<void> showPreviousManifestation({String? widgetId}) async {
    final list = await _getStoredManifestations(widgetId: widgetId);
    if (list.isEmpty) return;

    final currentIndex = await _getCurrentIndex(widgetId: widgetId);
    final previous = currentIndex == 0 ? list.length - 1 : currentIndex - 1;

    await _showManifestationAtIndex(list, previous, widgetId: widgetId);
    
    // 🔥 CAMBIO CRÍTICO: Solo actualizar el widget específico
    await _updateWidget(specificWidgetId: widgetId);
  }

  static Future<void> recordManifestationVisualization(
      {String? widgetId}) async {
    final currentIndex = await _getCurrentIndex(widgetId: widgetId);
    final key = 'last_visualization_${currentIndex}_${widgetId ?? "global"}';
    await HomeWidget.saveWidgetData<String>(
        key, DateTime.now().toIso8601String());

    // Activar animación
    await HomeWidget.saveWidgetData<bool>(
      _keyFor('trigger_visualization_animation', widgetId),
      true,
    );
    await _updateWidget(specificWidgetId: widgetId);

    await Future.delayed(const Duration(milliseconds: 500));

    // Desactivar animación
    await HomeWidget.saveWidgetData<bool>(
      _keyFor('trigger_visualization_animation', widgetId),
      false,
    );
    await _updateWidget(specificWidgetId: widgetId);
  }

  // ===============================================================
  //                        MÉTODOS PRIVADOS
  // ===============================================================
  static Future<void> _showManifestationAtIndex(
    List<Manifestation> list,
    int index, {
    String? widgetId,
  }) async {
    if (index < 0 || index >= list.length) return;

    final m = list[index];

    await HomeWidget.saveWidgetData<int>(
      _keyFor(keyCurrentIndex, widgetId),
      index,
    );
    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyCurrentTitle, widgetId),
      m.title,
    );
    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyCurrentDescription, widgetId),
      m.description ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyCurrentImageUrl, widgetId),
      m.imageUrl ?? '',
    );
  }

  static Future<int> _getCurrentIndex({String? widgetId}) async {
    final index = await HomeWidget.getWidgetData<int>(
      _keyFor(keyCurrentIndex, widgetId),
      defaultValue: 0,
    );
    return index ?? 0;
  }

  static Future<List<Manifestation>> _getStoredManifestations(
      {String? widgetId}) async {
    try {
      final jsonStr = await HomeWidget.getWidgetData<String>(
        _keyFor(keyManifestationsList, widgetId),
      );
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List decoded = jsonDecode(jsonStr);
      return decoded.map((e) {
        return Manifestation(
          id: e['id'],
          title: e['title'],
          description: e['description'],
          imageUrl: e['image_url'],
          createdAt: DateTime.now(),
          userId: '',
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error decodificando manifestaciones: $e');
      return [];
    }
  }

  static Future<void> _checkDailyRotation(
    List<Manifestation> list, {
    String? widgetId,
  }) async {
    final autoRotate = await HomeWidget.getWidgetData<bool>(
      _keyFor(keyAutoRotate, widgetId),
      defaultValue: false,
    );
    if (autoRotate != true) return;

    final lastDay = await HomeWidget.getWidgetData<String>(
      _keyFor(_keyDartLastUpdate, widgetId),
    );
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";

    if (lastDay != today) {
      await HomeWidget.saveWidgetData<String>(
        _keyFor(_keyDartLastUpdate, widgetId),
        today,
      );
      await showNextManifestation(widgetId: widgetId);
    }
  }

  static Future<void> _setEmptyState({String? widgetId}) async {
    await HomeWidget.saveWidgetData<int>(
      _keyFor(keyCurrentIndex, widgetId),
      0,
    );
    await HomeWidget.saveWidgetData<int>(
      _keyFor(keyTotalCount, widgetId),
      0,
    );
    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyCurrentTitle, widgetId),
      'Sin manifestaciones',
    );
    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyCurrentDescription, widgetId),
      'Crea tu primera manifestación',
    );
    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyCurrentImageUrl, widgetId),
      '',
    );
    await _updateWidget(specificWidgetId: widgetId);
  }

  // 🔥 CORRECCIÓN DEFINITIVA: Sistema de marcado temporal
   static Future<void> _updateWidget({String? specificWidgetId}) async {
    try {

      await HomeWidget.updateWidget(
        name: _widgetName,
      );
    } catch (e) {
      developer.log('Error al actualizar widget: $e', name: 'WidgetService');
    }
  }

  // ===============================================================
  //        FUNCIÓN PARA EL CALLBACK UNIFICADO DESDE BACKGROUND
  // ===============================================================
  static Future<void> handleWidgetAction(String action,
      [String? widgetId]) async {
    developer.log(
        '🎯 handleWidgetAction llamado: action=$action, widgetId=$widgetId',
        name: 'ManifestationWidget');

    switch (action) {
      case 'initialize':
          await initializeWidget(widgetId: widgetId);
        break;
      case 'next':
        await showNextManifestation(widgetId: widgetId);
        break;
      case 'previous':
        await showPreviousManifestation(widgetId: widgetId);
        break;
      case 'visualize':
        await recordManifestationVisualization(widgetId: widgetId);
        developer.log('Visualize action called on simple widget.', name: 'SimpleWidget');
        break;
      case 'refresh':
        await initializeWidget(widgetId: widgetId);
        break;
      default:
        debugPrint(
            'Acción desconocida de ManifestationWidget: $action (widgetId=$widgetId)');
    }
  }
}

// ===============================================================
//             ESTADÍSTICAS EXTRAS (Opcional)
// ===============================================================
extension ManifestationStats on SimpleManifestationWidgetService  {
  static Future<int> getVisualizationCount(String manifestationId) async {
    final n = await HomeWidget.getWidgetData<int>(
      'visualization_count_$manifestationId',
      defaultValue: 0,
    );
    return n ?? 0;
  }

  static Future<void> incrementVisualizationCount(
      String manifestationId) async {
    final current = await getVisualizationCount(manifestationId);
    await HomeWidget.saveWidgetData<int>(
      'visualization_count_$manifestationId',
      current + 1,
    );
  }
}