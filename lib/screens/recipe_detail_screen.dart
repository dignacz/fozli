//screens/recipe_detail_screen.dart

import '../utils/recipe_categories.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../models/shopping_list_item.dart';
import '../models/cooking_log.dart';
import '../utils/app_colors.dart';
import '../screens/edit_recipe_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic> _convertTimestampsToStrings(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _convertTimestampsToStrings(item);
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertTimestampsToStrings(value);
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }

  late Recipe _recipe;
  bool _isLoading = false;
  bool _isCookedToday = false;
  late List<bool> _selectedIngredients; // Track selected ingredients

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _selectedIngredients = List.filled(_recipe.ingredients.length, false); // All selected by default
    _checkIfCookedToday();
  }

  void _toggleAllIngredients() {
    final allSelected = _selectedIngredients.every((selected) => selected);
    setState(() {
      _selectedIngredients = List.filled(_recipe.ingredients.length, !allSelected);
    });
  }

  Future<void> _checkIfCookedToday() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance
          .collection('cookingLogs')
          .where('userId', isEqualTo: userId)
          .where('recipeId', isEqualTo: _recipe.id)
          .get();

      final cookedToday = snapshot.docs.any((doc) {
        final log = CookingLog.fromMap(doc.id, doc.data());
        return log.cookedDate.isAfter(startOfDay) &&
            log.cookedDate.isBefore(endOfDay);
      });

      if (mounted) {
        setState(() {
          _isCookedToday = cookedToday;
        });
      }
    } catch (e) {
      print('Error checking if cooked today: $e');
    }
  }

  Future<void> _logCookedToday() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final log = CookingLog(
        id: '',
        userId: userId,
        recipeId: _recipe.id,
        recipeName: _recipe.name,
        cookedDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('cookingLogs')
          .add(log.toMap());

      if (mounted) {
        setState(() {
          _isCookedToday = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hozzáadva a naptárhoz!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  Future<void> _loadRecipe() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipe.id)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _recipe = Recipe.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          _selectedIngredients = List.filled(_recipe.ingredients.length, false); // Changed to false
        });
      }
    } catch (e) {
      print('Error loading recipe: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addIngredientsToShoppingList(BuildContext context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Nincs bejelentkezve');

      // Get only selected ingredients
      final selectedIngredientsList = <Ingredient>[];
      for (int i = 0; i < _recipe.ingredients.length; i++) {
        if (_selectedIngredients[i]) {
          selectedIngredientsList.add(_recipe.ingredients[i]);
        }
      }

      if (selectedIngredientsList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Válassz ki legalább egy hozzávalót!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      for (var ingredient in selectedIngredientsList) {
        final item = ShoppingListItem(
          id: '',
          userId: userId,
          name: ingredient.name,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          checked: false,
          createdAt: DateTime.now(),
        );

        final docRef =
            FirebaseFirestore.instance.collection('shoppingList').doc();
        batch.set(docRef, item.toMap());
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedIngredientsList.length} hozzávaló hozzáadva a bevásárlólistához!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  Future<void> _showShareOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet, color: AppColors.coral),
              title: const Text('Megosztás szövegként'),
              subtitle: const Text('Könnyen olvasható formátum'),
              onTap: () {
                Navigator.pop(context);
                _shareAsText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppColors.coral),
              title: const Text('Megosztás .fozli fájlként'),
              subtitle: const Text('Megosztás más eszközökkel'),
              onTap: () {
                Navigator.pop(context);
                _shareAsFozli();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: AppColors.coral),
              title: const Text('Mentés eszközre'),
              subtitle: const Text('Letöltés a Letöltések mappába'),
              onTap: () {
                Navigator.pop(context);
                _downloadFozli();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsText() async {
    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('📖 ${_recipe.name}');
      buffer.writeln();
      buffer.writeln('Kategória: ${_recipe.category}');
      buffer.writeln();
      buffer.writeln('🛒 Hozzávalók:');
      for (var ingredient in _recipe.ingredients) {
        buffer.writeln('  • ${ingredient.name} - ${ingredient.quantity} ${ingredient.unit}');
      }
      
      if (_recipe.instructions != null && _recipe.instructions!.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('👨‍🍳 Elkészítés:');
        buffer.writeln(_recipe.instructions);
      }
      
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('Megosztva a Főzli alkalmazásból');

      await Share.share(
        buffer.toString(),
        subject: _recipe.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  Future<void> _downloadFozli() async {
    try {
      final recipeData = _recipe.toMap();
      recipeData.remove('userId');
      recipeData.remove('id');
      
      final cleanedData = _convertTimestampsToStrings(recipeData);
      
      final jsonData = jsonEncode(
        {
          'type': 'recipe',
          'version': '1.0',
          ...cleanedData,
          'exportedAt': DateTime.now().toIso8601String(),
        },
        toEncodable: (dynamic item) {
          if (item is DateTime) {
            return item.toIso8601String();
          }
          return item;
        },
      );

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        throw Exception('Letöltések mappa nem található');
      }

      final fileName = '${_recipe.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.fozli';
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonData, encoding: utf8); // UTF-8 encoding!

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mentve: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Rendben',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  Future<void> _shareAsFozli() async {
    try {
      final recipeData = _recipe.toMap();
      recipeData.remove('userId');
      recipeData.remove('id');
      
      final cleanedData = _convertTimestampsToStrings(recipeData);
      
      final jsonData = jsonEncode(
        {
          'type': 'recipe',
          'version': '1.0',
          ...cleanedData,
          'exportedAt': DateTime.now().toIso8601String(),
        },
        toEncodable: (dynamic item) {
          if (item is DateTime) {
            return item.toIso8601String();
          }
          return item;
        },
      );

      final tempDir = Directory.systemTemp;
      final fileName = '${_recipe.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}.fozli';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonData, encoding: utf8); // UTF-8 encoding!

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: _recipe.name,
        text: 'Főzli recept: ${_recipe.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecipe(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recept törlése'),
        content: const Text('Biztosan törölni szeretnéd ezt a receptet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(_recipe.id)
            .delete();

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recept törölve')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hiba: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _selectedIngredients.every((selected) => selected);
    final selectedCount = _selectedIngredients.where((selected) => selected).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe.name),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showShareOptions,
            tooltip: 'Megosztás',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditRecipeScreen(recipe: _recipe),
                ),
              );

              if (result == true) {
                await _loadRecipe();
              }
            },
            tooltip: 'Szerkesztés',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteRecipe(context),
            tooltip: 'Törlés',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
    : ListView(
        padding: const EdgeInsets.all(16),
        children: [
                // Category and Cooking Time bubbles
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Category bubble
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: RecipeCategories.getCategory(_recipe.category)
                            .color
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            RecipeCategories.getCategory(_recipe.category).emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _recipe.category,
                            style: TextStyle(
                              color: RecipeCategories.getCategory(_recipe.category)
                                  .color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cooking time bubble (same height as category)
                    if (_recipe.cookingTimeMinutes != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10, // Same padding as category
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lavender.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.lavender.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer, size: 20, color: AppColors.lavender), // Same size as emoji
                            const SizedBox(width: 8),
                            Text(
                              '${_recipe.cookingTimeMinutes} perc',
                              style: const TextStyle(
                                color: AppColors.lavender,
                                fontWeight: FontWeight.bold, // Match category style
                                fontSize: 16, // Same as category
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Recipe Title - NEW! (below bubbles, above image)
  Text(
    _recipe.name,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
    textAlign: TextAlign.center,
  ),
  const SizedBox(height: 16),

                // Recipe Image
                if (_recipe.imageUrl != null && _recipe.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _recipe.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppColors.coral,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  _buildPlaceholderImage(),

                const SizedBox(height: 16),

                // Ingredients Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hozzávalók',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            TextButton.icon(
                              onPressed: _toggleAllIngredients,
                              icon: Icon(
                                allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 18,
                              ),
                              label: Text(
                                allSelected ? 'Törlés' : 'Mind',
                                style: const TextStyle(fontSize: 13),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.coral,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        ..._recipe.ingredients.asMap().entries.map((entry) {
                          final index = entry.key;
                          final ingredient = entry.value;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedIngredients[index] = !_selectedIngredients[index];
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _selectedIngredients[index],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedIngredients[index] = value ?? false;
                                      });
                                    },
                                    activeColor: AppColors.coral,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ingredient.name,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${ingredient.quantity} ${ingredient.unit}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: selectedCount > 0 
                                ? () => _addIngredientsToShoppingList(context)
                                : null,
                            icon: const Icon(Icons.shopping_cart, size: 18),
                            label: Text(
                              selectedCount > 0
                                  ? 'Kijelöltek listához ($selectedCount)'
                                  : 'Válassz hozzávalókat',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.coral,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              disabledBackgroundColor: Colors.grey[300],
                              disabledForegroundColor: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions Card
                if (_recipe.instructions != null &&
                    _recipe.instructions!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Elkészítés',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Divider(height: 24),
                          Text(
                            _recipe.instructions!,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Cooked Today Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCookedToday ? null : () => _logCookedToday(),
                    icon: Icon(
                      _isCookedToday ? Icons.check_circle : Icons.check_circle_outline,
                    ),
                    label: Text(
                      _isCookedToday
                          ? 'Ma már elkészítetted!'
                          : 'Ma elkészítettem ezt!',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCookedToday 
                          ? Colors.grey 
                          : AppColors.lavender,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      disabledBackgroundColor: Colors.grey[400],
                      disabledForegroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: AppColors.coral.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Nincs kép',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}