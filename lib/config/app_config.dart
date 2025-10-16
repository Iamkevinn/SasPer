import 'package:flutter/foundation.dart';

class AppConfig {
  static const String renderBackendBaseUrl = "https://sasper.onrender.com/api";
  static const String supabaseUrl = 'https://flyqlrujavwndmdqaldr.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZseXFscnVqYXZ3bmRtZHFhbGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NDQyOTEsImV4cCI6MjA2NzIyMDI5MX0.gv47_mKVpXRETdHxDC2vGxuOlKK_bgjZz2zqpJMxDXs';
  static const String googlePlacesApiKey = "AIzaSyBFJi2UL13reVFEqVSnSuGEhbffsyQPyxw";

  static void checkKeys() {
    if (kDebugMode) {
      print("--- VERIFICANDO CLAVES DE AppConfig ---");
      print("Clave de Places API: '$googlePlacesApiKey'");
      print("¿Está vacía la clave?: ${googlePlacesApiKey.isEmpty}");
      print("------------------------------------");
    }

  }
}
