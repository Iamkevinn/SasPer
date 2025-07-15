// lib/models/goal_model.dart

class Goal {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  double currentAmount;
  final DateTime? targetDate;
  final DateTime createdAt;
  String status;
  final String? iconName;

  Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    required this.createdAt,
    this.status = 'active',
    this.iconName,
  });

  // Método factory para crear una instancia de Goal desde un mapa (JSON de Supabase)
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      // Supabase devuelve 'numeric' como double o int, así que lo casteamos de forma segura.
      targetAmount: (map['target_amount'] as num).toDouble(),
      currentAmount: (map['current_amount'] as num).toDouble(),
      targetDate: map['target_date'] != null ? DateTime.parse(map['target_date']) : null,
      createdAt: DateTime.parse(map['created_at']),
      status: map['status'],
      iconName: map['icon_name'],
    );
  }

  // Método para convertir una instancia de Goal a un mapa (para enviar a Supabase)
  Map<String, dynamic> toMap() {
    return {
      // 'id' y 'created_at' no se envían al crear, Supabase los genera.
      // 'user_id' tampoco, se infiere del usuario autenticado.
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate?.toIso8601String(),
      'status': status,
      'icon_name': iconName,
      // Al crear, añadiremos el user_id explícitamente en el servicio.
    };
  }

  // Getter para el progreso (de 0.0 a 1.0)
  double get progress => (currentAmount > 0 && targetAmount > 0) ? currentAmount / targetAmount : 0.0;
}