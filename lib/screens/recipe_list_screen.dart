// screens/recipe_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';
import 'recipe_detail_screen.dart';
import 'import_recipe_dialog.dart';
import 'collection_detail_screen.dart';
import '../utils/app_colors.dart';
import '../utils/recipe_categories.dart';

enum SortOption {
  alphabetical,
  category,
}

enum ViewMode {
  all, // Show all recipes
  folders, // Show folders view
}

class RecipeListScreen extends StatefulWidget {
  final bool isPremium;

  const RecipeListScreen({super.key, this.isPremium = true});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  SortOption _currentSort = SortOption.alphabetical;
  ViewMode _viewMode = ViewMode.all;
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
    if (_searchQuery.isEmpty) return recipes;
    
    return recipes.where((recipe) {
      final nameLower = recipe.name.toLowerCase();
      final categoryLower = recipe.category.toLowerCase();
      final ingredientsLower = recipe.ingredients
          .map((i) => i.name.toLowerCase())
          .join(' ');
      
      return nameLower.contains(_searchQuery) ||
             categoryLower.contains(_searchQuery) ||
             ingredientsLower.contains(_searchQuery);
    }).toList();
  }

  Future<void> _createCollection(String userId) async {
    final nameController = TextEditingController();
    String selectedEmoji = '📁';
    String selectedColor = 'FF8F8F';

    final templates = SeasonalCollections.getCollectionTemplates();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Új mappa létrehozása'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Mappa neve',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Vagy válassz sablonból:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: templates.map((template) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          nameController.text = template['name']!;
                          selectedEmoji = template['emoji']!;
                          selectedColor = template['color']!;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${template['color']}', radix: 16)).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(int.parse('FF${template['color']}', radix: 16)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(template['emoji']!, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 6),
                            Text(template['name']!),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Emoji: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(selectedEmoji, style: const TextStyle(fontSize: 32)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Mégse'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Létrehozás'),
            ),
          ],
        ),
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final collection = RecipeCollection(
          id: '',
          userId: userId,
          name: nameController.text.trim(),
          emoji: selectedEmoji,
          color: selectedColor,
          recipeIds: [],
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('recipeCollections')
            .add(collection.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${collection.name} létrehozva!')),
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
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('Nincs bejelentkezve'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // View mode toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<ViewMode>(
                    segments: const [
                      ButtonSegment<ViewMode>(
                        value: ViewMode.all,
                        label: Text('Összes recept'),
                        icon: Icon(Icons.restaurant_menu, size: 18),
                      ),
                      ButtonSegment<ViewMode>(
                        value: ViewMode.folders,
                        label: Text('Mappák'),
                        icon: Icon(Icons.folder, size: 18),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (Set<ViewMode> newSelection) {
                      setState(() {
                        _viewMode = newSelection.first;
                      });
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

          // Search Bar (only show in "all recipes" mode)
          if (_viewMode == ViewMode.all)
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
              child: Row(
                children: [
                  // Search field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Keresés...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.coral, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort buttons (compact icon-only)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSortButton(
                          icon: Icons.sort_by_alpha,
                          isSelected: _currentSort == SortOption.alphabetical,
                          onTap: () => _saveSortPreference(SortOption.alphabetical),
                          tooltip: 'ABC rendezés',
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.grey[300],
                        ),
                        _buildSortButton(
                          icon: Icons.category,
                          isSelected: _currentSort == SortOption.category,
                          onTap: () => _saveSortPreference(SortOption.category),
                          tooltip: 'Kategória rendezés',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: _viewMode == ViewMode.all
                ? _buildRecipesList(userId)
                : _buildFoldersView(userId),
          ),
        ],
      ),
      floatingActionButton: _viewMode == ViewMode.folders
          ? FloatingActionButton(
              onPressed: () => _createCollection(userId),
              backgroundColor: AppColors.sage,
              child: const Icon(Icons.create_new_folder, color: Colors.white),
            )
          : FloatingActionButton(
              onPressed: () {
                ImportRecipeDialog.show(context, isPremium: widget.isPremium);
              },
              backgroundColor: AppColors.coral,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildRecipesList(String userId) {
    return StreamBuilder<QuerySnapshot>(
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
    );
  }

  Widget _buildFoldersView(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipeCollections')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Hiba: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final collections = snapshot.data!.docs
            .map((doc) => RecipeCollection.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ))
            .toList();

        // Check if seasonal collection should exist
        final seasonalTemplate = SeasonalCollections.getSeasonalCollectionTemplate(userId);
        if (seasonalTemplate != null) {
          // Check if it exists in Firestore
          final exists = collections.any((c) => c.id == seasonalTemplate.id);
          
          if (!exists) {
            // Create it in Firestore
            FirebaseFirestore.instance
                .collection('recipeCollections')
                .doc(seasonalTemplate.id)
                .set(seasonalTemplate.toMap());
          }
        }

        // Filter collections: remove empty expired seasonal ones
        final visibleCollections = collections.where((c) {
          return SeasonalCollections.shouldShowSeasonalCollection(c);
        }).toList();

        // Sort: seasonal first, then by creation date
        visibleCollections.sort((a, b) {
          final aIsSeasonal = SeasonalCollections.isSeasonalCollection(a.id);
          final bIsSeasonal = SeasonalCollections.isSeasonalCollection(b.id);
          
          if (aIsSeasonal && !bIsSeasonal) return -1;
          if (!aIsSeasonal && bIsSeasonal) return 1;
          
          return b.createdAt.compareTo(a.createdAt);
        });

        if (visibleCollections.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Még nincsenek mappák',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nyomj a + gombra mappa létrehozásához!',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: visibleCollections.length,
          itemBuilder: (context, index) {
            final collection = visibleCollections[index];
            return _buildCollectionCard(collection);
          },
        );
      },
    );
  }

  Widget _buildCollectionCard(RecipeCollection collection) {
    final color = Color(int.parse('FF${collection.color}', radix: 16));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CollectionDetailScreen(collection: collection),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    collection.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${collection.recipeIds.length} recept',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
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
      color: Colors.white,
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
          height: 95,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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

  Widget _buildSortButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.coral : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}