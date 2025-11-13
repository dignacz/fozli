class Recipe {
  final String id;
  final String userId;
  final String name;
  final List<Ingredient> ingredients;
  final String? instructions;
  final String? imageUrl;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.userId,
    required this.name,
    required this.ingredients,
    this.instructions,
    this.imageUrl,
    required this.createdAt,
  });

  // Convert Recipe to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create Recipe from Firestore document
  factory Recipe.fromMap(String id, Map<String, dynamic> map) {
    return Recipe(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      ingredients: (map['ingredients'] as List<dynamic>?)
              ?.map((i) => Ingredient.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      instructions: map['instructions'],
      imageUrl: map['imageUrl'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
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