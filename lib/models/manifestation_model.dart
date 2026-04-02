class Manifestation {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? linkedGoalId;
  /// WOOP: mejor resultado y cómo te sentirás al lograrlo.
  final String? outcome;
  /// WOOP: obstáculo interno que dificulta el deseo.
  final String? obstacle;
  /// WOOP: regla «si [obstáculo], entonces [acción]».
  final String? plan;
  final DateTime createdAt;

  Manifestation({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.imageUrl,
    this.linkedGoalId,
    this.outcome,
    this.obstacle,
    this.plan,
    required this.createdAt,
  });

  /// Plan WOOP útil cuando deseo + resultado + obstáculo y plan están definidos.
  bool get hasCompleteWoop {
    bool filled(String? s) => s != null && s.trim().isNotEmpty;
    return title.trim().isNotEmpty &&
        filled(outcome) &&
        filled(obstacle) &&
        filled(plan);
  }

  static String? _trimmedText(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  factory Manifestation.fromMap(Map<String, dynamic> map) {
    String? rawUrl = map['image_url'] as String?;
    rawUrl = rawUrl?.trim();
    if (rawUrl != null && rawUrl.isEmpty) rawUrl = null;

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['created_at'] as String);
    } catch (_) {
      parsedDate = DateTime.now(); // fallback seguro
    }

    return Manifestation(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      description: _trimmedText(map['description']),
      imageUrl: rawUrl,
      linkedGoalId: map['linked_goal_id'] as String?,
      outcome: _trimmedText(map['outcome']),
      obstacle: _trimmedText(map['obstacle']),
      plan: _trimmedText(map['plan']),
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'image_url': imageUrl?.trim(),
      'linked_goal_id': linkedGoalId,
      'outcome': outcome,
      'obstacle': obstacle,
      'plan': plan,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
