// models/recipe.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/unit_normalizer.dart';
import 'package:html_unescape/html_unescape.dart';

class Recipe {
  final String id;
  final String userId;
  final String name;
  final List<Ingredient> ingredients;
  final String? instructions;
  final String category;
  final DateTime createdAt;
  final String? imageUrl;
  final int? cookingTimeMinutes;
  final int? servings; // NEW: Number of servings/portions

  Recipe({
    required this.id,
    required this.userId,
    required this.name,
    required this.ingredients,
    this.instructions,
    required this.category,
    required this.createdAt,
    this.imageUrl,
    this.cookingTimeMinutes,
    this.servings, // NEW
  });

  //HTML ENCODING
  static final _htmlUnescape = HtmlUnescape();

  // Convert Recipe to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'imageUrl': imageUrl,
      'cookingTimeMinutes': cookingTimeMinutes,
      'servings': servings, // NEW
    };
  }

  // Create Recipe from Firestore document
  factory Recipe.fromMap(String id, Map<String, dynamic> map) {
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
      imageUrl: map['imageUrl'],
      cookingTimeMinutes: map['cookingTimeMinutes'],
      servings: map['servings'], // NEW
    );
  }

  // Convert to schema.org/Recipe format
  Map<String, dynamic> toSchemaOrg() {
    return {
      '@context': 'https://schema.org',
      '@type': 'Recipe',
      'name': name,
      'recipeCategory': category,
      'recipeIngredient': ingredients
          .map((i) => '${i.quantity} ${i.unit} ${i.name}'.trim())
          .toList(),
      'recipeInstructions': instructions,
      'totalTime': cookingTimeMinutes != null ? 'PT${cookingTimeMinutes}M' : null,
      'image': imageUrl,
      'datePublished': createdAt.toIso8601String(),
      'recipeYield': servings?.toString(), // NEW
    };
  }

  // Create from schema.org/Recipe format
  factory Recipe.fromSchemaOrg(String userId, Map<String, dynamic> schemaData) {
    List<Ingredient> ingredients = [];

    // Try multiple possible ingredient fields
    final rawIngredients = schemaData['recipeIngredient'] ?? 
                           schemaData['ingredients'] ??
                           schemaData['ingredient'];

    if (rawIngredients != null) {
      List<String> ingredientStrings = [];

      // Convert whatever format to List<String>
      if (rawIngredients is String) {
        // Single string - split by newlines or commas
        ingredientStrings = rawIngredients
            .split(RegExp(r'\n|,'))
            .where((line) => line.trim().isNotEmpty)
            .toList();
      } 
      else if (rawIngredients is List) {
        // It's a list - but items might be strings, maps, or mixed
        for (var item in rawIngredients) {
          if (item is String) {
            ingredientStrings.add(item);
          } else if (item is Map) {
            // Try to extract text from map (some sites do this)
            final text = item['text'] ?? item['name'] ?? item['ingredient'] ?? item.toString();
            ingredientStrings.add(text.toString());
          } else {
            ingredientStrings.add(item.toString());
          }
        }
      }
      else if (rawIngredients is Map) {
        // Single map object
        final text = rawIngredients['text'] ?? rawIngredients['name'] ?? rawIngredients.toString();
        ingredientStrings.add(text.toString());
      }

      // Now parse all ingredient strings
      ingredients = ingredientStrings.map((text) {
        final trimmed = text.trim();
        if (trimmed.isEmpty) return null;

        final String lower = trimmed.toLowerCase();

        // Handle "ízlés szerint" pattern
        if (lower.contains('ízlés szerint') && !RegExp(r'^\d').hasMatch(trimmed)) {
          final name = trimmed.replaceAll(RegExp(r'\s*ízlés szerint\s*$', caseSensitive: false), '').trim();
          return Ingredient(quantity: '', unit: 'ízlés szerint', name: name);
        }

        return _parseIngredient(trimmed);
      }).whereType<Ingredient>().toList(); // Filter out nulls
    }

    // Parse cooking time safely
    int? cookingTime;
    try {
      final timeData = schemaData['totalTime'];
      if (timeData is String) {
        final match = RegExp(r'PT(\d+)M').firstMatch(timeData);
        if (match != null) {
          cookingTime = int.tryParse(match.group(1)!);
        }
      } else if (timeData is int) {
        cookingTime = timeData;
      }
    } catch (e) {
      print('⚠️ Could not parse cooking time: $e');
    }

    // NEW: Parse servings/portions
    int? servings;
    try {
      final yieldData = schemaData['recipeYield'] ?? schemaData['servings'];
      if (yieldData != null) {
        if (yieldData is int) {
          servings = yieldData;
        } else if (yieldData is String) {
          // Try to extract number from strings like "4 servings", "6 adag", "8", etc.
          final match = RegExp(r'(\d+)').firstMatch(yieldData);
          if (match != null) {
            servings = int.tryParse(match.group(1)!);
          }
        }
      }
    } catch (e) {
      print('⚠️ Could not parse servings: $e');
    }

    return Recipe(
      id: '',
      userId: userId,
      name: _parseToString(schemaData['name'], fallback: 'Névtelen recept'),
      ingredients: ingredients,
      instructions: _parseInstructions(schemaData['recipeInstructions']),
      category: _convertToAppCategory(schemaData['recipeCategory']),
      createdAt: DateTime.now(),
      imageUrl: _parseImage(schemaData['image']),
      cookingTimeMinutes: cookingTime,
      servings: servings, // NEW
    );
  }

  // Parse a single ingredient string
  static Ingredient _parseIngredient(String text) {
    final parts = text.split(' ');
    
    if (parts.isEmpty) {
      return Ingredient(quantity: '', unit: 'db', name: text);
    }

    String quantity = '';
    String unit = 'db';
    int startIndex = 0;

    // Try to parse quantity (handles decimals, fractions, mixed numbers)
    final quantityResult = _parseQuantity(parts);
    if (quantityResult != null) {
      quantity = quantityResult['value']!;
      startIndex = quantityResult['endIndex']! as int;
    }

    // Try to parse unit if we have more parts
    if (startIndex < parts.length) {
      final unitResult = _parseUnit(parts, startIndex);
      if (unitResult != null) {
        unit = unitResult['value']!;
        startIndex = unitResult['endIndex']! as int;
      }
    }

    // Rest is the ingredient name
    final name = parts.sublist(startIndex).join(' ').trim();

    return Ingredient(
      quantity: quantity,
      unit: unit,
      name: name.isNotEmpty ? name : text,
    );
  }

  // Parse quantity (handles: 2, 2.5, 2,5, 0.5, 0,5, 1/2, 1 1/2, etc.)
  static Map<String, dynamic>? _parseQuantity(List<String> parts) {
    if (parts.isEmpty) return null;

    final first = parts[0];
    
    // Check for decimal with DOT (2.5, 0.5, etc.)
    final decimalDotMatch = RegExp(r'^(\d+)\.(\d+)$').firstMatch(first);
    if (decimalDotMatch != null) {
      final value = '${decimalDotMatch.group(1)}.${decimalDotMatch.group(2)}';
      return {'value': value, 'endIndex': 1};
    }

    // Check for decimal with COMMA (2,5, 0,5, etc. - Hungarian format)
    final decimalCommaMatch = RegExp(r'^(\d+),(\d+)$').firstMatch(first);
    if (decimalCommaMatch != null) {
      // Convert comma to dot
      final value = '${decimalCommaMatch.group(1)}.${decimalCommaMatch.group(2)}';
      return {'value': value, 'endIndex': 1};
    }

    // Check for integer only (2, 5, 500)
    final intMatch = RegExp(r'^(\d+)$').firstMatch(first);
    if (intMatch != null) {
      return {'value': intMatch.group(1)!, 'endIndex': 1};
    }

    // Check for fraction (1/2, 3/4, etc.)
    final fractionMatch = RegExp(r'^(\d+)/(\d+)$').firstMatch(first);
    if (fractionMatch != null) {
      final numerator = int.parse(fractionMatch.group(1)!);
      final denominator = int.parse(fractionMatch.group(2)!);
      final decimal = (numerator / denominator).toStringAsFixed(2);
      return {'value': decimal, 'endIndex': 1};
    }

    // Check for mixed number (1 1/2 - two parts)
    if (parts.length >= 2) {
      final wholeMatch = RegExp(r'^(\d+)$').firstMatch(first);
      final fractionMatch2 = RegExp(r'^(\d+)/(\d+)$').firstMatch(parts[1]);
      
      if (wholeMatch != null && fractionMatch2 != null) {
        final whole = int.parse(wholeMatch.group(1)!);
        final numerator = int.parse(fractionMatch2.group(1)!);
        final denominator = int.parse(fractionMatch2.group(2)!);
        final total = whole + (numerator / denominator);
        return {'value': total.toStringAsFixed(2), 'endIndex': 2};
      }
    }

    return null;
  }

  // Parse unit (handles common units - all normalized via UnitNormalizer)
  static Map<String, dynamic>? _parseUnit(List<String> parts, int startIndex) {
    if (startIndex >= parts.length) return null;

    final units = [
      // English
      'cup', 'cups', 'tablespoon', 'tablespoons', 'tbsp', 'tbs',
      'teaspoon', 'teaspoons', 'tsp', 'pound', 'pounds', 'lb', 'lbs',
      'ounce', 'ounces', 'oz', 'pint', 'pints', 'quart', 'quarts',
      'gallon', 'gallons', 'clove', 'cloves', 'slice', 'slices',
      'can', 'cans', 'package', 'packages', 'pinch', 'dash',
      'gram', 'grams', 'kilogram', 'kilograms', 'liter', 'liters',
      'litre', 'litres', 'milliliter', 'milliliters', 'millilitre', 'millilitres',
      // Hungarian
      'db', 'g', 'dkg', 'kg', 'ml', 'dl', 'l', 'cl',
      'evőkanál', 'ek', 'teáskanál', 'tk', 'kávéskanál',
      'csipet', 'csomag', 'doboz', 'gerezd', 'darab',
      'csésze', 'bögre', 'kanál',
    ];

    final part = parts[startIndex].toLowerCase();
    
    // Check if it's a known unit
    if (units.contains(part)) {
      return {'value': _normalizeUnit(part), 'endIndex': startIndex + 1};
    }

    // Check for compound units (e.g., "fluid ounces")
    if (startIndex + 1 < parts.length) {
      final compound = '$part ${parts[startIndex + 1]}'.toLowerCase();
      if (compound.contains('fluid ounce') || compound.contains('fl oz')) {
        return {'value': _normalizeUnit('ml'), 'endIndex': startIndex + 2};
      }
    }

    return null;
  }

  // Normalize units using your existing UnitNormalizer
  static String _normalizeUnit(String unit) {
    return UnitNormalizer.normalize(unit);
  }

  // Helper parsing methods
  static String _parseToString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    
    String result;
    if (value is String) {
      result = value;
    } else if (value is List) {
      result = value.map((e) => e.toString()).join(', ');
    } else if (value is Map && value.containsKey('text')) {
      result = value['text'].toString();
    } else {
      result = value.toString();
    }
    
    // Decode HTML entities
    return _htmlUnescape.convert(result);
  }

  static String _parseCategory(dynamic categoryData) {
    if (categoryData == null) return 'Főétel';

    String result;
    if (categoryData is String) {
      result = categoryData;
    } else if (categoryData is List) {
      result = categoryData.isNotEmpty ? categoryData.first.toString() : 'Főétel';
    } else {
      result = categoryData.toString();
    }

    // Decode HTML entities
    return _htmlUnescape.convert(result);
  }

  static String? _parseInstructions(dynamic instructionsData) {
    if (instructionsData == null) return null;

    String result;
    
    if (instructionsData is String) {
      result = instructionsData.trim();
    } else if (instructionsData is List) {
      result = instructionsData.map((item) {
        if (item is String) return item;
        if (item is Map && item.containsKey('text')) {
          return item['text'].toString();
        }
        return item.toString();
      }).join('\n\n');
    } else if (instructionsData is Map && instructionsData.containsKey('text')) {
      result = instructionsData['text'].toString();
    } else {
      result = instructionsData.toString();
    }

    // Decode HTML entities
    return _htmlUnescape.convert(result);
  }

  static String? _parseImage(dynamic imageData) {
    if (imageData == null) return null;
    if (imageData is String) return imageData;
    if (imageData is List && imageData.isNotEmpty) {
      final first = imageData.first;
      if (first is String) return first;
      if (first is Map && first['url'] != null) return first['url'];
    }
    if (imageData is Map && imageData['url'] != null) return imageData['url'];
    return null;
  }

  static String _convertToAppCategory(dynamic categoryData) {
    final String raw = _parseCategory(categoryData).toLowerCase();

    if (raw.contains('főétel') || raw.contains('main') || raw.contains('chicken') ||
        raw.contains('csirke') || raw.contains('meat') || raw.contains('pasta') ||
        raw.contains('tészta')) {
      return 'Főétel';
    }
    if (raw.contains('leves') || raw.contains('soup') || raw.contains('broth')) return 'Leves';
    if (raw.contains('desszert') || raw.contains('dessert') || raw.contains('cake') ||
        raw.contains('sweet') || raw.contains('csoki') || raw.contains('süti') ||
        raw.contains('cookie') || raw.contains('torta')) {
      return 'Desszert';
    }
    if (raw.contains('péksütemény') || raw.contains('bread') || raw.contains('kenyér') ||
        raw.contains('baking') || raw.contains('pastry')) {
      return 'Péksütemény';
    }
    if (raw.contains('saláta') || raw.contains('salad')) return 'Saláta';
    if (raw.contains('ital') || raw.contains('drink') || raw.contains('beverage') ||
        raw.contains('smoothie') || raw.contains('cocktail')) {
      return 'Ital';
    }

    return 'Egyéb';
  }

  // Copy with method
  Recipe copyWith({
    String? id,
    String? userId,
    String? name,
    List<Ingredient>? ingredients,
    String? instructions,
    String? category,
    DateTime? createdAt,
    String? imageUrl,
    int? cookingTimeMinutes,
    int? servings, // NEW
  }) {
    return Recipe(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      cookingTimeMinutes: cookingTimeMinutes ?? this.cookingTimeMinutes,
      servings: servings ?? this.servings, // NEW
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
    required this.unit,
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

  // NEW: Helper to scale ingredient quantity
  Ingredient scaleQuantity(double multiplier) {
    if (quantity.isEmpty || unit == 'ízlés szerint') {
      return this; // Don't scale "to taste" items or empty quantities
    }

    try {
      final numericQuantity = double.parse(quantity);
      final scaledQuantity = numericQuantity * multiplier;
      
      // Format nicely: if it's a whole number, show without decimals
      final formattedQuantity = scaledQuantity == scaledQuantity.roundToDouble()
          ? scaledQuantity.round().toString()
          : scaledQuantity.toStringAsFixed(1);
      
      return Ingredient(
        name: name,
        quantity: formattedQuantity,
        unit: unit,
      );
    } catch (e) {
      // If parsing fails, return unchanged
      return this;
    }
  }
}