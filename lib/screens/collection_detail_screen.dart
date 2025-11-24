// screens/collection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../models/recipe_collection.dart';
import '../utils/app_colors.dart';
import '../utils/recipe_categories.dart';
import 'recipe_detail_screen.dart';

enum SortOption {
  alphabetical,
  category,
}

class CollectionDetailScreen extends StatefulWidget {
  final RecipeCollection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late RecipeCollection _collection;
  SortOption _currentSort = SortOption.alphabetical;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
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
    final sortIndex = prefs.getInt('collection_sort_option') ?? 0;
    setState(() {
      _currentSort = SortOption.values[sortIndex];
    });
  }

  Future<void> _saveSortPreference(SortOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('collection_sort_option', option.index);
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

  Future<void> _addRecipeToCollection() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Get all recipes
    final recipesSnapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .where('userId', isEqualTo: userId)
        .get();

    final allRecipes = recipesSnapshot.docs
        .map((doc) => Recipe.fromMap(doc.id, doc.data()))
        .toList();

    // Filter out recipes already in collection
    final availableRecipes = allRecipes
        .where((recipe) => !_collection.recipeIds.contains(recipe.id))
        .toList();

    if (availableRecipes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minden recept már benne van a mappában!')),
        );
      }
      return;
    }

    // Sort available recipes alphabetically
    availableRecipes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final selectedRecipes = await showDialog<List<Recipe>>(
      context: context,
      builder: (context) => _RecipeSelectionDialog(recipes: availableRecipes),
    );

    if (selectedRecipes != null && selectedRecipes.isNotEmpty) {
      try {
        final updatedRecipeIds = [
          ..._collection.recipeIds,
          ...selectedRecipes.map((r) => r.id),
        ];
        
        await FirebaseFirestore.instance
            .collection('recipeCollections')
            .doc(_collection.id)
            .update({'recipeIds': updatedRecipeIds});

        setState(() {
          _collection = _collection.copyWith(recipeIds: updatedRecipeIds);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedRecipes.length} recept hozzáadva!'),
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
  }

  Future<void> _removeRecipeFromCollection(String recipeId) async {
    try {
      final updatedRecipeIds = _collection.recipeIds
          .where((id) => id != recipeId)
          .toList();
      
      await FirebaseFirestore.instance
          .collection('recipeCollections')
          .doc(_collection.id)
          .update({'recipeIds': updatedRecipeIds});

      setState(() {
        _collection = _collection.copyWith(recipeIds: updatedRecipeIds);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recept eltávolítva a mappából')),
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

  Future<void> _deleteCollection() async {
    if (_collection.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ez a mappa nem törölhető!')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mappa törlése'),
        content: const Text('Biztosan törölni szeretnéd ezt a mappát? A receptek nem lesznek törölve, csak a mappa.'),
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
            .collection('recipeCollections')
            .doc(_collection.id)
            .delete();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mappa törölve')),
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
    final color = Color(int.parse('FF${_collection.color}', radix: 16));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_collection.emoji),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _collection.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
        actions: [
          if (!_collection.isSystem)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteCollection,
              tooltip: 'Mappa törlése',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar + Sort buttons (merged into one row)
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
                      prefixIcon: Icon(Icons.search, color: color, size: 20),
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
                        borderSide: BorderSide(color: color, width: 2),
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
                        color: color,
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
                        color: color,
                        tooltip: 'Kategória rendezés',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Recipe list
          Expanded(
            child: _buildRecipeList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecipeToCollection,
        backgroundColor: color,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRecipeList() {
    if (_collection.recipeIds.isEmpty) {
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
              'A mappa üres',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nyomj a + gombra receptek hozzáadásához!',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where(FieldPath.documentId, whereIn: _collection.recipeIds)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Hiba: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final recipes = snapshot.data!.docs
            .map((doc) => Recipe.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        final filteredRecipes = _filterRecipes(recipes);

        if (filteredRecipes.isEmpty && _searchQuery.isNotEmpty) {
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
                            '${recipe.ingredients.length} hozzávaló',
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
              
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                onPressed: () => _removeRecipeFromCollection(recipe.id),
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
    required Color color,
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
            color: isSelected ? color : Colors.transparent,
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

// Multi-select recipe dialog
class _RecipeSelectionDialog extends StatefulWidget {
  final List<Recipe> recipes;

  const _RecipeSelectionDialog({required this.recipes});

  @override
  State<_RecipeSelectionDialog> createState() => _RecipeSelectionDialogState();
}

class _RecipeSelectionDialogState extends State<_RecipeSelectionDialog> {
  final Set<String> _selectedRecipeIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Receptek kiválasztása (${_selectedRecipeIds.length})'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.recipes.length,
          itemBuilder: (context, index) {
            final recipe = widget.recipes[index];
            final categoryData = RecipeCategories.getCategory(recipe.category);
            final isSelected = _selectedRecipeIds.contains(recipe.id);
            
            return CheckboxListTile(
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedRecipeIds.add(recipe.id);
                  } else {
                    _selectedRecipeIds.remove(recipe.id);
                  }
                });
              },
              secondary: CircleAvatar(
                backgroundColor: categoryData.color,
                child: Text(
                  categoryData.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Text(recipe.name),
              subtitle: Text(recipe.category),
              activeColor: AppColors.coral,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        TextButton(
          onPressed: _selectedRecipeIds.isEmpty
              ? null
              : () {
                  final selectedRecipes = widget.recipes
                      .where((r) => _selectedRecipeIds.contains(r.id))
                      .toList();
                  Navigator.pop(context, selectedRecipes);
                },
          child: Text('Hozzáadás (${_selectedRecipeIds.length})'),
        ),
      ],
    );
  }
}