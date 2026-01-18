import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:sasper/data/manifestation_repository.dart';
import 'package:intl/intl.dart';

/// Permite crear claves separadas por widgetId
String _keyFor(String baseKey, String? widgetId) {
  return widgetId != null ? '${baseKey}_$widgetId' : baseKey;
}

/// Servicio para el widget de Manifestaciones (Vision Focus)
class ManifestationWidgetService {
  static const String _widgetName = 'ManifestationVisionWidget';

  // Claves principales
  static const String keyManifestationsList = 'vision_manifestations_list';
  static const String keyCurrentIndex = 'vision_current_manifestation_index';
  static const String keyTotalCount = 'vision_manifestations_total_count';
  static const String keyCurrentTitle = 'vision_current_title';
  static const String keyCurrentDescription = 'vision_current_description';
  static const String keyCurrentImageUrl = 'vision_current_image_url';
  static const String keyLastUpdateDate = 'vision_last_update_date';
  static const String keyAutoRotate = 'vision_auto_rotate_daily';
  
  // 🆕 Claves para el contador diario y animación
  static const String keyDailyCountPrefix = 'vision_daily_count_';
  static const String keyLastCountDate = 'vision_last_count_date';
  static const String keyTriggerAnimation = 'vision_trigger_animation';

  // 🆕 Obtener la fecha actual en formato "yyyy-MM-dd"
  static String _getCurrentDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // ===============================================================
  //                INICIALIZACIÓN PRINCIPAL DEL WIDGET
  // ===============================================================
  static Future<void> initializeWidget({String? widgetId}) async {
    final repository = ManifestationRepository();
    final manifestations = await repository.getManifestations();

    if (manifestations.isEmpty) {
      await _setEmptyState(widgetId: widgetId);
      return;
    }

    await saveManifestationsToWidget(
      manifestations,
      widgetId: widgetId,
    );
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
    
    // Actualizar el widget específico
    await _updateWidget(specificWidgetId: widgetId);
  }

  static Future<void> showPreviousManifestation({String? widgetId}) async {
    final list = await _getStoredManifestations(widgetId: widgetId);
    if (list.isEmpty) return;

    final currentIndex = await _getCurrentIndex(widgetId: widgetId);
    final previous = currentIndex == 0 ? list.length - 1 : currentIndex - 1;

    await _showManifestationAtIndex(list, previous, widgetId: widgetId);
    
    // Actualizar el widget específico
    await _updateWidget(specificWidgetId: widgetId);
  }

  // 🆕 ✨ FUNCIÓN ACTUALIZADA PARA MANEJAR LA VISUALIZACIÓN/MANIFESTACIÓN
  static Future<void> recordManifestationVisualization({String? widgetId}) async {
    try {
      final currentIndex = await _getCurrentIndex(widgetId: widgetId);
      final currentDate = _getCurrentDate();
      
      // 🔑 Construir clave única para manifestación + fecha + widget
      final countKey = _keyFor('${keyDailyCountPrefix}${currentIndex}_$currentDate', widgetId);
      
      // Obtener contador actual
      final currentCount = await HomeWidget.getWidgetData<int>(countKey, defaultValue: 0) ?? 0;
      final newCount = currentCount + 1;
      
      // 💾 Guardar nuevo contador
      await HomeWidget.saveWidgetData<int>(countKey, newCount);
      
      // 💾 Guardar fecha actual
      await HomeWidget.saveWidgetData<String>(
        _keyFor(keyLastCountDate, widgetId),
        currentDate,
      );
      
      // 🎨 Activar animación
      await HomeWidget.saveWidgetData<bool>(
        _keyFor(keyTriggerAnimation, widgetId),
        true,
      );
      
      developer.log(
        '✨ Manifestación registrada: $newCount veces hoy (widgetId: $widgetId, index: $currentIndex)',
        name: 'ManifestationWidget',
      );
      
      // 🔄 Actualizar widget para mostrar contador y animación
      await _updateWidget(specificWidgetId: widgetId);
      
    } catch (e) {
      developer.log(
        '❌ Error al registrar visualización: $e',
        name: 'ManifestationWidget',
      );
    }
  }

