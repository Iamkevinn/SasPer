// lib/data/recurring_repository.dart (NUEVO ARCHIVO)

import 'dart:async';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class RecurringRepository {
  final SupabaseClient _client;

  RecurringRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Stream<List<RecurringTransaction>> getRecurringTransactionsStream() {
    return _client
        .from('recurring_transactions')
        .stream(primaryKey: ['id'])
        .order('next_due_date', ascending: true)
        .map((listOfMaps) {
          final transactions = listOfMaps.map((data) => RecurringTransaction.fromMap(data)).toList();
          developer.log('🔄 Stream de transacciones recurrentes actualizado con ${transactions.length} items.');
          return transactions;
        });
  }

  Future<void> addRecurringTransaction({
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
      await _client.from('recurring_transactions').insert({
        'user_id': _client.auth.currentUser!.id,
        'description': description,
        'amount': amount,
        'type': type,
        'category': category,
        'account_id': accountId,
        'frequency': frequency,
        'interval': interval,
        'start_date': startDate.toIso8601String(),
        // La primera fecha de vencimiento es la fecha de inicio.
        'next_due_date': startDate.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });
    } catch (e) {
      developer.log('🔥 Error añadiendo transacción recurrente: $e');
      throw Exception('No se pudo crear el gasto fijo.');
    }
  }

  Future<void> deleteRecurringTransaction(String id) async {
    try {
      await _client.from('recurring_transactions').delete().eq('id', id);
    } catch (e) {
      developer.log('🔥 Error eliminando transacción recurrente: $e');
      throw Exception('No se pudo eliminar el gasto fijo.');
    }
  }
}