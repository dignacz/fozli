// services/fozli_import_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImportResult {
  final bool success;
  final String message;
  final String? importedId;
  final String? importedType; // 'recipe' or 'shopping_list'
  final String? importedName;

  ImportResult({
    required this.success,
    required this.message,
    this.importedId,
    this.importedType,
    this.importedName,
  });
}

class FozliImportService {
  static Future<ImportResult> importFozliFile(String filePath) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return ImportResult(
          success: false,
          message: 'Nincs bejelentkezve',
        );
      }

      final file = File(filePath);
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final type = data['type'] as String?;
      final version = data['version'] as String?;

      if (type == null || version == null) {
        return ImportResult(
          success: false,
          message: 'Érvénytelen fájl formátum',
        );
      }

      if (type == 'recipe') {
        return await _importRecipe(data, userId);
      } else if (type == 'shopping_list') {
        return await _importShoppingList(data, userId);
      } else {
        return ImportResult(
          success: false,
          message: 'Ismeretlen fájl típus: $type',
        );
      }
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Hiba az importálás során: $e',
      );
    }
  }

  static Future<ImportResult> _importRecipe(
    Map<String, dynamic> data,
    String userId,
  ) async {
    try {
      final recipeData = Map<String, dynamic>.from(data);
      recipeData.remove('type');
      recipeData.remove('version');
      recipeData.remove('exportedAt');
      
      recipeData['userId'] = userId;
      
      // Keep createdAt as string - don't convert to Timestamp
      // The string will be stored as-is in Firestore

      final docRef = await FirebaseFirestore.instance
          .collection('recipes')
          .add(recipeData);

      return ImportResult(
        success: true,
        message: 'Recept sikeresen importálva!',
        importedId: docRef.id,
        importedType: 'recipe',
        importedName: recipeData['name'] as String?,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Hiba a recept importálása során: $e',
      );
    }
  }

  static Future<ImportResult> _importShoppingList(
    Map<String, dynamic> data,
    String userId,
  ) async {
    try {
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        return ImportResult(
          success: false,
          message: 'A bevásárlólista üres',
        );
      }

      final batch = FirebaseFirestore.instance.batch();
      
      for (var itemData in items) {
        final item = Map<String, dynamic>.from(itemData as Map<String, dynamic>);
        item['userId'] = userId;
        
        // Keep createdAt as string - don't convert to Timestamp

        final docRef = FirebaseFirestore.instance.collection('shoppingList').doc();
        batch.set(docRef, item);
      }

      await batch.commit();

      return ImportResult(
        success: true,
        message: '${items.length} tétel sikeresen importálva!',
        importedType: 'shopping_list',
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Hiba a bevásárlólista importálása során: $e',
      );
    }
  }
}