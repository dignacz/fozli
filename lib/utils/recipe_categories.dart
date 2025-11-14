// utils/recipe_categories.dart
import 'package:flutter/material.dart';

class RecipeCategory {
  final String name;
  final String emoji;
  final Color color;

  const RecipeCategory({
    required this.name,
    required this.emoji,
    required this.color,
  });
}

class RecipeCategories {
  static const Map<String, RecipeCategory> categories = {
    'Főétel': RecipeCategory(
      name: 'Főétel',
      emoji: '🍽️',
      color: Color(0xFFFF6B6B), // coral red
    ),
    'Leves': RecipeCategory(
      name: 'Leves',
      emoji: '🍲',
      color: Color(0xFFFFB347), // orange
    ),
    'Desszert': RecipeCategory(
      name: 'Desszert',
      emoji: '🍰',
      color: Color(0xFFE699FF), // light purple
    ),
    'Péksütemény': RecipeCategory(
      name: 'Péksütemény',
      emoji: '🥖',
      color: Color(0xFFD4A574), // brown
    ),
    'Saláta': RecipeCategory(
      name: 'Saláta',
      emoji: '🥗',
      color: Color.fromARGB(255, 124, 206, 124), // light green
    ),
    'Ital': RecipeCategory(
      name: 'Ital',
      emoji: '🍹',
      color: Color(0xFF87CEEB), // sky blue
    ),
    'Egyéb': RecipeCategory(
      name: 'Egyéb',
      emoji: '🍴',
      color: Color(0xFF9B9B9B), // gray
    ),
  };

  static RecipeCategory getCategory(String categoryName) {
    return categories[categoryName] ?? categories['Egyéb']!;
  }

  static List<String> getCategoryNames() {
    return categories.keys.toList();
  }
}