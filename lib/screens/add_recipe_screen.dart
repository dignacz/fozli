// screens/add_recipe_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../utils/app_colors.dart';
import '../utils/recipe_categories.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _cookingTimeController = TextEditingController();
  final _servingsController = TextEditingController(); // NEW
  final List<IngredientInput> _ingredients = [IngredientInput()];
  bool _isLoading = false;
  String _selectedCategory = 'Főétel';

  // Measurement units in Hungarian
  static const List<String> _measurementUnits = [
    'db',
    'g',
    'dkg',
    'kg',
    'ml',
    'dl',
    'l',
    'ek',
    'tk',
    'csipet',
    'csomag',
    'doboz',
    'gerezd',
    'ízlés szerint',
  ];

  void _addIngredient() {
    setState(() {
      _ingredients.insert(0, IngredientInput());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      if (_ingredients.length > 1) {
        _ingredients.removeAt(index);
      }
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final validIngredients = _ingredients
        .where((i) => i.nameController.text.isNotEmpty)
        .toList();

    if (validIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add meg legalább egy hozzávalót!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Nincs bejelentkezve');

      // Parse cooking time
      int? cookingTime;
      if (_cookingTimeController.text.isNotEmpty) {
        cookingTime = int.tryParse(_cookingTimeController.text);
        if (cookingTime != null && cookingTime < 0) {
          cookingTime = null;
        }
      }

      // NEW: Parse servings
      int? servings;
      if (_servingsController.text.isNotEmpty) {
        servings = int.tryParse(_servingsController.text);
        if (servings != null && servings < 1) {
          servings = null;
        }
      }

      final recipe = Recipe(
        id: '',
        userId: userId,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        ingredients: validIngredients
            .map((i) => Ingredient(
                  name: i.nameController.text.trim(),
                  quantity: i.quantityController.text.trim(),
                  unit: i.selectedUnit,
                ))
            .toList(),
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        cookingTimeMinutes: cookingTime,
        servings: servings, // NEW
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance.collection('recipes').add(recipe.toMap());

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recept sikeresen mentve!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Új recept'),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Recipe Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recept neve',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kérlek add meg a recept nevét';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category Selector
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategória',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: RecipeCategories.getCategoryNames().map((String category) {
                final categoryData = RecipeCategories.getCategory(category);
                return DropdownMenuItem<String>(
                  value: category,
                  child: Row(
                    children: [
                      Text(
                        categoryData.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(category),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue ?? 'Főétel';
                });
              },
            ),
            const SizedBox(height: 16),

            // Image URL
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Kép URL (opcionális)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) {
                    return 'Érvénytelen URL formátum';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // NEW: Two-column layout for Cooking Time and Servings
            Row(
              children: [
                // Cooking Time
                Expanded(
                  child: TextFormField(
                    controller: _cookingTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Idő (perc)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer),
                      hintText: '30',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final minutes = int.tryParse(value);
                        if (minutes == null || minutes < 0) {
                          return 'Érvénytelen';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Servings
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    decoration: const InputDecoration(
                      labelText: 'Adag',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.restaurant),
                      hintText: '4',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final servings = int.tryParse(value);
                        if (servings == null || servings < 1) {
                          return 'Min 1';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Ingredients Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hozzávalók',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add),
                  label: const Text('Hozzáadás'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Ingredients List
            ..._ingredients.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ingredient.nameController,
                            decoration: const InputDecoration(
                              labelText: 'Név',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _removeIngredient(index),
                          icon: const Icon(Icons.delete_outline),
                          color: _ingredients.length > 1 ? Colors.red : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ingredient.quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Mennyiség',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: ingredient.selectedUnit,
                            decoration: const InputDecoration(
                              labelText: 'Egység',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: _measurementUnits.map((String unit) {
                              return DropdownMenuItem<String>(
                                value: unit,
                                child: Text(unit),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                ingredient.selectedUnit = newValue ?? 'db';
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),

            // Instructions
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Elkészítés (opcionális)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Mentés',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _imageUrlController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose(); // NEW
    for (var ingredient in _ingredients) {
      ingredient.dispose();
    }
    super.dispose();
  }
}

class IngredientInput {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  String selectedUnit = 'db';

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}