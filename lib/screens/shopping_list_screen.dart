//screens/shopping_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_list_item.dart';
import '../utils/app_colors.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  // Shopping list specific units
  static const List<String> _shoppingUnits = [
    'db',
    'csomag',
    'doboz',
    'kg',
    'g',
    'l',
    'dl',
    'ml',
  ];

  Future<void> _addItem(BuildContext context) async {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  String selectedUnit = 'db';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Új tétel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Név',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3, // Changed from 2 to 3
                  child: TextField(
                    controller: quantityController,
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
                const SizedBox(width: 1), // Keep spacing
                Expanded(
                  flex: 2, // Changed from 1 to 2
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Egység',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 3, 
                        vertical: 12,
                      ),
                    ),
                    items: _shoppingUnits.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedUnit = newValue ?? 'db';
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hozzáadás'),
          ),
        ],
      ),
    ),
  );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) throw Exception('Nincs bejelentkezve');

        final item = ShoppingListItem(
          id: '',
          userId: userId,
          name: nameController.text.trim(),
          quantity: quantityController.text.trim(),
          unit: selectedUnit,
          checked: false,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance.collection('shoppingList').add(item.toMap());
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hiba: $e')),
          );
        }
      }
    }
  }

  Future<void> _editItem(BuildContext context, ShoppingListItem item) async {
  final nameController = TextEditingController(text: item.name);
  final quantityController = TextEditingController(text: item.quantity);
  String selectedUnit = item.unit;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Tétel szerkesztése'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Név',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3, // Changed from 2 to 3
                  child: TextField(
                    controller: quantityController,
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
                const SizedBox(width: 1),
                Expanded(
                  flex: 2, // Changed from 1 to 2
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Egység',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 12,
                      ),
                    ),
                    items: _shoppingUnits.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedUnit = newValue ?? 'db';
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
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
    ),
  );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('shoppingList')
            .doc(item.id)
            .update({
          'name': nameController.text.trim(),
          'quantity': quantityController.text.trim(),
          'unit': selectedUnit,
        });
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hiba: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleItem(ShoppingListItem item) async {
    await FirebaseFirestore.instance
        .collection('shoppingList')
        .doc(item.id)
        .update({'checked': !item.checked});
  }

  Future<void> _deleteItem(String itemId) async {
    await FirebaseFirestore.instance
        .collection('shoppingList')
        .doc(itemId)
        .delete();
  }

  Future<void> _clearCheckedItems(BuildContext context, String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kipipált tételek törlése'),
        content: const Text('Biztosan törölni szeretnéd az összes kipipált tételt?'),
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
        final snapshot = await FirebaseFirestore.instance
            .collection('shoppingList')
            .where('userId', isEqualTo: userId)
            .where('checked', isEqualTo: true)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kipipált tételek törölve')),
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
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('Nincs bejelentkezve'));
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shoppingList')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hiba: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!.docs
              .map((doc) => ShoppingListItem.fromMap(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                  ))
              .toList();

          if (items.isEmpty) {
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
                    'A bevásárlólista üres',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adj hozzá tételeket vagy használd a "Listához" gombot a recepteknél!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final hasCheckedItems = items.any((item) => item.checked);

          return Column(
            children: [
              if (hasCheckedItems)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange[50],
                  child: TextButton.icon(
                    onPressed: () => _clearCheckedItems(context, userId),
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Kipipáltak törlése'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.coral),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Dismissible(
                      key: Key(item.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _deleteItem(item.id),
                      child: Card(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: ListTile(
                          leading: Checkbox(
                            value: item.checked,
                            onChanged: (_) => _toggleItem(item),
                            activeColor: AppColors.coral,
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.checked ? Colors.grey : null,
                            ),
                          ),
                          subtitle: item.quantity.isNotEmpty
                              ? Text(
                                  '${item.quantity} ${item.unit}',
                                  style: TextStyle(
                                    color: item.checked
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editItem(context, item),
                            color: AppColors.coral,
                          ),
                          onTap: () => _toggleItem(item),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(context),
        backgroundColor: AppColors.coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}