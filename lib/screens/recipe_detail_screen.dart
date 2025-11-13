import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  late Recipe _recipe;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
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

      final batch = FirebaseFirestore.instance.batch();

      for (var ingredient in _recipe.ingredients) {
        final item = ShoppingListItem(
          id: '',
          userId: userId,
          name: ingredient.name,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          checked: false,
          createdAt: DateTime.now(),
        );

        final docRef = FirebaseFirestore.instance.collection('shoppingList').doc();
        batch.set(docRef, item.toMap());
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hozzávalók hozzáadva a bevásárlólistához!'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe.name),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        actions: [
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
                await _loadRecipe(); // Reload the recipe after editing
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
                            ElevatedButton.icon(
                              onPressed: () => _addIngredientsToShoppingList(context),
                              icon: const Icon(Icons.shopping_cart, size: 18),
                              label: const Text('Listához'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.coral,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        ..._recipe.ingredients.map((ingredient) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: AppColors.coral,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      ingredient.name,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
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
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),


                // Instructions Card (if exists)
                if (_recipe.instructions != null && _recipe.instructions!.isNotEmpty)
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

                   // Naptár
const SizedBox(height: 16),
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () => _logCookedToday(),
    icon: const Icon(Icons.check_circle_outline),
    label: const Text('Ma megfőztem ezt!'),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.lavender,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
  ),
),
              ],
            ),
    );
  }
}