class Transaction {
  final String id;
  final String type;
  final String? category;
  final String? description;
  final double amount;
  final DateTime transactionDate;

  Transaction({
    required this.id,
    required this.type,
    this.category,
    this.description,
    required this.amount,
    required this.transactionDate,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? 'error_id',
      type: json['type'] as String? ?? 'Desconocido',
      category: json['category'] as String?,
      description: json['description'] as String?,
      amount: (json['amount'] as num? ?? 0).toDouble(),
      transactionDate: DateTime.tryParse(json['transaction_date']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  // Método para convertir a Map, útil para pasar a EditTransactionScreen
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'category': category,
    'description': description,
    'amount': amount,
    'transaction_date': transactionDate.toIso8601String(),
  };
}