//models/shopping_list_item.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

class ShoppingListItem {
  final String id;
  final String userId;
  final String name;
  final String quantity;
  final String unit;
  final bool checked;
  final DateTime createdAt;

  ShoppingListItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.checked = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'checked': checked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ShoppingListItem.fromMap(String id, Map<String, dynamic> map) {
    // Handle both Timestamp (from Firestore) and String (from imported .fozli files)
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.parse(map['createdAt'] as String);
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return ShoppingListItem(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? '',
      unit: map['unit'] ?? 'db',
      checked: map['checked'] ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  ShoppingListItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? quantity,
    String? unit,
    bool? checked,
    DateTime? createdAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}