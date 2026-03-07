// lib/services/ai_analysis_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/config/app_config.dart'; 
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/simulation_models.dart';
import 'package:sasper/data/dashboard_repository.dart'; // 👈 IMPORTANTE

class AiAnalysisService {
  final http.Client _httpClient;
  final SupabaseClient _supabaseClient;
  
  static const String _analysisEndpoint = "/analisis-financiero";
  static const String _goalProjectionEndpoint = "/proyeccion-meta"; 

  AiAnalysisService({
    http.Client? httpClient,
    SupabaseClient? supabaseClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _supabaseClient = supabaseClient ?? Supabase.instance.client;

  Future<String> getFinancialAnalysis() async {
    developer.log('🤖 [Service] Iniciando análisis enriquecido...', name: 'AiAnalysisService');
    
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) throw Exception("Usuario no autenticado.");

      // 1. RECOLECTAR CONTEXTO LOCAL (Lo que la app ya sabe)
      final dashboard = DashboardRepository.instance.currentData;
      if (dashboard == null) throw Exception("Datos de dashboard no disponibles.");

      // 2. PREPARAR EL PAYLOAD (El paquete de datos para Gemini)
      final Map<String, dynamic> contextData = {
        'user_id': user.id,
        'financial_state': {
          'available_balance': dashboard.availableBalance,
          'total_balance': dashboard.totalBalance,
          'net_worth': dashboard.netWorth,
          'total_debt': dashboard.totalDebt,
          'monthly_income': dashboard.monthlyIncome,
          'restricted_money': dashboard.savingsBalance + dashboard.obligatedBalance,
        },
        'spending_mood_context': _extractMoodContext(dashboard.recentTransactions),
        'debt_context': _extractDebtDetails(dashboard.recentTransactions),
        // Podrías añadir aquí una lista resumida de free_trials si lo necesitas
      };

      final url = Uri.parse('${AppConfig.renderBackendBaseUrl}$_analysisEndpoint');

      // 3. LLAMADA POST CON EL CONTEXTO
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(contextData),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['analisis'] as String;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log('🔥 [Service] Error: $e', name: 'AiAnalysisService', stackTrace: stackTrace);
      throw Exception('No se pudo completar el análisis inteligente.');
    }
  }

  // --- MÉTODOS AUXILIARES PARA LIMPIAR DATOS ANTES DE ENVIAR ---

  // Extrae el "sentimiento" de los gastos recientes
  Map<String, dynamic> _extractMoodContext(List<dynamic> transactions) {
    if (transactions.isEmpty) return {'status': 'Sin datos'};
    
    // 1. Convertimos la lista dinámica a una lista de objetos Transaction
    // 2. Extraemos el mood de forma segura
    final List<String> moods = transactions.map((t) {
      final m = t.mood;
      if (m == null) return 'neutral';
      
      // FIX: En lugar de .name, usamos toString() y dividimos por el punto
      // Esto funciona en todas las versiones de Dart y evita el NoSuchMethodError
      return m.toString().split('.').last;
    }).toList();

    final mostFrequentMood = moods.fold<Map<String, int>>({}, (acc, m) {
      acc[m] = (acc[m] ?? 0) + 1;
      return acc;
    });

    return {
      'history': moods.take(15).toList(),
      'predominant': mostFrequentMood.entries.isEmpty 
          ? 'neutral' 
          : mostFrequentMood.entries.reduce((a, b) => a.value > b.value ? a : b).key
    };
  }

  List<Map<String, dynamic>> _extractDebtDetails(List<dynamic> transactions) {
    // Filtramos y mapeamos asegurando que tratamos los datos como Transaction
    return transactions
        .where((t) => t.isInstallment == true)
        .map((t) {
          final total = t.installmentsTotal ?? 1;
          final current = t.installmentsCurrent ?? 1;
          
          return {
            'item': t.description ?? 'Sin descripción',
            'remaining_installments': total - current + 1,
            'amount_per_installment': (t.amount / total).abs(),
            'category': t.category ?? 'General',
          };
        }).toList();
  }
  
  /// Llama al backend para calcular la proyección financiera de una meta.
  ///
  /// Recibe la meta original y los nuevos valores de monto y fecha.
  /// Devuelve un Future con el objeto `FinancialProjection`.
  Future<FinancialProjection> getGoalProjection({
    required Goal originalGoal,
    required double newTargetAmount,
    required DateTime newTargetDate,
  }) async {
    developer.log('🤖 [Service] Requesting goal projection for "${originalGoal.name}"...', name: 'AiAnalysisService');

    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception("Usuario no autenticado.");
    }

    try {
      // 1. Construcción de la URL para el nuevo endpoint.
      final url = Uri.parse('${AppConfig.renderBackendBaseUrl}$_goalProjectionEndpoint');
      developer.log('📞 Calling API: $url', name: 'AiAnalysisService');

      // 2. Preparación del cuerpo (body) de la solicitud POST.
      // Enviamos toda la información que el backend necesita para el cálculo.
      final body = jsonEncode({
        'user_id': user.id,
        'goal_details': {
          'current_amount': originalGoal.currentAmount,
          'new_target_amount': newTargetAmount,
          'new_target_date': newTargetDate.toIso8601String(),
        }
      });
      
      // 3. Llamada HTTP POST con timeout y headers.
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 20), onTimeout: () {
        throw TimeoutException('La conexión con el servidor de proyecciones ha superado el tiempo de espera.');
      });

      // 4. Procesamiento de la respuesta del backend.
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        // El backend debería devolver un objeto JSON que coincida con tu modelo FinancialProjection.
        // Aquí, creamos una instancia del modelo a partir de la respuesta.
        final projection = FinancialProjection.fromMap(data); 
        
        developer.log('✅ [Service] Goal projection received successfully.', name: 'AiAnalysisService');
        return projection;

      } else {
        developer.log(
          '🔥 [Service] Server error on goal projection: ${response.statusCode}\nBody: ${response.body}',
          name: 'AiAnalysisService',
          level: 1000,
        );
        throw Exception('Error del servidor al calcular la proyección. Código: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      developer.log('⏱️ [Service] Timeout error on goal projection: $e', name: 'AiAnalysisService', error: e);
      rethrow;
    } catch (e, stackTrace) {
      developer.log('🔥 [Service] General error on goal projection: $e', name: 'AiAnalysisService', error: e, stackTrace: stackTrace);
      throw Exception('No se pudo calcular la proyección. Por favor, inténtalo de nuevo.');
    }
  }
}