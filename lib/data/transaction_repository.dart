// lib/data/transaction_repository.dart

import 'dart:async';
import 'package:sasper/models/transaction_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

// No necesitamos importar el modelo aquí, ya que los datos vienen de la UI.
// Tampoco necesitamos notificar con EventService, ya que la lógica de streams
// está en el DashboardRepository, que escucha directamente la tabla.

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Añade una nueva transacción a la base de datos.
  /// Lanza una excepción si la operación falla.
  Future<void> addTransaction({
    required String accountId,
    required double amount,
    required String type, // 'Ingreso' o 'Gasto'
    required String category,
    required String description,
    required DateTime transactionDate,
  }) async {
    developer.log('➕ [Repo] Adding new transaction...', name: 'TransactionRepository');
    try {
      await _client.from('transactions').insert({
        'user_id': _client.auth.currentUser!.id,
        'account_id': accountId,
        'amount': amount,
        'type': type,
        'category': category,
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
      });
      developer.log('✅ [Repo] Transaction added successfully.', name: 'TransactionRepository');
      // No necesitamos EventService aquí. El DashboardRepository ya escucha los cambios en la tabla 'transactions'.
    } catch (e) {
      developer.log('🔥 [Repo] Error adding transaction: $e', name: 'TransactionRepository');
      throw Exception('No se pudo añadir la transacción.');
    }
  }

  /// Devuelve una transacción específica por su ID.
  Future<Transaction?> getTransactionById(int transactionId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('id', transactionId)
          .single(); // .single() espera una sola fila o lanza un error
          
      return Transaction.fromMap(response);
    } catch (e) {
      developer.log('🔥 Error fetching transaction by id $transactionId: $e', name: 'TransactionRepository');
      return null; // Devuelve null si no se encuentra o hay un error
    }
  }
  
  /// Actualiza una transacción existente.
  Future<void> updateTransaction({
    required int transactionId, // El ID de la transacción es un 'bigint' -> int
    required String accountId,
    required double amount,
    required String type,
    required String category,
    required String description,
    required DateTime transactionDate,
  }) async {
    developer.log('🔄 [Repo] Updating transaction $transactionId...', name: 'TransactionRepository');
    try {
      await _client.from('transactions').update({
        'account_id': accountId,
        'amount': amount,
        'type': type,
        'category': category,
        'description': description,
        'transaction_date': transactionDate.toIso8601String(),
      }).eq('id', transactionId);
      developer.log('✅ [Repo] Transaction updated successfully.', name: 'TransactionRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error updating transaction: $e', name: 'TransactionRepository');
      throw Exception('No se pudo actualizar la transacción.');
    }
  }

  /// Elimina una transacción.
  Future<void> deleteTransaction(int transactionId) async {
    developer.log('🗑️ [Repo] Deleting transaction $transactionId...', name: 'TransactionRepository');
    try {
      await _client.from('transactions').delete().eq('id', transactionId);
      developer.log('✅ [Repo] Transaction deleted successfully.', name: 'TransactionRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error deleting transaction: $e', name: 'TransactionRepository');
      throw Exception('No se pudo eliminar la transacción.');
    }
  }
}