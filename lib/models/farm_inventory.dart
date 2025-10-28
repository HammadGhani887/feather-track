import 'package:cloud_firestore/cloud_firestore.dart';

enum InventoryOwnerType { farmOwner, vendor }

class FarmInventory {
  final String id;
  final String ownerId; // Can be either farmOwnerId or vendorId
  final InventoryOwnerType ownerType;
  final String itemName;
  final String category; // 'bird', 'egg', 'feed', etc.
  final int quantity;
  final String unit; // 'kg', 'dozens', 'birds', etc.
  final double price;
  final String description;
  final String? imageUrl;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final bool isAvailable;

  FarmInventory({
    required this.id,
    required this.ownerId,
    required this.ownerType,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.description,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.isAvailable,
  });

  factory FarmInventory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FarmInventory(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      ownerType: data['ownerType'] == 'vendor'
          ? InventoryOwnerType.vendor
          : InventoryOwnerType.farmOwner,
      itemName: data['itemName'] ?? '',
      category: data['category'] ?? '',
      quantity: data['quantity'] ?? 0,
      unit: data['unit'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      isAvailable: data['isAvailable'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'ownerType':
          ownerType == InventoryOwnerType.vendor ? 'vendor' : 'farmOwner',
      'itemName': itemName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isAvailable': isAvailable,
    };
  }

  FarmInventory copyWith({
    String? itemName,
    String? category,
    int? quantity,
    String? unit,
    double? price,
    String? description,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return FarmInventory(
      id: this.id,
      ownerId: this.ownerId,
      ownerType: this.ownerType,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: this.createdAt,
      updatedAt: Timestamp.now(),
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}
