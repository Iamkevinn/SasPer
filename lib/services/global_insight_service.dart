import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/insight_model.dart';
import 'package:sasper/widgets/shared/floating_insight_banner.dart';
import 'package:sasper/screens/analysis_screen.dart';
import 'package:sasper/main.dart'; // 👈 Importa donde esté tu navigatorKey
import 'dart:developer' as developer;
import 'package:sasper/services/notification_service.dart';

class GlobalInsightService {
  static final instance = GlobalInsightService._();
  GlobalInsightService._();

  OverlayEntry? _overlayEntry;
  bool _isListening = false;

  void startListening() { // 👈 Ya no necesita context aquí
    if (_isListening) return;

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return;

      client
          .channel('public:insights')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'insights',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              developer.log('🧠 [EVENTO] Payload completo: $payload'); // <--- MIRA ESTO EN LA CONSOLA
  
              // payload.newRecord es el mapa que necesitas para Insight.fromMap
              final newRecord = payload.newRecord; 
              final newInsight = Insight.fromMap(newRecord);
              
              developer.log('🧠 IA: Tipo recibido: ${newInsight.type}'); // <--- MIRA ESTO
              // 👈 --- NUEVA LÓGICA INTELIGENTE ---
              if (newInsight.type == InsightType.goal_saving_reminder) {
                // Si es un recordatorio de meta, disparamos la notificación local interactiva.
                final goalId = newInsight.metadata['goal_id'] as String? ?? '';
                final goalName = newInsight.metadata['goal_name'] as String? ?? 'tu meta';
                final savingsAmount = (newInsight.metadata['savings_amount'] as num? ?? 0).toDouble();

                if (goalId.isNotEmpty) {
                  NotificationService.instance.showGoalSavingReminder(
                    goalId: goalId,
                    goalName: goalName,
                    savingsAmount: savingsAmount,
                  );
                }
              } else {
                // Para cualquier otro tipo de insight, mostramos el banner superior como antes.
              _showTopBanner(newInsight);
              }
            },
          )
          .subscribe((status, error) {
            developer.log('📡 Estado de suscripción Realtime: $status, Error: $error');
          });

      _isListening = true;
      developer.log('✅ Global Insight Listener activado.');
    } catch (e) {
      developer.log('🔥 Error en listener: $e');
    }
  }

  void _showTopBanner(Insight insight) {
    // Usamos la navigatorKey para obtener el contexto actual de la app
    final context = navigatorKey.currentContext;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _removeCurrentBanner();

      _overlayEntry = OverlayEntry(
        builder: (ctx) => Positioned(
          top: 0, left: 0, right: 0,
          child: Material(
            color: Colors.transparent,
            child: FloatingInsightBanner(
              insight: insight,
              onDismiss: () => _removeCurrentBanner(),
              onTap: () {
                _removeCurrentBanner();
                navigatorKey.currentState?.push(
                  MaterialPageRoute(builder: (_) => const AnalysisScreen())
                );
              },
            ),
          ),
        ),
      );

      // Insertamos usando el overlay del Navigator principal
      navigatorKey.currentState?.overlay?.insert(_overlayEntry!);

      Future.delayed(const Duration(seconds: 6), () {
        _removeCurrentBanner();
      });
    });
  }

  void _removeCurrentBanner() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }
}