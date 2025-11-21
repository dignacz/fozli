//models/recipe.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

class Recipe {
  final String id;
  final String userId;
  final String name;
  final List<Ingredient> ingredients;
  final String? instructions;
  final String category;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.userId,
    required this.name,
    required this.ingredients,
    this.instructions,
    required this.category,
    required this.createdAt,
  });

  // Convert Recipe to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create Recipe from Firestore document
  factory Recipe.fromMap(String id, Map<String, dynamic> map) {
    // Create Recipe from Firestore document
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.parse(map['createdAt'] as String);
    } else {
      parsedCreatedAt = DateTime.now();
    }
    return Recipe(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      ingredients: (map['ingredients'] as List<dynamic>?)
              ?.map((i) => Ingredient.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: map['instructions'],
      category: map['category'] ?? 'Főétel',
      createdAt: parsedCreatedAt,
    );
  }
}

class Ingredient {
  final String name;
  final String quantity;
  final String unit;

  Ingredient({
    required this.name,
    required this.quantity,
    required this.unit
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? '',
      unit: map['unit'] ?? 'db',
    );
  }
}