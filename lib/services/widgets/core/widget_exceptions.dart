import 'package:sasper/services/widgets/core/widget_types.dart';

/// Excepción base para errores de widgets
abstract class WidgetException implements Exception {
  final String message;
  final WidgetType? widgetType;
  final dynamic originalError;
  final StackTrace? stackTrace;

  WidgetException(
    this.message, {
    this.widgetType,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (widgetType != null) buffer.write(' [Widget: ${widgetType!.name}]');
    if (originalError != null) buffer.write('\nCaused by: $originalError');
    return buffer.toString();
  }
}

class WidgetRenderException extends WidgetException {
  WidgetRenderException(
    super.message, {
    super.widgetType,
    super.originalError,
    super.stackTrace,
  });
}

class WidgetDataException extends WidgetException {
  WidgetDataException(
    super.message, {
    super.widgetType,
    super.originalError,
    super.stackTrace,
  });
}

class WidgetSyncException extends WidgetException {
  WidgetSyncException(
    super.message, {
    super.widgetType,
    super.originalError,
    super.stackTrace,
  });
}

class SupabaseConnectionException extends WidgetDataException {
  SupabaseConnectionException(
    super.message, {
    super.widgetType,
    super.originalError,
    super.stackTrace,
  });
}