// screens/shopping_list_screen_updated.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/shopping_list_item.dart';
import '../utils/app_colors.dart';
import 'import_shopping_list_dialog.dart';

class ShoppingListScreen extends StatefulWidget {
  final bool isPremium; // Add this to track premium status

  const ShoppingListScreen({super.key, this.isPremium = false});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  Map<String, dynamic> _convertTimestampsToStrings(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _convertTimestampsToStrings(item);
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          }
          return item;
        }).toList();
      } else if (value is Map<String, dynamic>) {
        result[key] = _convertTimestampsToStrings(value);
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }

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

  Future<void> _showShareOptions(List<ShoppingListItem> items) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet, color: AppColors.coral),
              title: const Text('Megosztás szövegként'),
              subtitle: const Text('Könnyen olvasható formátum'),
              onTap: () {
                Navigator.pop(context);
                _shareAsText(items);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppColors.coral),
              title: const Text('Megosztás .fozli fájlként'),
              subtitle: const Text('Importálható más eszközökön'),
              onTap: () {
                Navigator.pop(context);
                _shareAsFozli(items);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareAsText(List<ShoppingListItem> items) async {
    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('🛒 Bevásárlólista');
      buffer.writeln();
      
      final unchecked = items.where((item) => !item.checked).toList();
      final checked = items.where((item) => item.checked).toList();
      
      if (unchecked.isNotEmpty) {
        buffer.writeln('Kell még:');
        for (var item in unchecked) {
          final quantity = item.quantity.isNotEmpty 
              ? ' - ${item.quantity} ${item.unit}' 
              : '';
          buffer.writeln('  ☐ ${item.name}$quantity');
        }
      }
      
      if (checked.isNotEmpty) {
        buffer.writeln();
        buffer.writeln('Megvan:');
        for (var item in checked) {
          final quantity = item.quantity.isNotEmpty 
              ? ' - ${item.quantity} ${item.unit}' 
              : '';
          buffer.writeln('  ☑ ${item.name}$quantity');
        }
      }
      
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('Megosztva a Főzli alkalmazásból');

      await Share.share(
        buffer.toString(),
        subject: 'Bevásárlólista',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  Future<void> _shareAsFozli(List<ShoppingListItem> items) async {
    try {
      final itemsData = items.map((item) {
        final data = item.toMap();
        data.remove('userId');
        data.remove('id');
        
        // Convert all Timestamps to ISO8601 strings
        return _convertTimestampsToStrings(data);
      }).toList();
      
      final jsonData = jsonEncode({
        'type': 'shopping_list',
        'version': '1.0',
        'items': itemsData,
        'exportedAt': DateTime.now().toIso8601String(),
      });

      final tempDir = Directory.systemTemp;
      final fileName = 'bevasarlolista_${DateTime.now().millisecondsSinceEpoch}.fozli';
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonData);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Bevásárlólista',
        text: 'Főzli bevásárlólista',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lista exportálva!'),
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
                    flex: 3,
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
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Egység',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
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
    String selectedUnit = _shoppingUnits.contains(item.unit) ? item.unit : 'db';

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
                    flex: 3,
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
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Egység',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
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
      body: Column(
        children: [
          // Always visible import and share buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shoppingList')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                final items = snapshot.hasData
                    ? snapshot.data!.docs
                        .map((doc) => ShoppingListItem.fromMap(
                              doc.id,
                              doc.data() as Map<String, dynamic>,
                            ))
                        .toList()
                    : <ShoppingListItem>[];
                
                final hasCheckedItems = items.any((item) => item.checked);
                final hasItems = items.isNotEmpty;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        ImportShoppingListDialog.show(context, isPremium: widget.isPremium);
                      },
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Importálás'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.coral),
                    ),
                    if (hasItems)
                      TextButton.icon(
                        onPressed: () => _showShareOptions(items),
                        icon: const Icon(Icons.share, size: 20),
                        label: const Text('Megosztás'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.coral),
                      ),
                    if (hasCheckedItems)
                      TextButton.icon(
                        onPressed: () => _clearCheckedItems(context, userId),
                        icon: const Icon(Icons.delete_sweep, size: 20),
                        label: const Text('Törlés'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.coral),
                      ),
                  ],
                );
              },
            ),
          ),
          // Main content area
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
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

                return ListView.builder(
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addItem(context),
        backgroundColor: AppColors.coral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}