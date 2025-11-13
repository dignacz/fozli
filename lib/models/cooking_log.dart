// models/cooking_log.dart
class CookingLog {
  final String id;
  final String userId;
  final String recipeId;
  final String recipeName;
  final DateTime cookedDate;
  final DateTime createdAt;

  CookingLog({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.recipeName,
    required this.cookedDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'recipeId': recipeId,
      'recipeName': recipeName,
      'cookedDate': cookedDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CookingLog.fromMap(String id, Map<String, dynamic> map) {
    return CookingLog(
      id: id,
      userId: map['userId'] ?? '',
      recipeId: map['recipeId'] ?? '',
      recipeName: map['recipeName'] ?? '',
      cookedDate: DateTime.parse(map['cookedDate']),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}