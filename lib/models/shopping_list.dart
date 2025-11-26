// models/shopping_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingList {
  final String id;
  final String userId;
  final String name;
  final String emoji;
  final String color; // Hex color without # (e.g., "FF8F8F")
  final DateTime createdAt;
  final bool isSystem; // true for seasonal lists that can't be deleted

  ShoppingList({
    required this.id,
    required this.userId,
    required this.name,
    required this.emoji,
    required this.color,
    required this.createdAt,
    this.isSystem = false,
  });

  factory ShoppingList.fromMap(String id, Map<String, dynamic> map) {
    return ShoppingList(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      emoji: map['emoji'] ?? '📝',
      color: map['color'] ?? 'FF8F8F',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isSystem: map['isSystem'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'emoji': emoji,
      'color': color,
      'createdAt': Timestamp.fromDate(createdAt),
      'isSystem': isSystem,
    };
  }

  ShoppingList copyWith({
    String? id,
    String? userId,
    String? name,
    String? emoji,
    String? color,
    DateTime? createdAt,
    bool? isSystem,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      isSystem: isSystem ?? this.isSystem,
    );
  }
}

// Pre-made shopping list templates
class ShoppingListTemplates {
  static final List<Map<String, String>> templates = [
    {'name': 'Heti bevásárlás', 'emoji': '🛒', 'color': 'FF8F8F'}, // Coral
    {'name': 'Gyors beszerzés', 'emoji': '⚡', 'color': 'FFB84D'}, // Orange
    {'name': 'Hétvégi főzés', 'emoji': '🍽️', 'color': 'B7A3E3'}, // Lavender
    {'name': 'Party kellékek', 'emoji': '🎉', 'color': 'FFB6C1'}, // Pink
    {'name': 'Egészséges alapok', 'emoji': '🥗', 'color': '9CAF88'}, // Sage
    {'name': 'Éléskamra', 'emoji': '🏪', 'color': 'C2E2FA'}, // Sky blue
  ];
}

// Seasonal shopping lists (Christmas, Easter)
class SeasonalShoppingLists {
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

  // Get seasonal list ID for current season
  static String? getSeasonalListId() {
    final year = DateTime.now().year;
    if (isChristmasSeason()) {
      return 'christmas_shopping_$year';
    } else if (isEasterSeason()) {
      return 'easter_shopping_$year';
    }
    return null;
  }

  // Get seasonal list template (for creation)
  static ShoppingList? getSeasonalListTemplate(String userId) {
    final year = DateTime.now().year;
    if (isChristmasSeason()) {
      return ShoppingList(
        id: 'christmas_shopping_$year',
        userId: userId,
        name: 'Karácsonyi bevásárlás',
        emoji: '🎄',
        color: 'C41E3A', // Christmas red
        createdAt: DateTime.now(),
        isSystem: true,
      );
    } else if (isEasterSeason()) {
      return ShoppingList(
        id: 'easter_shopping_$year',
        userId: userId,
        name: 'Húsvéti bevásárlás',
        emoji: '🐰',
        color: 'FFD700', // Gold
        createdAt: DateTime.now(),
        isSystem: true,
      );
    }
    return null;
  }

  // Check if a list is a seasonal list
  static bool isSeasonalList(String listId) {
    return listId.startsWith('christmas_shopping_') || listId.startsWith('easter_shopping_');
  }

  // Check if a seasonal list should be visible
  // Returns true if it's the current season OR if it has items (keep user's data)
  static Future<bool> shouldShowSeasonalList(String listId, String userId) async {
    if (!isSeasonalList(listId)) return true;
    
    // Check if it has items
    final snapshot = await FirebaseFirestore.instance
        .collection('shoppingListItems')
        .where('userId', isEqualTo: userId)
        .where('listId', isEqualTo: listId)
        .limit(1)
        .get();
    
    // If it has items, always show it (don't hide user's data)
    if (snapshot.docs.isNotEmpty) return true;
    
    // If empty, only show during the season
    if (listId.startsWith('christmas_shopping_')) {
      return isChristmasSeason();
    } else if (listId.startsWith('easter_shopping_')) {
      return isEasterSeason();
    }
    
    return false;
  }
}