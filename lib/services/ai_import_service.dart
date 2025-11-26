// services/ai_import_service.dart - FIXED FOR VOICE INPUT
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

  /// Import shopping list from text (FIXED FOR VOICE INPUT!)
  static Future<AiImportResult> importShoppingListFromText(
    String text, {
    String? listId,
  }) async {
    if (_apiKey == null) {
      return AiImportResult(
        success: false,
        message: 'API kulcs nincs beállítva',
      );
    }

    try {
      debugPrint('🎤 Voice input received: "$text"');
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return AiImportResult(
          success: false,
          message: 'Nincs bejelentkezve',
        );
      }

      final prompt = _getShoppingListExtractionPrompt(text);
      final response = await _callGeminiApi(prompt);

      debugPrint('🤖 AI raw response: $response');

      if (response == null) {
        return AiImportResult(
          success: false,
          message: 'Nem sikerült feldolgozni a szöveget',
        );
      }

      // Parse the JSON response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ JSON parse error: $e');
        debugPrint('Response was: $response');
        return AiImportResult(
          success: false,
          message: 'Hibás válasz formátum az AI-tól',
        );
      }

      // Check for error response
      if (data.containsKey('error')) {
        debugPrint('❌ AI returned error: ${data['error']}');
        return AiImportResult(
          success: false,
          message: 'Nem található bevásárlólista adat',
        );
      }

      final items = data['items'] as List<dynamic>?;

      if (items == null || items.isEmpty) {
        debugPrint('❌ No items found in response');
        return AiImportResult(
          success: false,
          message: 'Nem található bevásárlólista adat',
        );
      }

      debugPrint('✅ Found ${items.length} items');

      // Create shopping list items
      final batch = FirebaseFirestore.instance.batch();
      final shoppingItems = <ShoppingListItem>[];

      for (var itemData in items) {
        final name = itemData['name']?.toString() ?? '';
        final quantity = itemData['quantity']?.toString() ?? '1';
        final unit = itemData['unit']?.toString() ?? 'db';
        
        debugPrint('  📦 Item: $name ($quantity $unit)');

        // Create item with listId if provided
        final itemMap = {
          'userId': userId,
          'name': name,
          'quantity': quantity,
          'unit': unit,
          'checked': false,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        // Add listId if provided (for the current shopping list)
        if (listId != null && listId.isNotEmpty) {
          itemMap['listId'] = listId;
          debugPrint('    ✅ Assigning to list: $listId');
        }

        final docRef = FirebaseFirestore.instance.collection('shoppingListItems').doc();
        batch.set(docRef, itemMap);
        
        final item = ShoppingListItem(
          id: docRef.id,
          userId: userId,
          name: name,
          quantity: quantity,
          unit: unit,
          checked: false,
          createdAt: DateTime.now(),
        );
        shoppingItems.add(item);
      }

      await batch.commit();

      debugPrint('✅ Successfully saved ${items.length} items to Firestore');

      return AiImportResult(
        success: true,
        message: '${items.length} tétel sikeresen importálva!',
        importedType: 'shopping_list',
        importedData: shoppingItems,
      );
    } catch (e) {
      debugPrint('❌ Exception in importShoppingListFromText: $e');
      return AiImportResult(
        success: false,
        message: 'Hiba: $e',
      );
    }
  }

  /// Import shopping list from image (OCR)
  static Future<AiImportResult> importShoppingListFromImage(
    String imagePath, {
    String? listId,
  }) async {
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
      
      // Check for error response
      if (data.containsKey('error')) {
        return AiImportResult(
          success: false,
          message: 'Nem található bevásárlólista adat a képen',
        );
      }
      
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
          quantity: itemData['quantity']?.toString() ?? '1',
          unit: itemData['unit'] ?? 'db',
          checked: false,
          createdAt: DateTime.now(),
        );

        final docRef = FirebaseFirestore.instance.collection('shoppingListItems').doc();
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

  // 🎤 FIXED FOR VOICE INPUT!
  static String _getShoppingListExtractionPrompt(String text) {
    return '''
You are a shopping list extraction assistant. Extract shopping items from ANY format.

ACCEPT THESE FORMATS:
✅ List format: "tej, kenyér, tojás"
✅ Natural speech: "tej egy liter kenyér három tojás"
✅ Sentence: "kellene tej és kenyér meg tojás is"
✅ Voice input: "vegyünk tejet kenyeret és tojást"
✅ With quantities: "2 liter tej 1 kenyér 6 tojás"

YOUR JOB: Extract EVERY food/grocery item mentioned!

Input text: "$text"

Return ONLY valid JSON (no markdown, no code blocks):
{
  "items": [
    {"name": "Tej", "quantity": "1", "unit": "liter"},
    {"name": "Kenyér", "quantity": "1", "unit": "db"},
    {"name": "Tojás", "quantity": "3", "unit": "db"}
  ]
}

QUANTITY RULES:
- "egy liter" → "1 liter"
- "három" → "3"
- "2 kg" → "2 kg"
- "egy" → "1"
- No quantity mentioned → "1" and unit "db"

COMMON UNITS: db, csomag, doboz, kg, g, liter, dl, ml, csomag

IMPORTANT: 
- Extract items even if not in list format!
- If you find ANY food/grocery items, extract them!
- Use "db" (darab) as default unit if not specified
- Use "1" as default quantity if not specified
- DO NOT return error - try your best to find items!

Examples:
Input: "tej kenyér tojás"
Output: {"items": [{"name": "Tej", "quantity": "1", "unit": "db"}, {"name": "Kenyér", "quantity": "1", "unit": "db"}, {"name": "Tojás", "quantity": "1", "unit": "db"}]}

Input: "tej egy liter kenyér három tojás"
Output: {"items": [{"name": "Tej", "quantity": "1", "unit": "liter"}, {"name": "Kenyér", "quantity": "1", "unit": "db"}, {"name": "Tojás", "quantity": "3", "unit": "db"}]}

Now extract from the input text above. Return ONLY the JSON, nothing else!
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
      debugPrint('API call error: $e');
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
      debugPrint('API call error: $e');
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