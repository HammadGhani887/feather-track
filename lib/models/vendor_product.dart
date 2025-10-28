import 'package:cloud_firestore/cloud_firestore.dart';

class VendorProduct {
  final String id;
  final String vendorId;
  final String title;
  final String type;
  final double pricePerUnit;
  final int quantity;
  final String unit;
  final String? imageUrl;
  final String description;
  final String shippingEstimate;
  final String? deliveryArea;
  final bool isVisible;
  final Timestamp createdAt;
  final String ownerRole;

  VendorProduct({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.type,
    required this.pricePerUnit,
    required this.quantity,
    required this.unit,
    this.imageUrl,
    required this.description,
    required this.shippingEstimate,
    this.deliveryArea,
    required this.isVisible,
    required this.createdAt,
    required this.ownerRole,
  });

  factory VendorProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VendorProduct(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      pricePerUnit: (data['pricePerUnit'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 0,
      unit: data['unit'] ?? 'per kg',
      imageUrl: data['imageUrl'],
      description: data['description'] ?? '',
      shippingEstimate: data['shippingEstimate'] ?? '',
      deliveryArea: data['deliveryArea'],
      isVisible: data['isVisible'] ?? true,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      ownerRole: data['ownerRole'] ?? 'Vendor',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'title': title,
      'type': type,
      'pricePerUnit': pricePerUnit,
      'quantity': quantity,
      'unit': unit,
      'imageUrl': imageUrl,
      'description': description,
      'shippingEstimate': shippingEstimate,
      'deliveryArea': deliveryArea,
      'isVisible': isVisible,
      'createdAt': createdAt,
      'ownerRole': ownerRole,
    };
  }
}
