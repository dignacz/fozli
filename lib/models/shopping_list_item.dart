//models/shopping_list_item.dart
class ShoppingListItem {
  final String id;
  final String userId;
  final String name;
  final String quantity;
  final String unit; // Add unit field
  final bool checked;
  final DateTime createdAt;

  ShoppingListItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.quantity,
    required this.unit, // Add unit
    this.checked = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'quantity': quantity,
      'unit': unit, // Add unit
      'checked': checked,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ShoppingListItem.fromMap(String id, Map<String, dynamic> map) {
    return ShoppingListItem(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? '',
      unit: map['unit'] ?? 'db', // Add unit with default
      checked: map['checked'] ?? false,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  ShoppingListItem copyWith({
    String? id,
    String? userId,
    String? name,
    String? quantity,
    String? unit, // Add unit
    bool? checked,
    DateTime? createdAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit, // Add unit
      checked: checked ?? this.checked,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}