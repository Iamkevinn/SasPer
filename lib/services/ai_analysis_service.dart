// lib/services/ai_analysis_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AiAnalysisService {
  // ¡¡IMPORTANTE!! Reemplaza esta IP con la IP de tu ordenador
  static const String _baseUrl = "http://192.168.1.105:8000/api/analisis-financiero";

  Future<String> getFinancialAnalysis() async {
    try {
      // 1. Obtener el ID del usuario actual de Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception("Usuario no autenticado.");
      }
      final userId = user.id;

      // 2. Construir la URL completa con el user_id
      final url = Uri.parse('$_baseUrl?user_id=$userId');

      print('Llamando a la API de análisis: $url');

      // 3. Hacer la llamada HTTP GET
      final response = await http.get(url);

      // 4. Procesar la respuesta
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // El backend devuelve un JSON como {"analisis": "texto..."}
        return data['analisis'] as String;
      } else {
        // Manejar errores del servidor
        print('Error del servidor: ${response.statusCode}');
        print('Cuerpo de la respuesta: ${response.body}');
        throw Exception('Error al obtener el análisis del servidor.');
      }
    } catch (e) {
      // Manejar errores de red o cualquier otra excepción
      print('Error en AiAnalysisService: $e');
      throw Exception('No se pudo conectar con el servicio de análisis. Revisa tu conexión y que el servidor Python esté funcionando.');
    }
  }
}