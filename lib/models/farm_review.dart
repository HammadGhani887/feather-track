import 'package:cloud_firestore/cloud_firestore.dart';

class FarmReview {
  final String id;
  final String farmOwnerId;
  final String farmName;
  final String vendorId;
  final String vendorName;
  final String vendorPhone;
  final String orderId;
  final double rating;
  final String reviewText;
  final Map<String, double> categoryRatings;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final bool isEdited;

  FarmReview({
    required this.id,
    required this.farmOwnerId,
    required this.farmName,
    required this.vendorId,
    required this.vendorName,
    required this.vendorPhone,
    required this.orderId,
    required this.rating,
    required this.reviewText,
    required this.categoryRatings,
    required this.createdAt,
    required this.updatedAt,
    this.isEdited = false,
  });

  factory FarmReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FarmReview(
      id: doc.id,
      farmOwnerId: data['farmOwnerId'] ?? '',
      farmName: data['farmName'] ?? '',
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? '',
      vendorPhone: data['vendorPhone'] ?? '',
      orderId: data['orderId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewText: data['reviewText'] ?? '',
      categoryRatings: Map<String, double>.from(data['categoryRatings'] ?? {}),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      isEdited: data['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'farmOwnerId': farmOwnerId,
      'farmName': farmName,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorPhone': vendorPhone,
      'orderId': orderId,
      'rating': rating,
      'reviewText': reviewText,
      'categoryRatings': categoryRatings,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isEdited': isEdited,
    };
  }

  FarmReview copyWith({
    String? reviewText,
    double? rating,
    Map<String, double>? categoryRatings,
  }) {
    return FarmReview(
      id: id,
      farmOwnerId: farmOwnerId,
      farmName: farmName,
      vendorId: vendorId,
      vendorName: vendorName,
      vendorPhone: vendorPhone,
      orderId: orderId,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      categoryRatings: categoryRatings ?? this.categoryRatings,
      createdAt: createdAt,
      updatedAt: Timestamp.now(),
      isEdited: true,
    );
  }
}
