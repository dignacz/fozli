// models/recipe_collection.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeCollection {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final String color; // Hex color code
  final List<String> recipeIds; // List of recipe IDs in this collection
  final DateTime createdAt;
  final bool isSystem; // System collections (like Christmas) can't be deleted

  RecipeCollection({
    required this.id,
    required this.userId,
    required this.name,
    required this.emoji,
    required this.color,
    required this.recipeIds,
    required this.createdAt,
    this.isSystem = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'emoji': emoji,
      'color': color,
      'recipeIds': recipeIds,
      'createdAt': createdAt.toIso8601String(),
      'isSystem': isSystem,
    };
  }

  factory RecipeCollection.fromMap(String id, Map<String, dynamic> map) {
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.parse(map['createdAt'] as String);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return RecipeCollection(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '📁',
      color: map['color'] ?? 'FF8F8F',
      recipeIds: List<String>.from(map['recipeIds'] ?? []),
      createdAt: parsedCreatedAt,
      isSystem: map['isSystem'] ?? false,
    );
  }

  RecipeCollection copyWith({
    String? id,
    String? userId,
    String? name,
    String? emoji,
    String? color,
    List<String>? recipeIds,
    DateTime? createdAt,
    bool? isSystem,
  }) {
    return RecipeCollection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      recipeIds: recipeIds ?? this.recipeIds,
      createdAt: createdAt ?? this.createdAt,
      isSystem: isSystem ?? this.isSystem,
    );
  }
}

class SeasonalCollections {
  // Check if Christmas season (December 1 - January 6)
  static bool isChristmasSeason() {
    final now = DateTime.now();
    return (now.month == 12) || (now.month == 1 && now.day <= 6);
  }

  // Check if Easter season (dynamic - 2 weeks before to 1 week after Easter)
  static bool isEasterSeason() {
    final now = DateTime.now();
    final easter = _calculateEaster(now.year);
    final start = easter.subtract(const Duration(days: 14));
    final end = easter.add(const Duration(days: 7));
    return now.isAfter(start) && now.isBefore(end);
  }

  // Calculate Easter date using Computus algorithm
  static DateTime _calculateEaster(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  // Get seasonal collection ID for current season
  static String? getSeasonalCollectionId() {
    final year = DateTime.now().year;
    if (isChristmasSeason()) {
      return 'christmas_$year';
    } else if (isEasterSeason()) {
      return 'easter_$year';
    }
    return null;
  }

  // Get seasonal collection template (for creation)
  static RecipeCollection? getSeasonalCollectionTemplate(String userId) {
    final year = DateTime.now().year;
    if (isChristmasSeason()) {
      return RecipeCollection(
        id: 'christmas_$year',
        userId: userId,
        name: 'Karácsonyi receptek',
        emoji: '🎄',
        color: 'C41E3A', // Christmas red
        recipeIds: [],
        createdAt: DateTime.now(),
        isSystem: true,
      );
    } else if (isEasterSeason()) {
      return RecipeCollection(
        id: 'easter_$year',
        userId: userId,
        name: 'Húsvéti receptek',
        emoji: '🐰',
        color: 'FFD700', // Gold
        recipeIds: [],
        createdAt: DateTime.now(),
        isSystem: true,
      );
    }
    return null;
  }

  // Check if a collection is a seasonal collection
  static bool isSeasonalCollection(String collectionId) {
    return collectionId.startsWith('christmas_') || collectionId.startsWith('easter_');
  }

  // Check if a seasonal collection should be visible
  // Returns true if it's the current season OR if it has recipes (keep user's data)
  static bool shouldShowSeasonalCollection(RecipeCollection collection) {
    if (!isSeasonalCollection(collection.id)) return true;
    
    // If it has recipes, always show it (don't hide user's organized recipes)
    if (collection.recipeIds.isNotEmpty) return true;
    
    // If empty, only show during the season
    if (collection.id.startsWith('christmas_')) {
      return isChristmasSeason();
    } else if (collection.id.startsWith('easter_')) {
      return isEasterSeason();
    }
    
    return false;
  }

  // Predefined collection templates
  static List<Map<String, String>> getCollectionTemplates() {
    return [
      {'name': 'Kedvencek', 'emoji': '⭐', 'color': 'FFD700'},
      {'name': 'Gyors ételek', 'emoji': '⚡', 'color': 'FF8F8F'},
      {'name': 'Hétvégi menü', 'emoji': '🍽️', 'color': 'B7A3E3'},
      {'name': 'Vendégvárók', 'emoji': '👥', 'color': '9CAF88'},
      {'name': 'Egészséges', 'emoji': '🥗', 'color': '9CAF88'},
      {'name': 'Comfort food', 'emoji': '🍲', 'color': 'FF8F8F'},
      {'name': 'Édesség', 'emoji': '🍰', 'color': 'FFC0CB'},
      {'name': 'Fagyasztható', 'emoji': '❄️', 'color': 'C2E2FA'},
    ];
  }
}