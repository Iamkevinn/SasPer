import 'package:flutter/foundation.dart';

class WidgetConfig {
  // Timeouts
  static const Duration networkTimeout = Duration(seconds: 10);
  static const Duration renderTimeout = Duration(seconds: 5);
  
  // Cache
  static const Duration cacheExpiration = Duration(minutes: 15);
  static const int maxCacheSize = 10 * 1024 * 1024; // 10MB
  
  // Rendering
  static const int maxChartCategories = 5;
  static const double chartQuality = 2.0; // DPI multiplier
  
  // Retry
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Logging
  static const bool verboseLogging = kDebugMode;
  
  // SharedPreferences keys
  static const String supabaseUrlKey = 'supabase_url';
  static const String supabaseApiKeyKey = 'supabase_api_key';
  static const String lastUpdateKey = 'widget_last_update';
  static const String lastValidStateKey = 'widget_last_valid_state';
}