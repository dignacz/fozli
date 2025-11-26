// services/fozli_import_service.dart - WITH DEBUG PRINTS
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
  static Future<ImportResult> importFozliFile(
    String filePath, {
    String? listId,
    String? allowedType,
  }) async {
    print('🔍 DEBUG: importFozliFile called');
    print('🔍 DEBUG: allowedType = $allowedType');
    print('🔍 DEBUG: listId = $listId');
    
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

      print('🔍 DEBUG: File type = $type');
      print('🔍 DEBUG: File version = $version');

      if (type == null || version == null) {
        return ImportResult(
          success: false,
          message: 'Érvénytelen fájl formátum',
        );
      }

      // ✅ CHECK: Are we importing the right type on the right page?
      print('🔍 DEBUG: Checking validation...');
      print('🔍 DEBUG: allowedType != null: ${allowedType != null}');
      print('🔍 DEBUG: type != allowedType: ${type != allowedType}');
      
      if (allowedType != null && type != allowedType) {
        print('❌ DEBUG: VALIDATION FAILED!');
        print('❌ DEBUG: type = $type, allowedType = $allowedType');
        
        if (type == 'recipe' && allowedType == 'shopping_list') {
          print('❌ DEBUG: Returning recipe error');
          return ImportResult(
            success: false,
            message: 'Recept fájlt nem lehet importálni a bevásárlólista oldalon!',
          );
        } else if (type == 'shopping_list' && allowedType == 'recipe') {
          print('❌ DEBUG: Returning shopping list error');
          return ImportResult(
            success: false,
            message: 'Bevásárlólista fájlt nem lehet importálni a recept oldalon!',
          );
        }
      } else {
        print('✅ DEBUG: Validation passed or skipped');
      }

      if (type == 'recipe') {
        print('✅ DEBUG: Importing recipe');
        return await _importRecipe(data, userId);
      } else if (type == 'shopping_list') {
        print('✅ DEBUG: Importing shopping list');
        return await _importShoppingList(data, userId, listId: listId);
      } else {
        return ImportResult(
          success: false,
          message: 'Ismeretlen fájl típus: $type',
        );
      }
    } catch (e) {
      print('❌ DEBUG: Exception: $e');
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
    String userId, {
    String? listId,
  }) async {
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
        
        if (listId != null && listId.isNotEmpty) {
          item['listId'] = listId;
        }

        final docRef = FirebaseFirestore.instance.collection('shoppingListItems').doc();
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