// screens/shopping_lists_overview_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_list.dart';
import '../utils/app_colors.dart';
import 'shopping_list_detail_screen.dart';

class ShoppingListsOverviewScreen extends StatefulWidget {
  final bool isPremium;

  const ShoppingListsOverviewScreen({super.key, this.isPremium = true});

  @override
  State<ShoppingListsOverviewScreen> createState() => _ShoppingListsOverviewScreenState();
}

class _ShoppingListsOverviewScreenState extends State<ShoppingListsOverviewScreen> {
  Future<void> _createShoppingList() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    String? selectedTemplate;
    final nameController = TextEditingController();
    String selectedEmoji = '📝';
    String selectedColor = 'FF8F8F';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Új bevásárlólista'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Template selection
                const Text(
                  'Sablon választása (opcionális):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ShoppingListTemplates.templates.map((template) {
                    final isSelected = selectedTemplate == template['name'];
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(template['emoji']!),
                          const SizedBox(width: 4),
                          Text(template['name']!),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTemplate = template['name'];
                            nameController.text = template['name']!;
                            selectedEmoji = template['emoji']!;
                            selectedColor = template['color']!;
                          } else {
                            selectedTemplate = null;
                          }
                        });
                      },
                      selectedColor: AppColors.coral.withOpacity(0.3),
                      checkmarkColor: AppColors.coral,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Custom name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Lista neve',
                    border: OutlineInputBorder(),
                    hintText: 'pl. Heti bevásárlás',
                  ),
                  autofocus: selectedTemplate == null,
                ),
                const SizedBox(height: 16),
                
                // Emoji picker
                const Text(
                  'Emoji:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '📝', '🛒', '🛍️', '🎒', '📦', '🎁', '🍎', '🥖', 
                    '🧀', '🥩', '🍕', '🍰', '☕', '🏪', '💰', '✨'
                  ].map((emoji) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedEmoji = emoji;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selectedEmoji == emoji
                              ? AppColors.coral.withOpacity(0.2)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedEmoji == emoji
                                ? AppColors.coral
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                
                // Color picker
                const Text(
                  'Szín:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    {'color': 'FF8F8F', 'name': 'Coral'},
                    {'color': 'FFB84D', 'name': 'Narancs'},
                    {'color': 'FFD700', 'name': 'Arany'},
                    {'color': '9CAF88', 'name': 'Zöld'},
                    {'color': 'C2E2FA', 'name': 'Kék'},
                    {'color': 'B7A3E3', 'name': 'Lila'},
                    {'color': 'FFB6C1', 'name': 'Rózsaszín'},
                    {'color': 'C41E3A', 'name': 'Piros'},
                  ].map((colorData) {
                    final color = Color(int.parse('FF${colorData['color']}', radix: 16));
                    return InkWell(
                      onTap: () {
                        setState(() {
                          selectedColor = colorData['color']!;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedColor == colorData['color']
                                ? Colors.black
                                : Colors.grey[300]!,
                            width: selectedColor == colorData['color'] ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
        final list = ShoppingList(
          id: '', // Firestore will generate
          userId: userId,
          name: nameController.text.trim(),
          emoji: selectedEmoji,
          color: selectedColor,
          createdAt: DateTime.now(),
          isSystem: false,
        );

        await FirebaseFirestore.instance.collection('shoppingLists').add(list.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lista létrehozva!'),
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

  Future<void> _deleteList(ShoppingList list) async {
    if (list.isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ez a lista nem törölhető!')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lista törlése'),
        content: Text('Biztosan törölni szeretnéd a(z) "${list.name}" listát? A listán lévő tételek is törlődnek.'),
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
        // Delete list
        await FirebaseFirestore.instance
            .collection('shoppingLists')
            .doc(list.id)
            .delete();

        // Delete all items in this list
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('shoppingListItems')
            .where('userId', isEqualTo: list.userId)
            .where('listId', isEqualTo: list.id)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in itemsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lista törölve')),
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
      return const Scaffold(
        body: Center(child: Text('Nincs bejelentkezve')),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shoppingLists')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hiba: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lists = snapshot.data!.docs
              .map((doc) => ShoppingList.fromMap(doc.id, doc.data() as Map<String, dynamic>))
              .toList();

          // Check if seasonal list should exist
          final seasonalTemplate = SeasonalShoppingLists.getSeasonalListTemplate(userId);
          if (seasonalTemplate != null) {
            // Check if it exists in Firestore
            final exists = lists.any((l) => l.id == seasonalTemplate.id);
            
            if (!exists) {
              // Create it in Firestore
              FirebaseFirestore.instance
                  .collection('shoppingLists')
                  .doc(seasonalTemplate.id)
                  .set(seasonalTemplate.toMap());
            }
          }

          // Filter lists: use async filtering with FutureBuilder
          return FutureBuilder<List<ShoppingList>>(
            future: _filterVisibleLists(lists, userId),
            builder: (context, filterSnapshot) {
              if (!filterSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final visibleLists = filterSnapshot.data!;

              // Sort: seasonal first, then by creation date
              visibleLists.sort((a, b) {
                final aIsSeasonal = SeasonalShoppingLists.isSeasonalList(a.id);
                final bIsSeasonal = SeasonalShoppingLists.isSeasonalList(b.id);
                
                if (aIsSeasonal && !bIsSeasonal) return -1;
                if (!aIsSeasonal && bIsSeasonal) return 1;
                
                return b.createdAt.compareTo(a.createdAt);
              });

              if (visibleLists.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Még nincsenek bevásárlólisták',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nyomj a + gombra lista létrehozásához!',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: visibleLists.length,
                itemBuilder: (context, index) {
                  final list = visibleLists[index];
                  return _buildListCard(list, userId);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createShoppingList,
        backgroundColor: AppColors.coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<List<ShoppingList>> _filterVisibleLists(List<ShoppingList> lists, String userId) async {
    final visibleLists = <ShoppingList>[];
    
    for (var list in lists) {
      final shouldShow = await SeasonalShoppingLists.shouldShowSeasonalList(list.id, userId);
      if (shouldShow) {
        visibleLists.add(list);
      }
    }
    
    return visibleLists;
  }

  Widget _buildListCard(ShoppingList list, String userId) {
    final color = Color(int.parse('FF${list.color}', radix: 16));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shoppingListItems')
          .where('userId', isEqualTo: userId)
          .where('listId', isEqualTo: list.id)
          .snapshots(),
      builder: (context, itemsSnapshot) {
        final itemCount = itemsSnapshot.hasData ? itemsSnapshot.data!.docs.length : 0;
        final checkedCount = itemsSnapshot.hasData
            ? itemsSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['checked'] == true;
              }).length
            : 0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShoppingListDetailScreen(
                    shoppingList: list,
                    isPremium: widget.isPremium,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Emoji icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        list.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // List info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.shopping_basket, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '$itemCount tétel',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            if (checkedCount > 0) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                '$checkedCount kész',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Delete button (only for non-system lists)
                  if (!list.isSystem)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _deleteList(list),
                    ),
                  
                  // Arrow
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}