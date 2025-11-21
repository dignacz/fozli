//utils/unit_normalizer.dart
class UnitNormalizer {
  static const Map<String, String> unitMap = {
    // Angol -> HU
    'cup': 'csésze',
    'cups': 'csésze',
    'tbsp': 'ek',
    'tbs': 'ek',
    'tablespoon': 'ek',
    'tablespoons': 'ek',
    'tsp': 'tk',
    'teaspoon': 'tk',
    'teaspoons': 'tk',
    'oz': 'g',
    'ounce': 'g',
    'ounces': 'g',
    'lb': 'kg',
    'lbs': 'kg',
    'pound': 'kg',
    'pounds': 'kg',
    'ml': 'ml',
    'milliliter': 'ml',
    'milliliters': 'ml',
    'millilitre': 'ml',
    'millilitres': 'ml',
    'l': 'l',
    'liter': 'l',
    'liters': 'l',
    'litre': 'l',
    'litres': 'l',
    'dl': 'dl',
    'cl': 'cl',
    'g': 'g',
    'gram': 'g',
    'grams': 'g',
    'kg': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'dkg': 'dkg',
    'dekagram': 'dkg',
    
    // Darabszám és speciális
    'clove': 'gerezd',
    'cloves': 'gerezd',
    'slice': 'szelet',
    'slices': 'szelet',
    'can': 'doboz',
    'cans': 'doboz',
    'package': 'csomag',
    'packages': 'csomag',
    'pinch': 'csipet',
    'dash': 'csipet',
    'piece': 'db',
    'pieces': 'db',

    // Magyar
    'evőkanál': 'ek',
    'ek': 'ek',
    'kanál': 'ek',
    'tk': 'tk',
    'kávéskanál': 'tk',
    'teáskanál': 'tk',
    'csipet': 'csipet',
    'gerezd': 'gerezd',
    'szelet': 'szelet',
    'darab': 'db',
    'db': 'db',
    'csésze': 'csésze',
    'bögre': 'csésze',
    'csomag': 'csomag',
    'doboz': 'doboz',

    // Speciális
    'ízlés szerint': 'ízlés szerint',
  };

  // Make it explicitly static and non-nullable
  static String normalize(String? rawUnit) {
    // Handle null or empty
    if (rawUnit == null || rawUnit.isEmpty) return 'db';

    final lower = rawUnit.toLowerCase().trim();

    // Exact match first
    final exactMatch = unitMap[lower];
    if (exactMatch != null) {
      return exactMatch;
    }

    // Partial match (for variations)
    for (final entry in unitMap.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // Ha nem ismerjük, akkor db
    return 'db';
  }
}