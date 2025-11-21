// screens/recipe_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart';
import 'import_recipe_dialog.dart';
import '../utils/app_colors.dart';
import '../utils/recipe_categories.dart';

enum SortOption {
  alphabetical,
  category,
}

class RecipeListScreen extends StatefulWidget {
  final bool isPremium;

  const RecipeListScreen({super.key, this.isPremium = false});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  SortOption _currentSort = SortOption.alphabetical;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSortPreference();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      sortedRecipes.sort((a, b) {
        final categoryCompare = a.category.compareTo(b.category);
        if (categoryCompare != 0) return categoryCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }
    
    return sortedRecipes;
  }

  List<Recipe> _filterRecipes(List<Recipe> recipes) {
  print('🔍 Search query: "$_searchQuery"'); // Add this debug line
  
  if (_searchQuery.isEmpty) return recipes;
  
  final filtered = recipes.where((recipe) {
    final nameLower = recipe.name.toLowerCase();
    final categoryLower = recipe.category.toLowerCase();
    final ingredientsLower = recipe.ingredients
        .map((i) => i.name.toLowerCase())
        .join(' ');
    
    final matches = nameLower.contains(_searchQuery) ||
           categoryLower.contains(_searchQuery) ||
           ingredientsLower.contains(_searchQuery);
    
    print('  Recipe: ${recipe.name} - Match: $matches'); // Add this too
    
    return matches;
  }).toList();
  
  print('✅ Filtered: ${filtered.length} recipes'); // Add this
  
  return filtered;
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
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Keresés receptek között...',
                prefixIcon: const Icon(Icons.search, color: AppColors.coral),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.coral, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          
          // Sort buttons (removed import button)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
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

                final filteredRecipes = _filterRecipes(recipes);

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

                if (filteredRecipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nincs találat',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Próbálj meg más keresési kifejezést!',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final sortedRecipes = _sortRecipes(filteredRecipes);

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
    ImportRecipeDialog.show(context, isPremium: widget.isPremium);
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
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailScreen(recipe: recipe),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 95, // Fixed height for 2 rows
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image or Emoji - same size for both
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                  ? Image.network(
                      recipe.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildEmojiPlaceholder(categoryData);
                      },
                    )
                  : _buildEmojiPlaceholder(categoryData),
            ),
            const SizedBox(width: 12),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title - max 2 lines
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Subtitle info - with proper overflow handling
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: categoryData.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          recipe.category,
                          style: TextStyle(
                            color: categoryData.color.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${recipe.ingredients.length} hozzávaló${recipe.cookingTimeMinutes != null ? ' • ${recipe.cookingTimeMinutes} perc' : ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Arrow
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildEmojiPlaceholder(dynamic categoryData) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: categoryData.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          categoryData.emoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}