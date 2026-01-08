import 'dart:convert';
import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:sasper/data/manifestation_repository.dart';

/// 🌟 SERVICIO PARA EL WIDGET "FOCUS DE AFIRMACIÓN"
class AffirmationWidgetService {
  static const String _widgetName = 'AffirmationFocusWidget';

  // Claves base para SharedPreferences (se usan con _keyFor)
  static const String keyManifestationsList = 'affirmation_manifestations_list';
  static const String keyCurrentIndex = 'affirmation_current_index';
  static const String keyCurrentAffirmationType = 'affirmation_type_index';
  static const String keyTotalCount = 'affirmation_total_count';
  static const String keyAffirmationTypeName = "affirmation_type_name";
  static const String keyAffirmationTypeIcon = "affirmation_type_icon";
  static const String keyCurrentTitle = 'affirmation_current_title';
  static const String keyCurrentAffirmation = 'affirmation_current_text';
  static const String keyFocusCount = 'affirmation_focus_count';
  static const String keyLastFocusDate = 'affirmation_last_focus_date';
  static const String keyWeeklyFocusCount = 'affirmation_weekly_focus_count';
  static const String keyColorTheme = 'affirmation_color_theme';

  // Temas de color disponibles
  static const List<Map<String, String>> colorThemes = [
    {
      'name': 'Serenidad',
      'gradient_start': '#4A90E2',
      'gradient_end': '#50E3C2',
      'text_color': '#FFFFFF',
    },
    {
      'name': 'Energía',
      'gradient_start': '#FF6B6B',
      'gradient_end': '#FFD93D',
      'text_color': '#2C3E50',
    },
    {
      'name': 'Misterio',
      'gradient_start': '#8E44AD',
      'gradient_end': '#3498DB',
      'text_color': '#FFFFFF',
    },
    {
      'name': 'Aurora',
      'gradient_start': '#FF6B9D',
      'gradient_end': '#C06C84',
      'text_color': '#FFFFFF',
    },
  ];

  // Plantillas de afirmaciones por enfoque
  static const List<AffirmationTemplate> affirmationTemplates = [
    AffirmationTemplate(
      type: AffirmationType.gratitude,
      template: 'Estoy tan feliz y agradecido/a por {meta}',
      icon: '🙏',
      name: 'Gratitud',
    ),
    AffirmationTemplate(
      type: AffirmationType.present,
      template: 'Disfruto cada día de {meta}',
      icon: '✨',
      name: 'Presente',
    ),
    AffirmationTemplate(
      type: AffirmationType.trust,
      template: 'Confío en que el universo me provee {meta}',
      icon: '🌌',
      name: 'Confianza',
    ),
    AffirmationTemplate(
      type: AffirmationType.openness,
      template: 'Estoy abierto/a y listo/a para recibir {meta}',
      icon: '🌟',
      name: 'Apertura',
    ),
  ];

  // -------------------------
  // Helper para claves por widget
  // -------------------------
  static String _keyFor(String baseKey, String? widgetId) {
    return widgetId != null ? '${baseKey}_$widgetId' : baseKey;
  }

  /// Inicializa el widget con todas las manifestaciones
  static Future<void> initializeWidget({String? widgetId}) async {
    try {
      final repository = ManifestationRepository();
      final manifestations = await repository.getManifestations();

      if (manifestations.isEmpty) {
        await _setEmptyState(widgetId: widgetId);
        return;
      }

      await saveManifestationsToWidget(manifestations, widgetId: widgetId);
    } catch (e) {
      print('⚠️ Error inicializando widget de afirmaciones: $e');
      await _setEmptyState(widgetId: widgetId);
    }
  }

  /// Guarda todas las manifestaciones y configura el widget
  static Future<void> saveManifestationsToWidget(
    List<Manifestation> manifestations, {
    String? widgetId,
  }) async {
    if (manifestations.isEmpty) {
      await _setEmptyState(widgetId: widgetId);
      return;
    }

    final List<Map<String, dynamic>> widgetDataList =
        manifestations.map((m) {
      return {
        'id': m.id,
        'title': m.title,
      };
    }).toList();

    final String jsonStringList = jsonEncode(widgetDataList);

    await HomeWidget.saveWidgetData<String>(
      _keyFor(keyManifestationsList, widgetId),
      jsonStringList,
    );
    await HomeWidget.saveWidgetData<int>(
      _keyFor(keyTotalCount, widgetId),
      manifestations.length,
    );

    final currentManifestationIndex =
        await _getCurrentManifestationIndex(widgetId: widgetId);
    final currentAffirmationType =
        await _getCurrentAffirmationType(widgetId: widgetId);

    final validManifestationIndex =
        currentManifestationIndex < manifestations.length
            ? currentManifestationIndex
            : 0;
    final validAffirmationType =
        currentAffirmationType < affirmationTemplates.length
            ? currentAffirmationType
            : 0;

    await _showAffirmationAtIndex(
      manifestations,
      validManifestationIndex,
      validAffirmationType,
      widgetId: widgetId,
    );

    final currentTheme = await _getCurrentTheme(widgetId: widgetId);
    await _applyColorTheme(currentTheme, widgetId: widgetId);
  }

