// lib/services/ai_analysis_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// Asumimos que has creado este archivo de configuración
import 'package:sasper/config/app_config.dart'; 

class AiAnalysisService {
  final http.Client _httpClient;
  final SupabaseClient _supabaseClient;
  
  // Usamos una constante para el endpoint específico
  static const String _analysisEndpoint = "/analisis-financiero";

  // 1. Inyección de dependencias en el constructor
  AiAnalysisService({
    http.Client? httpClient,
    SupabaseClient? supabaseClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _supabaseClient = supabaseClient ?? Supabase.instance.client;

  Future<String> getFinancialAnalysis() async {
    developer.log('🤖 [Service] Requesting financial analysis...', name: 'AiAnalysisService');
    
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw Exception("Usuario no autenticado.");
      }
      final userId = user.id;
      
      // 2. Construcción de la URL desde una configuración central
      final url = Uri.parse('${AppConfig.renderBackendBaseUrl}$_analysisEndpoint?user_id=$userId');

      developer.log('📞 Calling API: $url', name: 'AiAnalysisService');

      // 3. Llamada HTTP con timeout
      final response = await _httpClient
          .get(url)
          .timeout(const Duration(seconds: 45), onTimeout: () {
            // Esto se ejecuta si el tiempo de espera se agota
            throw TimeoutException('La conexión con el servidor de análisis ha superado el tiempo de espera.');
          });

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final analysis = data['analisis'];
        if (analysis == null) {
          throw Exception("Respuesta inválida del servidor: no se encontró la clave 'analisis'.");
        }
        developer.log('✅ [Service] Analysis received successfully.', name: 'AiAnalysisService');
        return analysis as String;
      } else {
        developer.log(
          '🔥 [Service] Server error: ${response.statusCode}\nBody: ${response.body}',
          name: 'AiAnalysisService',
          level: 1000, // Nivel de error
        );
        throw Exception('Error del servidor al obtener el análisis. Código: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      developer.log('⏱️ [Service] Timeout error: $e', name: 'AiAnalysisService', error: e);
      rethrow; // Re-lanzamos la excepción para que la UI pueda manejarla específicamente
    } catch (e, stackTrace) {
      developer.log('🔥 [Service] General error: $e', name: 'AiAnalysisService', error: e, stackTrace: stackTrace);
      // Re-lanzamos una excepción más genérica para la UI
      throw Exception('No se pudo completar el análisis. Por favor, inténtalo de nuevo.');
    }
  }
}