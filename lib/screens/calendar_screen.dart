// screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/cooking_log.dart';
import '../models/recipe.dart';
import '../utils/app_colors.dart';
import '../utils/recipe_categories.dart'; // Add this import

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<CookingLog>> _events = {};
  Map<String, Recipe> _recipesCache = {}; // Add recipe cache

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
    _loadRecipes(); // Load recipes for category display
  }

  Future<void> _loadRecipes() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .where('userId', isEqualTo: userId)
        .get();

    final Map<String, Recipe> recipes = {};
    for (var doc in snapshot.docs) {
      final recipe = Recipe.fromMap(doc.id, doc.data());
      recipes[recipe.id] = recipe;
    }

    setState(() {
      _recipesCache = recipes;
    });
  }

  Future<void> _loadEvents() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('cookingLogs')
        .where('userId', isEqualTo: userId)
        .get();

    final Map<DateTime, List<CookingLog>> events = {};

    for (var doc in snapshot.docs) {
      final log = CookingLog.fromMap(doc.id, doc.data());
      final date = DateTime(
        log.cookedDate.year,
        log.cookedDate.month,
        log.cookedDate.day,
      );

      if (events[date] == null) {
        events[date] = [];
      }
      events[date]!.add(log);
    }

    setState(() {
      _events = events;
    });
  }

  List<CookingLog> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  Future<void> _addCookingLog(DateTime selectedDate) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Get all recipes for selection
    final recipesSnapshot = await FirebaseFirestore.instance
        .collection('recipes')
        .where('userId', isEqualTo: userId)
        .get();

    final recipes = recipesSnapshot.docs
        .map((doc) => Recipe.fromMap(doc.id, doc.data()))
        .toList();

    if (recipes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nincs recept! Adj hozzá receptet először.')),
        );
      }
      return;
    }

    final selectedRecipe = await showDialog<Recipe>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Válassz receptet'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final categoryData = RecipeCategories.getCategory(recipe.category);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: categoryData.color,
                  child: Text(
                    categoryData.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(recipe.name),
                subtitle: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                onTap: () => Navigator.pop(context, recipe),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
        ],
      ),
    );

    if (selectedRecipe != null) {
      try {
        final log = CookingLog(
          id: '',
          userId: userId,
          recipeId: selectedRecipe.id,
          recipeName: selectedRecipe.name,
          cookedDate: selectedDate,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('cookingLogs')
            .add(log.toMap());

        await _loadEvents();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedRecipe.name} hozzáadva!'),
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

  Future<void> _deleteLog(CookingLog log) async {
    try {
      await FirebaseFirestore.instance
          .collection('cookingLogs')
          .doc(log.id)
          .delete();

      await _loadEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bejegyzés törölve')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TableCalendar<CookingLog>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.coral.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: AppColors.coral,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addCookingLog(_selectedDay ?? DateTime.now()),
        backgroundColor: AppColors.coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay ?? DateTime.now());

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Ezen a napon nem főztél semmit',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Kattints a + gombra hozzáadáshoz!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final log = events[index];
        final recipe = _recipesCache[log.recipeId];
        
        // Get category info if recipe exists, otherwise use default
        final categoryData = recipe != null 
            ? RecipeCategories.getCategory(recipe.category)
            : RecipeCategories.getCategory('Egyéb');

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: categoryData.color,
              child: Text(
                categoryData.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            title: Text(log.recipeName),
            subtitle: Row(
              children: [
                if (recipe != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                ],
                Text(
                  DateFormat('HH:mm').format(log.createdAt),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteLog(log),
            ),
          ),
        );
      },
    );
  }
}