  /// Siguiente afirmación
  static Future<void> showNextManifestation({String? widgetId}) async {
    final manifestations = await _getStoredManifestations(widgetId: widgetId);
    if (manifestations.isEmpty) return;

    final currentIndex =
        await _getCurrentManifestationIndex(widgetId: widgetId);
    final nextIndex = (currentIndex + 1) % manifestations.length;

    final currentAffirmationType =
        await _getCurrentAffirmationType(widgetId: widgetId);

    await _showAffirmationAtIndex(
      manifestations,
      nextIndex,
      currentAffirmationType,
      widgetId: widgetId,
    );
    
    // 🔥 CAMBIO CRÍTICO
    await _updateWidget(specificWidgetId: widgetId);
  }

  /// Anterior afirmación
  static Future<void> showPreviousManifestation({String? widgetId}) async {
    final manifestations = await _getStoredManifestations(widgetId: widgetId);
    if (manifestations.isEmpty) return;

    final currentIndex =
        await _getCurrentManifestationIndex(widgetId: widgetId);
    final previousIndex =
        currentIndex == 0 ? manifestations.length - 1 : currentIndex - 1;

    final currentAffirmationType =
        await _getCurrentAffirmationType(widgetId: widgetId);

    await _showAffirmationAtIndex(
      manifestations,
      previousIndex,
      currentAffirmationType,
      widgetId: widgetId,
    );
    
    // 🔥 CAMBIO CRÍTICO
    await _updateWidget(specificWidgetId: widgetId);
  }

  /// Rotar tipo de afirmación
  static Future<void> rotateAffirmationType({String? widgetId}) async {
    final manifestations = await _getStoredManifestations(widgetId: widgetId);
    if (manifestations.isEmpty) return;

    final currentManifestationIndex =
        await _getCurrentManifestationIndex(widgetId: widgetId);
    final currentAffirmationType =
        await _getCurrentAffirmationType(widgetId: widgetId);

    final nextType = (currentAffirmationType + 1) % affirmationTemplates.length;

    await _showAffirmationAtIndex(
      manifestations,
      currentManifestationIndex,
      nextType,
      widgetId: widgetId,
    );
    
    // 🔥 CAMBIO CRÍTICO
    await _updateWidget(specificWidgetId: widgetId);
  }

