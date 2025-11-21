// services/url_recipe_import_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';

class UrlImportResult {
  final bool success;
  final String message;
  final Recipe? recipe;
  final String? recipeId;

  UrlImportResult({
    required this.success,
    required this.message,
    this.recipe,
    this.recipeId,
  });
}

class UrlRecipeImportService {

   static bool _isRecipeType(dynamic type) {
    if (type == null) return false;

    if (type is String) {
      return type.toLowerCase() == 'recipe';
    }

    if (type is List) {
      return type.any((e) => e.toString().toLowerCase() == 'recipe');
    }

    return false;
  }
  static Future<UrlImportResult> importFromUrl(String url) async {
    try {
      print('🔍 Starting URL import: $url');
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return UrlImportResult(
          success: false,
          message: 'Nincs bejelentkezve',
        );
      }


      // Validate URL
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return UrlImportResult(
          success: false,
          message: 'Érvénytelen URL formátum. Használj https:// vagy http:// címet.',
        );
      }

      print('✅ URL validated: $uri');

      // Fetch the webpage
      print('📡 Fetching webpage...');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Az oldal betöltése túl sokáig tart (15 másodperc)');
        },
      );

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        return UrlImportResult(
          success: false,
          message: 'Nem sikerült betölteni az oldalt (HTTP ${response.statusCode})',
        );
      }

      // Parse HTML
      print('🔨 Parsing HTML...');

      // Handle malformed content-type headers by using bodyBytes
String htmlContent;
try {
  htmlContent = response.body;
} catch (e) {
  // If response.body fails due to invalid content-type, use bodyBytes
  print('⚠️ Invalid content-type header, using bodyBytes...');
  htmlContent = utf8.decode(response.bodyBytes, allowMalformed: true);
}

final document = html_parser.parse(htmlContent);

      // Look for JSON-LD schema.org data
      Map<String, dynamic>? recipeData;
      
      final scriptElements = document.querySelectorAll('script[type="application/ld+json"]');
      print('📜 Found ${scriptElements.length} JSON-LD scripts');
      
      for (var script in scriptElements) {
        try {
          final jsonData = jsonDecode(script.text);
          print('🔍 Checking JSON-LD data...');
          
          // Handle both single object and array of objects
          List<dynamic> dataList = [];
          if (jsonData is List) {
            dataList = jsonData;
          } else {
            dataList = [jsonData];
          }

          // Find Recipe type
          for (var item in dataList) {
            if (item is Map<String, dynamic>) {
              if (_isRecipeType(item['@type'])) {
              recipeData = item;
              print('✅ Found Recipe in JSON-LD!');
              break;
            }
              
              // Also check for nested @graph structures
              if (item['@graph'] is List) {
                for (var graphItem in item['@graph']) {
                  if (graphItem is Map<String, dynamic> && 
                   _isRecipeType(graphItem['@type'])) {
                    recipeData = graphItem;
                    print('✅ Found Recipe in @graph!');
                    break;
                  }
                }
              }
            }
          }
          
          if (recipeData != null) break;
        } catch (e) {
          print('⚠️ Error parsing JSON-LD: $e');
          continue;
        }
      }

      if (recipeData == null) {
        print('❌ No JSON-LD found, trying microdata...');
        recipeData = _extractMicrodata(document);
      }

      if (recipeData == null) {
        return UrlImportResult(
          success: false,
          message: 'Nem található recept adat az oldalon.\n\nEz az oldal nem támogatja a schema.org/Recipe formátumot.\n\nPróbálj meg egy másik recept oldalt (pl. CookPad, Mindmegette).',
        );
      }

      print('🎯 Recipe data found: ${recipeData['name']}');
      print('   Ingredients: ${(recipeData['recipeIngredient'] as List?)?.length ?? 0}');

      // Convert to Recipe object
      final recipe = Recipe.fromSchemaOrg(userId, recipeData);
      print('✅ Recipe object created');

      // Save to Firestore
      print('💾 Saving to Firestore...');
      final docRef = await FirebaseFirestore.instance
          .collection('recipes')
          .add(recipe.toMap());

      print('✅ Saved with ID: ${docRef.id}');

      final savedRecipe = recipe.copyWith(id: docRef.id);

      return UrlImportResult(
        success: true,
        message: 'Recept sikeresen importálva: ${recipe.name}',
        recipe: savedRecipe,
        recipeId: docRef.id,
      );
    } catch (e, stackTrace) {
      print('❌ Error in URL import: $e');
      print('Stack trace: $stackTrace');
      
      return UrlImportResult(
        success: false,
        message: 'Hiba az importálás során:\n${e.toString()}',
      );
    }
  }

  static Map<String, dynamic>? _extractMicrodata(dynamic document) {
    print('🔍 Extracting microdata...');
    
    // Basic microdata extraction for Recipe itemtype
    final recipeElement = document.querySelector('[itemtype*="schema.org/Recipe"]');
    if (recipeElement == null) {
      print('❌ No microdata Recipe found');
      return null;
    }

    print('✅ Found microdata Recipe element');
    final data = <String, dynamic>{
      '@type': 'Recipe',
    };

    // Extract name
    final nameElement = recipeElement.querySelector('[itemprop="name"]');
    if (nameElement != null) {
      data['name'] = nameElement.text.trim();
      print('   Name: ${data['name']}');
    }

    // Extract image
    final imageElement = recipeElement.querySelector('[itemprop="image"]');
    if (imageElement != null) {
      data['image'] = imageElement.attributes['src'] ?? imageElement.attributes['content'];
      print('   Image: ${data['image']}');
    }

    // Extract instructions
    final instructionsElements = recipeElement.querySelectorAll('[itemprop="recipeInstructions"]');
    if (instructionsElements.isNotEmpty) {
      data['recipeInstructions'] = instructionsElements
          .map((e) => e.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n\n');
      print('   Instructions: ${data['recipeInstructions']?.toString().substring(0, 50)}...');
    }

    // Extract ingredients
    final ingredientElements = recipeElement.querySelectorAll('[itemprop="recipeIngredient"]');
    if (ingredientElements.isNotEmpty) {
      data['recipeIngredient'] = ingredientElements
          .map((e) => e.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      print('   Ingredients: ${(data['recipeIngredient'] as List).length}');
    }

    // Extract cooking time
    final timeElement = recipeElement.querySelector('[itemprop="totalTime"]');
    if (timeElement != null) {
      data['totalTime'] = timeElement.attributes['content'] ?? timeElement.text.trim();
      print('   Time: ${data['totalTime']}');
    }

    // Extract category
    final categoryElement = recipeElement.querySelector('[itemprop="recipeCategory"]');
    if (categoryElement != null) {
      data['recipeCategory'] = categoryElement.text.trim();
      print('   Category: ${data['recipeCategory']}');
    }

    return data.containsKey('name') ? data : null;
  }
}