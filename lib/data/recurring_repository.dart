// lib/data/recurring_repository.dart

import 'dart:async';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class RecurringRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<RecurringTransaction>>.broadcast();
  RealtimeChannel? _channel;

  // Constructor privado para forzar el uso del Singleton `instance`.
  RecurringRepository._internal();
  static final RecurringRepository instance = RecurringRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ RecurringRepository inicializado PEREZOSAMENTE.', name: 'RecurringRepository');
    }
  }

  /// Llama al RPC para procesar un pago recurrente.
  Future<void> processPayment(String recurringId) async {
    try {
      await client.rpc('process_recurring_payment', params: {'recurring_id': recurringId});
      developer.log('✅ [Repo] Pago procesado para $recurringId', name: 'RecurringRepository');
      // luego de cambiar la base, actualizamos widgets relacionados
      await widget_service.WidgetService.updateNextPaymentWidget();
      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
    } catch (e) {
      developer.log('🔥 [Repo] Error procesando pago: $e', name: 'RecurringRepository');
      throw Exception('No se pudo registrar el pago.');
    }
  }

  /// Llama al RPC para omitir un pago recurrente.
  Future<void> skipPayment(String recurringId) async {
    try {
      await client.rpc('skip_recurring_payment', params: {'recurring_id': recurringId});
      developer.log('✅ [Repo] Pago omitido para $recurringId', name: 'RecurringRepository');
      await widget_service.WidgetService.updateNextPaymentWidget();
      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
    } catch (e) {
      developer.log('🔥 [Repo] Error omitiendo pago: $e', name: 'RecurringRepository');
      throw Exception('No se pudo omitir el pago.');
    }
  }

  /// Llama al RPC para posponer un pago recurrente.
  Future<void> snoozePayment(String recurringId, DateTime newDate) async {
    try {
      await client.rpc('snooze_recurring_payment', params: {
        'recurring_id': recurringId,
        'new_date': newDate.toIso8601String(),
      });
      developer.log('✅ [Repo] Pago pospuesto para $recurringId', name: 'RecurringRepository');
      await widget_service.WidgetService.updateNextPaymentWidget();
      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
    } catch (e) {
      developer.log('🔥 [Repo] Error posponiendo pago: $e', name: 'RecurringRepository');
      throw Exception('No se pudo posponer el pago.');
    }
  }
  
  /// Getter público para el cliente de Supabase.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para RecurringRepository.");
    }
    return _supabase!;
  }

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de todas las transacciones recurrentes.
  Stream<List<RecurringTransaction>> getRecurringTransactionsStream() {
    _fetchAndPushData();
    return _streamController.stream;
  }
  
  /// Obtiene una lista de todas las transacciones recurrentes (llamada única).
  Future<List<RecurringTransaction>> getAll() async {
    developer.log('🔄 [Repo] Obteniendo todas las transacciones recurrentes...', name: 'RecurringRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado.');

      final data = await client
          .from('recurring_transactions')
          .select()
          .eq('user_id', userId)
          .order('next_due_date', ascending: true);

      final list = (data as List).map((e) => RecurringTransaction.fromMap(e)).toList();
      developer.log('✅ [Repo] Obtenidas ${list.length} transacciones recurrentes.', name: 'RecurringRepository');
      return list;
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo transacciones recurrentes: $e', name: 'RecurringRepository');
      return [];
    }
  }

  /// Vuelve a cargar los datos y los emite en el stream.
  Future<void> refreshData() {
    developer.log('🔄 [Repo] Refresco manual solicitado.', name: 'RecurringRepository');
    return _fetchAndPushData();
  }

  /// Añade una nueva transacción recurrente y la devuelve.
  /// ⚠️ VERSIÓN CORREGIDA: Guarda la fecha CON OFFSET de zona horaria
  Future<RecurringTransaction> addRecurringTransaction({
    required String description,
    required double amount,
    required String type,
    required String category,
    required String accountId,
    required String frequency,
    required int interval,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    try {
      // 🔥 SOLUCIÓN: Usar formato ISO 8601 COMPLETO con offset de zona horaria
      // Esto le dice a PostgreSQL EXPLÍCITAMENTE en qué zona horaria está la fecha
      // Formato: "YYYY-MM-DDTHH:MM:SS-05:00" (para Colombia UTC-5)
      
      // Calcular el offset en horas (Colombia = -5)
      final offsetMinutes = startDate.timeZoneOffset.inMinutes;
      final offsetHours = (offsetMinutes / 60).floor();
      final offsetMins = offsetMinutes.abs() % 60;
      final offsetSign = offsetMinutes >= 0 ? '+' : '-';
      final offsetStr = '$offsetSign${offsetHours.abs().toString().padLeft(2, '0')}:${offsetMins.toString().padLeft(2, '0')}';
      
      final String startDateStr = 
          '${startDate.year.toString().padLeft(4, '0')}-'
          '${startDate.month.toString().padLeft(2, '0')}-'
          '${startDate.day.toString().padLeft(2, '0')}T'
          '${startDate.hour.toString().padLeft(2, '0')}:'
          '${startDate.minute.toString().padLeft(2, '0')}:'
          '${startDate.second.toString().padLeft(2, '0')}'
          '$offsetStr';

      final String? endDateStr = endDate != null
          ? '${endDate.year.toString().padLeft(4, '0')}-'
            '${endDate.month.toString().padLeft(2, '0')}-'
            '${endDate.day.toString().padLeft(2, '0')}T'
            '${endDate.hour.toString().padLeft(2, '0')}:'
            '${endDate.minute.toString().padLeft(2, '0')}:'
            '${endDate.second.toString().padLeft(2, '0')}'
            '$offsetStr'
          : null;

      developer.log(
        '💾 [Repo] Guardando con fecha Y OFFSET: $startDateStr',
        name: 'RecurringRepository',
      );

      final newTransactionData = {
        'user_id': client.auth.currentUser!.id,
        'description': description,
        'amount': amount,
        'type': type,
        'category': category,
        'account_id': accountId,
        'frequency': frequency,
        'interval': interval,
        'start_date': startDateStr,
        'next_due_date': startDateStr,
        'end_date': endDateStr,
      };

      final response = await client
          .from('recurring_transactions')
          .insert(newTransactionData)
          .select()
          .single();

      developer.log(
        '✅ [Repo] Guardado exitoso. Fecha en BD: ${response['next_due_date']}',
        name: 'RecurringRepository',
      );

      return RecurringTransaction.fromMap(response);
    } catch (e, stackTrace) {
      developer.log(
        '🔥 Error añadiendo transacción recurrente: $e\n$stackTrace',
        name: 'RecurringRepository',
      );
      throw Exception('No se pudo crear el gasto fijo.');
    }
  }

  /// Actualiza una transacción recurrente existente.
  Future<void> updateRecurringTransaction(RecurringTransaction transaction) async {
    try {
      await client
        .from('recurring_transactions')
        .update(transaction.toJson()) 
        .eq('id', transaction.id);
    } catch (e) {
      developer.log('🔥 Error actualizando gasto fijo: $e', name: 'RecurringRepository');
      throw Exception('No se pudo actualizar el gasto fijo.');
    }
  }
  
  /// Elimina una transacción recurrente por su ID.
  Future<void> deleteRecurringTransaction(String id) async {
    try {
      await client.from('recurring_transactions').delete().eq('id', id);
    } catch (e) {
      developer.log('🔥 Error eliminando transacción recurrente: $e', name: 'RecurringRepository');
      throw Exception('No se pudo eliminar el gasto fijo.');
    }
  }

  /// Libera los recursos del repositorio.
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de RecurringRepository.', name: 'RecurringRepository');
    if (_channel != null) {
      _supabase?.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }

  // --- MÉTODOS PRIVADOS ---

  /// Configura la suscripción de Realtime.
  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo-Lazy] Configurando Realtime para Transacciones Recurrentes...', name: 'RecurringRepository');
    _channel = _supabase!
        .channel('public:recurring_transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recurring_transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime (RECURRING). Refrescando...', name: 'RecurringRepository');
            _fetchAndPushData();
          },
        )
        .subscribe();
  }

  /// Carga todas las transacciones recurrentes y las emite en el stream.
  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Obteniendo transacciones recurrentes...', name: 'RecurringRepository');
    try {
      final transactions = await getAll();
      if (!_streamController.isClosed) {
        _streamController.add(transactions);
        developer.log('✅ [Repo] ${transactions.length} elementos recurrentes enviados al stream.', name: 'RecurringRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo transacciones recurrentes: $e', name: 'RecurringRepository');
      if (!_streamController.isClosed) {
        _streamController.addError('Error al cargar datos: $e');
      }
    }
  }
}