// screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../models/cooking_log.dart';
import '../models/shopping_list_item.dart';
import '../models/user_profile.dart';
import '../utils/app_colors.dart';
import '../utils/recipe_categories.dart'; // Add this import
import 'recipe_detail_screen.dart';
import 'dart:math';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _displayName = '';
  bool _isLoadingName = true;
  List<Recipe> _recentRecipes = [];
  List<Recipe> _forgottenRecipes = [];
  List<ShoppingListItem> _shoppingItems = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDashboardData();
  }

  Future<void> _loadUserProfile() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('userProfiles')
          .doc(userId)
          .get();

      if (doc.exists) {
        final profile = UserProfile.fromMap(doc.data()!);
        setState(() {
          _displayName = profile.displayName;
          _isLoadingName = false;
        });
      } else {
        // Use email as default
        final email = FirebaseAuth.instance.currentUser?.email ?? 'Vendég';
        setState(() {
          _displayName = email;
          _isLoadingName = false;
        });
      }
    } catch (e) {
      final email = FirebaseAuth.instance.currentUser?.email ?? 'Vendég';
      setState(() {
        _displayName = email;
        _isLoadingName = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Load all recipes
      final recipesSnapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .where('userId', isEqualTo: userId)
          .get();

      final allRecipes = recipesSnapshot.docs
          .map((doc) => Recipe.fromMap(doc.id, doc.data()))
          .toList();

      // Load cooking logs from last 15 days
      final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
      final logsSnapshot = await FirebaseFirestore.instance
          .collection('cookingLogs')
          .where('userId', isEqualTo: userId)
          .where('cookedDate', isGreaterThanOrEqualTo: fifteenDaysAgo.toIso8601String())
          .get();

      final recentLogs = logsSnapshot.docs
          .map((doc) => CookingLog.fromMap(doc.id, doc.data()))
          .toList();

      // Sort by most recent first
      recentLogs.sort((a, b) => b.cookedDate.compareTo(a.cookedDate));

      // Get recent recipes (max 3)
      final recentRecipeIds = recentLogs.map((log) => log.recipeId).toSet();
      final recentRecipes = allRecipes
          .where((recipe) => recentRecipeIds.contains(recipe.id))
          .take(3)
          .toList();

      // Sort recent recipes by cooking date
      recentRecipes.sort((a, b) {
        final aLog = recentLogs.firstWhere((log) => log.recipeId == a.id);
        final bLog = recentLogs.firstWhere((log) => log.recipeId == b.id);
        return bLog.cookedDate.compareTo(aLog.cookedDate);
      });

      // Get all cooking logs to find forgotten recipes
      final allLogsSnapshot = await FirebaseFirestore.instance
          .collection('cookingLogs')
          .where('userId', isEqualTo: userId)
          .get();

      final allLogs = allLogsSnapshot.docs
          .map((doc) => CookingLog.fromMap(doc.id, doc.data()))
          .toList();

      final allCookedRecipeIds = allLogs.map((log) => log.recipeId).toSet();

      // Forgotten recipes: either never cooked OR not cooked in last 15 days
      final forgottenRecipes = allRecipes
          .where((recipe) => !recentRecipeIds.contains(recipe.id))
          .toList();

      // Shuffle and take 3
      forgottenRecipes.shuffle(Random());
      final selectedForgotten = forgottenRecipes.take(3).toList();

      // Load shopping list items
      final shoppingSnapshot = await FirebaseFirestore.instance
          .collection('shoppingList')
          .where('userId', isEqualTo: userId)
          .where('checked', isEqualTo: false)
          .get();

      final shoppingItems = shoppingSnapshot.docs
          .map((doc) => ShoppingListItem.fromMap(doc.id, doc.data()))
          .toList();

      shoppingItems.shuffle(Random());
      final selectedShopping = shoppingItems.take(3).toList();

      setState(() {
        _recentRecipes = recentRecipes;
        _forgottenRecipes = selectedForgotten;
        _shoppingItems = selectedShopping;
        _isLoadingData = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _displayName);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Név szerkesztése'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Név',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      try {
        final profile = UserProfile(
          userId: userId,
          displayName: controller.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('userProfiles')
            .doc(userId)
            .set(profile.toMap());

        setState(() {
          _displayName = controller.text.trim();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Név sikeresen frissítve!'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingName || _isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUserProfile();
        await _loadDashboardData();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo and Greeting Section - UPDATED
          Column(
            children: [
              // Logo Placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.coral, width: 3),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: 50,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(height: 16),
              
              // Centered Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Szia, $_displayName!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: _editDisplayName,
                    color: AppColors.coral,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Üdv a Főzliben, ami leveszi rólad a konyhai mentális terhet!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recently Cooked Section
          _buildSection(
            title: 'Nemrég készítetted el',
            emptyMessage: 'Még nem készítettél semmit az elmúlt 15 napban',
            items: _recentRecipes,
            isRecipe: true,
          ),
          const SizedBox(height: 24),

          // Forgotten Recipes Section
          _buildSection(
            title: 'Már régen nem készítetted el',
            emptyMessage: 'Nincs több recept',
            items: _forgottenRecipes,
            isRecipe: true,
          ),
          const SizedBox(height: 24),

          // Shopping List Preview
          _buildShoppingSection(),
          const SizedBox(height: 24),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onNavigate(1);
                  },
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Több recept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onNavigate(2);
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Teljes lista'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Premium Placeholder
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Column(
              children: [
                Icon(Icons.star, color: Colors.amber[700], size: 40),
                const SizedBox(height: 8),
                Text(
                  'Prémium előfizetés',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vásárold meg a prémiumot a zökkenőmentes használatért!\nReklám-mentes élmény, AI receptkészítő és még sok más!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hamarosan elérhető!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Előfizetés most'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String emptyMessage,
    required List items,
    required bool isRecipe,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center( // Add this
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                emptyMessage,
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...items.map((item) {
            if (isRecipe) {
              final recipe = item as Recipe;
              final categoryData = RecipeCategories.getCategory(recipe.category);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryData.color,
                    child: Text(
                      categoryData.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(recipe.name),
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
                            color: categoryData.color,
                            fontSize: 11,
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
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
            return const SizedBox.shrink();
          }),
      ],
    );
  }

  Widget _buildShoppingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center( // Add this
          child: const Text(
            'Mit kell venned',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_shoppingItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'A bevásárlólistád üres',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._shoppingItems.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.shopping_basket, color: AppColors.coral),
                title: Text(item.name),
                subtitle: item.quantity.isNotEmpty
                    ? Text('${item.quantity} ${item.unit}')
                    : null,
              ),
            );
          }),
      ],
    );
  }
}