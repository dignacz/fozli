// screens/recipe_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import '../utils/app_colors.dart';
import '../utils/recipe_categories.dart';

enum SortOption {
  alphabetical,
  category,
}

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  SortOption _currentSort = SortOption.alphabetical;

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final sortIndex = prefs.getInt('recipe_sort_option') ?? 0;
    setState(() {
      _currentSort = SortOption.values[sortIndex];
    });
  }

  Future<void> _saveSortPreference(SortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('recipe_sort_option', option.index);
    setState(() {
      _currentSort = option;
    });
  }

  List<Recipe> _sortRecipes(List<Recipe> recipes) {
    final sortedRecipes = List<Recipe>.from(recipes);
    
    if (_currentSort == SortOption.alphabetical) {
      sortedRecipes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // Sort by category, then alphabetically within each category
      sortedRecipes.sort((a, b) {
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    
    return sortedRecipes;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('Nincs bejelentkezve'));
    }

    return Scaffold(
      body: Column(
        children: [
          // Sort Options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.sort, color: AppColors.coral, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Rendezés:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<SortOption>(
                    segments: const [
                      ButtonSegment<SortOption>(
                        value: SortOption.alphabetical,
                        label: Text('ABC'),
                        icon: Icon(Icons.sort_by_alpha, size: 18),
                      ),
                      ButtonSegment<SortOption>(
                        value: SortOption.category,
                        label: Text('Kategória'),
                        icon: Icon(Icons.category, size: 18),
                      ),
                    ],
                    selected: {_currentSort},
                    onSelectionChanged: (Set<SortOption> newSelection) {
                      _saveSortPreference(newSelection.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.coral;
                          }
                          return Colors.white;
                        },
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                        (Set<WidgetState> states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return Colors.black87;
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Recipe List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recipes')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Hiba: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final recipes = snapshot.data!.docs
                    .map((doc) => Recipe.fromMap(
                          doc.id,
                          doc.data() as Map<String, dynamic>,
                        ))
                    .toList();

                if (recipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 60,
                            color: AppColors.coral,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Még nincsenek receptek',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nyomj a + gombra az első recept hozzáadásához!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                // Sort recipes based on current selection
                final sortedRecipes = _sortRecipes(recipes);

                // Group by category if category sort is selected
                if (_currentSort == SortOption.category) {
                  return _buildCategoryGroupedList(sortedRecipes);
                } else {
                  return _buildSimpleList(sortedRecipes);
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRecipeScreen(),
            ),
          );
        },
        backgroundColor: AppColors.coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSimpleList(List<Recipe> recipes) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _buildRecipeCard(recipe);
      },
    );
  }

  Widget _buildCategoryGroupedList(List<Recipe> recipes) {
    // Group recipes by category
    final Map<String, List<Recipe>> groupedRecipes = {};
    for (var recipe in recipes) {
      if (!groupedRecipes.containsKey(recipe.category)) {
        groupedRecipes[recipe.category] = [];
      }
      groupedRecipes[recipe.category]!.add(recipe);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: groupedRecipes.length,
      itemBuilder: (context, index) {
        final category = groupedRecipes.keys.elementAt(index);
        final categoryRecipes = groupedRecipes[category]!;
        final categoryData = RecipeCategories.getCategory(category);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    categoryData.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: categoryData.color,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${categoryRecipes.length})',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Recipes in this category
            ...categoryRecipes.map((recipe) => _buildRecipeCard(recipe)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final categoryData = RecipeCategories.getCategory(recipe.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryData.color,
          child: Text(
            categoryData.emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          recipe.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: categoryData.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                recipe.category,
                style: TextStyle(
                  color: categoryData.color.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '• ${recipe.ingredients.length} hozzávaló',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        },
      ),
    );
  }
}