// services/ai_import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/shopping_list_item.dart';

class AiImportResult {
  final bool success;
  final String message;
  final String? importedId;
  final String? importedType; // 'recipe' or 'shopping_list'
  final dynamic importedData; // Recipe or List<ShoppingListItem>

  AiImportResult({
    required this.success,
    required this.message,
    this.importedId,
    this.importedType,
    this.importedData,
  });
}

class AiImportService {
  // Replace with your actual Vertex AI credentials
  static const String _projectId = 'gen-lang-client-0976886554';
  static const String _location = 'eu-central1'; // or your preferred location
  static const String _model = 'gemini-2.5-flash-lite'; // or gemini-1.5-pro

  // IMPORTANT: In production, use Firebase Functions or secure backend to handle API keys
  // Never hardcode API keys in client apps!
  static String? _apiKey; // Set this from secure storage or backend

  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }

  /// Import recipe from text
  static Future<AiImportResult> importRecipeFromText(String text) async {
    if (_apiKey == null) {
      return AiImportResult(
        success: false,
        message: 'API kulcs nincs beállítva',
      );
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return AiImportResult(
          success: false,
          message: 'Nincs bejelentkezve',
        );
      }

      final prompt = _getRecipeExtractionPrompt(text);
      final response = await _callGeminiApi(prompt);

      if (response == null) {
        return AiImportResult(
          success: false,
          message: 'Nem sikerült feldolgozni a szöveget',
        );
      }

      // Parse the JSON response
      final recipeData = jsonDecode(response) as Map<String, dynamic>;

      // Validate it's actually a recipe
      if (!_isValidRecipeData(recipeData)) {
        return AiImportResult(
          success: false,
          message: 'A szöveg nem tartalmaz érvényes recept adatokat',
        );
      }

      // Create Recipe object
      final recipe = Recipe.fromSchemaOrg(userId, recipeData);

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('recipes')
          .add(recipe.toMap());

      return AiImportResult(
        success: true,
        message: 'Recept sikeresen importálva: ${recipe.name}',
        importedId: docRef.id,
        importedType: 'recipe',
        importedData: recipe.copyWith(id: docRef.id),
      );
    } catch (e) {
      return AiImportResult(
        success: false,
        message: 'Hiba: $e',
      );
    }
  }

  /// Import recipe from image (OCR)
  static Future<AiImportResult> importRecipeFromImage(String imagePath) async {
    if (_apiKey == null) {
      return AiImportResult(
        success: false,
        message: 'API kulcs nincs beállítva',
      );
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return AiImportResult(
          success: false,
          message: 'Nincs bejelentkezve',
        );
      }

      // Read image and convert to base64
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final prompt = _getRecipeExtractionPrompt('');
      final response = await _callGeminiApiWithImage(prompt, base64Image);

      if (response == null) {
        return AiImportResult(
          success: false,
          message: 'Nem sikerült feldolgozni a képet',
        );
      }

      // Parse the JSON response
      final recipeData = jsonDecode(response) as Map<String, dynamic>;

      // Validate it's actually a recipe
      if (!_isValidRecipeData(recipeData)) {
        return AiImportResult(
          success: false,
          message: 'A kép nem tartalmaz érvényes recept adatokat',
        );
      }

      // Create Recipe object
      final recipe = Recipe.fromSchemaOrg(userId, recipeData);

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('recipes')
          .add(recipe.toMap());

      return AiImportResult(
        success: true,
        message: 'Recept sikeresen importálva: ${recipe.name}',
        importedId: docRef.id,
        importedType: 'recipe',
        importedData: recipe.copyWith(id: docRef.id),
      );
    } catch (e) {
      return AiImportResult(
        success: false,
        message: 'Hiba: $e',
      );
    }
  }

  /// Import shopping list from text
  static Future<AiImportResult> importShoppingListFromText(String text) async {
    if (_apiKey == null) {
      return AiImportResult(
        success: false,
        message: 'API kulcs nincs beállítva',
      );
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return AiImportResult(
          success: false,
          message: 'Nincs bejelentkezve',
        );
      }

      final prompt = _getShoppingListExtractionPrompt(text);
      final response = await _callGeminiApi(prompt);

      if (response == null) {
        return AiImportResult(
          success: false,
          message: 'Nem sikerült feldolgozni a szöveget',
        );
      }

      // Parse the JSON response
      final data = jsonDecode(response) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;

      if (items == null || items.isEmpty) {
        return AiImportResult(
          success: false,
          message: 'Nem található bevásárlólista adat',
        );
      }

      // Create shopping list items
      final batch = FirebaseFirestore.instance.batch();
      final shoppingItems = <ShoppingListItem>[];

      for (var itemData in items) {
        final item = ShoppingListItem(
          id: '',
          userId: userId,
          name: itemData['name'] ?? '',
          quantity: itemData['quantity']?.toString() ?? '',
          unit: itemData['unit'] ?? 'db',
          checked: false,
          createdAt: DateTime.now(),
        );

        final docRef = FirebaseFirestore.instance.collection('shoppingList').doc();
        batch.set(docRef, item.toMap());
        shoppingItems.add(item.copyWith(id: docRef.id));
      }

      await batch.commit();

      return AiImportResult(
        success: true,
        message: '${items.length} tétel sikeresen importálva!',
        importedType: 'shopping_list',
        importedData: shoppingItems,
      );
    } catch (e) {
      return AiImportResult(
        success: false,
        message: 'Hiba: $e',
      );
    }
  }

  /// Import shopping list from image (OCR)
  static Future<AiImportResult> importShoppingListFromImage(String imagePath) async {
    if (_apiKey == null) {
      return AiImportResult(
        success: false,
        message: 'API kulcs nincs beállítva',
      );
    }

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return AiImportResult(
          success: false,
          message: 'Nincs bejelentkezve',
        );
      }

      // Read image and convert to base64
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final prompt = _getShoppingListExtractionPrompt('');
      final response = await _callGeminiApiWithImage(prompt, base64Image);

      if (response == null) {
        return AiImportResult(
          success: false,
          message: 'Nem sikerült feldolgozni a képet',
        );
      }

      // Parse the JSON response
      final data = jsonDecode(response) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;

      if (items == null || items.isEmpty) {
        return AiImportResult(
          success: false,
          message: 'Nem található bevásárlólista adat a képen',
        );
      }

      // Create shopping list items
      final batch = FirebaseFirestore.instance.batch();
      final shoppingItems = <ShoppingListItem>[];

      for (var itemData in items) {
        final item = ShoppingListItem(
          id: '',
          userId: userId,
          name: itemData['name'] ?? '',
          quantity: itemData['quantity']?.toString() ?? '',
          unit: itemData['unit'] ?? 'db',
          checked: false,
          createdAt: DateTime.now(),
        );

        final docRef = FirebaseFirestore.instance.collection('shoppingList').doc();
        batch.set(docRef, item.toMap());
        shoppingItems.add(item.copyWith(id: docRef.id));
      }

      await batch.commit();

      return AiImportResult(
        success: true,
        message: '${items.length} tétel sikeresen importálva!',
        importedType: 'shopping_list',
        importedData: shoppingItems,
      );
    } catch (e) {
      return AiImportResult(
        success: false,
        message: 'Hiba: $e',
      );
    }
  }

  // Private helper methods

  static String _getRecipeExtractionPrompt(String text) {
    return '''
You are a strict recipe extraction assistant. Your ONLY job is to extract recipe information.

CRITICAL RULES:
1. ONLY extract if the input contains a CLEAR, COMPLETE recipe with ingredients and instructions
2. If the input is NOT a recipe (random text, shopping list, story, etc.), return: {"error": "not_a_recipe"}
3. Do NOT make up or invent any recipe information
4. Do NOT accept incomplete recipes (missing ingredients or instructions)
5. PRESERVE paragraph breaks in instructions using \\n\\n between paragraphs
6. ONLY extract fields that are EXPLICITLY present in the input - do NOT guess or estimate

Input text: $text

If this is a valid recipe, extract and return ONLY this JSON (no other text):
{
  "@type": "Recipe",
  "name": "Recipe name in Hungarian",
  "recipeCategory": "Category (Főétel, Desszert, Leves, Saláta, Ital, Péksütemény, or Egyéb)",
  "recipeIngredient": ["quantity unit ingredient", "quantity unit ingredient"],
  "recipeInstructions": "Step by step instructions in Hungarian. Preserve paragraph breaks with \\n\\n between paragraphs.",
  "totalTime": "PT30M" (ONLY if cooking time is EXPLICITLY mentioned, format: PT[minutes]M, otherwise null),
  "recipeYield": 4 (ONLY if servings/portions are EXPLICITLY mentioned, use number only, otherwise null),
  "image": "https://example.com/image.jpg" (ONLY if image URL found in text, otherwise null)
}

SERVINGS EXTRACTION (only when present):
- "4 servings" → "recipeYield": 4
- "6 adag" → "recipeYield": 6
- "serves 8" → "recipeYield": 8
- "2-4 people" → "recipeYield": 4 (use highest number)
- "egy tepsire" → "recipeYield": 4
- "25 db" → "recipeYield": 25
- NO servings mentioned → "recipeYield": null

COOKING TIME EXTRACTION (only when present):
- "30 minutes" → "totalTime": "PT30M"
- "1 hour" → "totalTime": "PT60M"
- "45 perc" → "totalTime": "PT45M"
- "1.5 hours" → "totalTime": "PT90M"
- NO time mentioned → "totalTime": null

IMPORTANT: 
- In recipeInstructions, use \\n\\n to separate different steps or paragraphs!
- Do NOT invent or estimate cooking time or servings if not explicitly stated
- Use null for totalTime, recipeYield, and image if not found in the input

If NOT a valid recipe, return: {"error": "not_a_recipe"}
''';
  }

  static String _getShoppingListExtractionPrompt(String text) {
    return '''
You are a strict shopping list extraction assistant. Your ONLY job is to extract shopping list items.

CRITICAL RULES:
1. ONLY extract if the input contains a CLEAR shopping/grocery list
2. If the input is NOT a shopping list (recipe, story, random text, etc.), return: {"error": "not_a_shopping_list"}
3. Do NOT make up items
4. Extract quantities and units when available

Input text: $text

If this is a valid shopping list, extract and return ONLY this JSON (no other text):
{
  "items": [
    {"name": "Item name in Hungarian", "quantity": "2", "unit": "kg"},
    {"name": "Item name", "quantity": "", "unit": "db"}
  ]
}

Valid units: db, csomag, doboz, kg, g, l, dl, ml

If NOT a valid shopping list, return: {"error": "not_a_shopping_list"}
''';
  }

  static Future<String?> _callGeminiApi(String prompt) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 1,
            'topP': 1,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        // ✅ STRIP MARKDOWN CODE BLOCKS
        if (text != null) {
          String cleaned = text.trim();
          cleaned = cleaned.replaceAll(RegExp(r'^```json\s*'), '');
          cleaned = cleaned.replaceAll(RegExp(r'^```\s*'), '');
          cleaned = cleaned.replaceAll(RegExp(r'\s*```$'), '');
          return cleaned.trim();
        }
      }
      return null;
    } catch (e) {
      print('API call error: $e');
      return null;
    }
  }

  static Future<String?> _callGeminiApiWithImage(String prompt, String base64Image) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 1,
            'topP': 1,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        // ✅ STRIP MARKDOWN CODE BLOCKS
        if (text != null) {
          String cleaned = text.trim();
          cleaned = cleaned.replaceAll(RegExp(r'^```json\s*'), '');
          cleaned = cleaned.replaceAll(RegExp(r'^```\s*'), '');
          cleaned = cleaned.replaceAll(RegExp(r'\s*```$'), '');
          return cleaned.trim();
        }
      }
      return null;
    } catch (e) {
      print('API call error: $e');
      return null;
    }
  }

  static bool _isValidRecipeData(Map<String, dynamic> data) {
    if (data.containsKey('error')) return false;
    
    return data.containsKey('name') &&
        data.containsKey('recipeIngredient') &&
        (data['recipeIngredient'] as List?)?.isNotEmpty == true;
  }
}

// Extension for ShoppingListItem
extension ShoppingListItemCopyWith on ShoppingListItem {
  ShoppingListItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? quantity,
    String? unit,
    bool? checked,
    DateTime? createdAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}