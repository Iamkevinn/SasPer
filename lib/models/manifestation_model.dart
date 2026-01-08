class Manifestation {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? linkedGoalId;
  final DateTime createdAt;

  Manifestation({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.imageUrl,
    this.linkedGoalId,
    required this.createdAt,
  });

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
      description: map['description'] as String?,
      imageUrl: rawUrl,
      linkedGoalId: map['linked_goal_id'] as String?,
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
      'created_at': createdAt.toIso8601String(),
    };
  }
}
