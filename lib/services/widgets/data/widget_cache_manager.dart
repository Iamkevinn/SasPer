import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetCacheManager {
  static final WidgetCacheManager _instance = WidgetCacheManager._();
  static WidgetCacheManager get instance => _instance;
  
  WidgetCacheManager._();

  /// Genera un hash MD5 de los datos
  String _generateHash(dynamic data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Verifica si los datos han cambiado
  Future<bool> hasChanged(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedHash = prefs.getString('${key}_hash');
    final newHash = _generateHash(data);
    
    return cachedHash != newHash;
  }

  /// Guarda datos en caché con su hash
  Future<void> save(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _generateHash(data);
    
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_hash', hash);
    await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  /// Recupera datos de caché si no han expirado
  Future<Map<String, dynamic>?> get(
    String key, {
    Duration? maxAge,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;

    if (maxAge != null) {
      final timestamp = prefs.getInt('${key}_timestamp');
      if (timestamp == null) return null;
      
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > maxAge.inMilliseconds) return null;
    }

    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Limpia toda la caché
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.endsWith('_hash') || k.endsWith('_timestamp'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