  // 🆕 Obtener el contador diario actual para una manifestación
  static Future<int> getDailyCount({required String? widgetId}) async {
    try {
      final currentIndex = await _getCurrentIndex(widgetId: widgetId);
      final currentDate = _getCurrentDate();
      final countKey = _keyFor('${keyDailyCountPrefix}${currentIndex}_$currentDate', widgetId);
      
      final count = await HomeWidget.getWidgetData<int>(countKey, defaultValue: 0) ?? 0;
      return count;
    } catch (e) {
      developer.log('❌ Error obteniendo contador diario: $e', name: 'ManifestationWidget');
      return 0;
    }
  }

  // 🆕 Resetear contador diario (útil para testing o ajustes manuales)
  static Future<void> resetDailyCount({required String? widgetId}) async {
    try {
      final currentIndex = await _getCurrentIndex(widgetId: widgetId);
      final currentDate = _getCurrentDate();
      final countKey = _keyFor('${keyDailyCountPrefix}${currentIndex}_$currentDate', widgetId);
      
      await HomeWidget.saveWidgetData<int>(countKey, 0);
      await _updateWidget(specificWidgetId: widgetId);
      
      developer.log('🔄 Contador diario reseteado', name: 'ManifestationWidget');
    } catch (e) {
      developer.log('❌ Error reseteando contador: $e', name: 'ManifestationWidget');
    }
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
      _keyFor(keyLastUpdateDate, widgetId),
    );
    final now = DateTime.now();
    final today = "${now.year}-${now.month}-${now.day}";

    if (lastDay != today) {
      await HomeWidget.saveWidgetData<String>(
        _keyFor(keyLastUpdateDate, widgetId),
        today,
      );
      await showNextManifestation(widgetId: widgetId);
    }
  }

  static Future<void> _setEmptyState({String? widgetId}) async {
    await HomeWidget.saveWidgetData<int>(_keyFor(keyCurrentIndex, widgetId), 0);
    await HomeWidget.saveWidgetData<int>(_keyFor(keyTotalCount, widgetId), 0);
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyCurrentTitle, widgetId), 'Sin manifestaciones');
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyCurrentDescription, widgetId),
        'Crea tu primera manifestación');
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyCurrentImageUrl, widgetId), '');
    await _updateWidget(specificWidgetId: widgetId);
  }

  static Future<void> _updateWidget({String? specificWidgetId}) async {
    try {
      await HomeWidget.updateWidget(
        androidName: _widgetName,
        iOSName: _widgetName,
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
//             ESTADÍSTICAS EXTRAS (Mejoradas)
// ===============================================================
extension ManifestationStats on ManifestationWidgetService {
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
  
  // 🆕 Obtener estadísticas de manifestaciones por día
  static Future<Map<String, int>> getManifestationHistory({
    required String? widgetId,
    int daysBack = 7,
  }) async {
    final Map<String, int> history = {};
    final now = DateTime.now();
    
    for (int i = 0; i < daysBack; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      // Obtener índice actual (o podrías iterar por todos)
      final currentIndex = await ManifestationWidgetService._getCurrentIndex(widgetId: widgetId);
      final countKey = _keyFor('${ManifestationWidgetService.keyDailyCountPrefix}${currentIndex}_$dateStr', widgetId);
      
      final count = await HomeWidget.getWidgetData<int>(countKey, defaultValue: 0) ?? 0;
      history[dateStr] = count;
    }
    
    return history;
  }
  
  // 🆕 Obtener total de manifestaciones realizadas
  static Future<int> getTotalManifestations({required String? widgetId}) async {
    int total = 0;
    final now = DateTime.now();
    
    // Revisar últimos 30 días
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final currentIndex = await ManifestationWidgetService._getCurrentIndex(widgetId: widgetId);
      final countKey = _keyFor('${ManifestationWidgetService.keyDailyCountPrefix}${currentIndex}_$dateStr', widgetId);
      
      final count = await HomeWidget.getWidgetData<int>(countKey, defaultValue: 0) ?? 0;
      total += count;
    }
    
    return total;
  }
}