  /// Registra un "momento de enfoque"
  static Future<void> recordFocusMoment({String? widgetId}) async {
    final currentCount = await _getFocusCount(widgetId: widgetId);
    await HomeWidget.saveWidgetData<int>(
        _keyFor(keyFocusCount, widgetId), currentCount + 1);

    final today = DateTime.now();
    final todayString = '${today.year}-${today.month}-${today.day}';
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyLastFocusDate, widgetId), todayString);

    await _incrementWeeklyFocusCount(widgetId: widgetId);

    await HomeWidget.saveWidgetData<bool>(
        _keyFor('trigger_focus_animation', widgetId), true);
    await _updateWidget(specificWidgetId: widgetId);

    await Future.delayed(const Duration(milliseconds: 800));

    await HomeWidget.saveWidgetData<bool>(
        _keyFor('trigger_focus_animation', widgetId), false);
    await _updateWidget(specificWidgetId: widgetId);
  }

  /// Cambia el tema del widget
  static Future<void> setColorTheme(int themeIndex, {String? widgetId}) async {
    if (themeIndex < 0 || themeIndex >= colorThemes.length) return;

    await HomeWidget.saveWidgetData<int>(
        _keyFor(keyColorTheme, widgetId), themeIndex);
    await _applyColorTheme(themeIndex, widgetId: widgetId);
    await _updateWidget(specificWidgetId: widgetId);
  }

  /// Estadísticas de enfoque
  static Future<Map<String, dynamic>> getFocusStatistics(
      {String? widgetId}) async {
    final totalFocus = await _getFocusCount(widgetId: widgetId);
    final weeklyFocus = await _getWeeklyFocusCount(widgetId: widgetId);
    final lastFocusDate = await HomeWidget.getWidgetData<String>(
        _keyFor(keyLastFocusDate, widgetId));

    return {
      'total_focus_count': totalFocus,
      'weekly_focus_count': weeklyFocus,
      'last_focus_date': lastFocusDate,
    };
  }

  // -------------------------
  // Métodos privados
  // -------------------------
  static Future<void> _showAffirmationAtIndex(
    List<Manifestation> manifestations,
    int manifestationIndex,
    int affirmationTypeIndex, {
    String? widgetId,
  }) async {
    if (manifestationIndex < 0 ||
        manifestationIndex >= manifestations.length) return;
    if (affirmationTypeIndex < 0 ||
        affirmationTypeIndex >= affirmationTemplates.length) return;

    final manifestation = manifestations[manifestationIndex];
    final template = affirmationTemplates[affirmationTypeIndex];

    final affirmationText = template.template.replaceAll(
      '{meta}',
      manifestation.title.toLowerCase(),
    );

    await HomeWidget.saveWidgetData<int>(
        _keyFor(keyCurrentIndex, widgetId), manifestationIndex);
    await HomeWidget.saveWidgetData<int>(
        _keyFor(keyCurrentAffirmationType, widgetId), affirmationTypeIndex);
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyCurrentTitle, widgetId), manifestation.title);
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyCurrentAffirmation, widgetId), affirmationText);
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyAffirmationTypeName, widgetId), template.name);
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyAffirmationTypeIcon, widgetId), template.icon);
  }

  static Future<void> _applyColorTheme(int themeIndex,
      {String? widgetId}) async {
    if (themeIndex < 0 || themeIndex >= colorThemes.length) return;

    final theme = colorThemes[themeIndex];
    await HomeWidget.saveWidgetData<String>(
        _keyFor('theme_gradient_start', widgetId), theme['gradient_start']!);
    await HomeWidget.saveWidgetData<String>(
        _keyFor('theme_gradient_end', widgetId), theme['gradient_end']!);
    await HomeWidget.saveWidgetData<String>(
        _keyFor('theme_text_color', widgetId), theme['text_color']!);
  }

  static Future<int> _getCurrentManifestationIndex(
      {String? widgetId}) async {
    try {
      final index = await HomeWidget.getWidgetData<int>(
          _keyFor(keyCurrentIndex, widgetId),
          defaultValue: 0);
      return index ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _getCurrentAffirmationType({String? widgetId}) async {
    try {
      final type = await HomeWidget.getWidgetData<int>(
          _keyFor(keyCurrentAffirmationType, widgetId),
          defaultValue: 0);
      return type ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _getCurrentTheme({String? widgetId}) async {
    try {
      final theme = await HomeWidget.getWidgetData<int>(
          _keyFor(keyColorTheme, widgetId),
          defaultValue: 0);
      return theme ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _getFocusCount({String? widgetId}) async {
    try {
      final count = await HomeWidget.getWidgetData<int>(
          _keyFor(keyFocusCount, widgetId),
          defaultValue: 0);
      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> _getWeeklyFocusCount({String? widgetId}) async {
    try {
      final count = await HomeWidget.getWidgetData<int>(
          _keyFor(keyWeeklyFocusCount, widgetId),
          defaultValue: 0);
      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<void> _incrementWeeklyFocusCount({String? widgetId}) async {
    final currentCount = await _getWeeklyFocusCount(widgetId: widgetId);
    await HomeWidget.saveWidgetData<int>(
        _keyFor(keyWeeklyFocusCount, widgetId), currentCount + 1);
  }

  static Future<List<Manifestation>> _getStoredManifestations(
      {String? widgetId}) async {
    try {
      final jsonString = await HomeWidget.getWidgetData<String>(
          _keyFor(keyManifestationsList, widgetId));
      if (jsonString == null || jsonString.isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) {
        return Manifestation(
          id: json['id'] as String,
          userId: '',
          title: json['title'] as String,
          createdAt: DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('Error al recuperar manifestaciones: $e');
      return [];
    }
  }

  static Future<void> _setEmptyState({String? widgetId}) async {
    await HomeWidget.saveWidgetData<int>(_keyFor(keyCurrentIndex, widgetId), 0);
    await HomeWidget.saveWidgetData<int>(
        _keyFor(keyCurrentAffirmationType, widgetId), 0);
    await HomeWidget.saveWidgetData<int>(_keyFor(keyTotalCount, widgetId), 0);
    await HomeWidget.saveWidgetData<String>(
        _keyFor(keyCurrentTitle, widgetId), 'tus metas');
    await HomeWidget.saveWidgetData<String>(_keyFor(keyCurrentAffirmation, widgetId),
        'Crea tu primera manifestación en la app');

    await _applyColorTheme(0, widgetId: widgetId);
    await _updateWidget(specificWidgetId: widgetId);
  }

  // 🔥 CORRECCIÓN DEFINITIVA: Sistema de marcado temporal
  static Future<void> _updateWidget({String? specificWidgetId}) async {
    try {

      await HomeWidget.updateWidget(androidName: _widgetName, iOSName: _widgetName);
    } catch (e) {
      print('Error al actualizar widget: $e');
    }
  }

  /// Maneja acciones desde el callback nativo
  static Future<void> handleWidgetAction(String action, [String? widgetId]) async {
    developer.log(
      '🎯 handleWidgetAction: action=$action, widgetId=$widgetId',
      name: 'AffirmationWidget',
    );
    
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
      case 'rotate':
        await rotateAffirmationType(widgetId: widgetId);
        break;
      case 'focus':
        await recordFocusMoment(widgetId: widgetId);
        break;
      case 'refresh':
        await initializeWidget(widgetId: widgetId);
        break;
      default:
        developer.log(
          'Acción desconocida de AffirmationWidget: $action (widgetId=$widgetId)',
          name: 'AffirmationWidget',
        );
    }
  }
}

// MODELOS AUXILIARES
enum AffirmationType { gratitude, present, trust, openness }

class AffirmationTemplate {
  final AffirmationType type;
  final String template;
  final String icon;
  final String name;

  const AffirmationTemplate({
    required this.type,
    required this.template,
    required this.icon,
    required this.name,
  });
}