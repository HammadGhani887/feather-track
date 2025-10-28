import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/farm_review.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new review
  Future<void> createReview(FarmReview review) async {
    await _firestore.collection('reviews').doc(review.id).set(review.toMap());
  }

  // Update an existing review
  Future<void> updateReview(FarmReview review) async {
    await _firestore
        .collection('reviews')
        .doc(review.id)
        .update(review.toMap());
  }

  // Get all reviews for a farm
  Future<List<FarmReview>> getFarmReviews(String farmOwnerId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('farmOwnerId', isEqualTo: farmOwnerId)
        .get();

    final reviews =
        snapshot.docs.map((doc) => FarmReview.fromFirestore(doc)).toList();

    // Sort locally
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return reviews;
  }

  // Get average rating for a farm
  Future<double> getFarmAverageRating(String farmOwnerId) async {
    final reviews = await getFarmReviews(farmOwnerId);
    if (reviews.isEmpty) return 0.0;

    double total = 0;
    for (var review in reviews) {
      total += review.rating;
    }
    return total / reviews.length;
  }

  // Get farm ranking
  Future<List<Map<String, dynamic>>> getFarmRankings() async {
    final snapshot = await _firestore.collection('reviews').get();

    // Group reviews by farm
    Map<String, List<FarmReview>> farmReviews = {};
    for (var doc in snapshot.docs) {
      final review = FarmReview.fromFirestore(doc);
      farmReviews[review.farmOwnerId] = [
        ...(farmReviews[review.farmOwnerId] ?? []),
        review
      ];
    }

    // Get all farm documents to fetch farm names
    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'Farm Owner')
        .get();
    final Map<String, String> farmNames = {};
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      farmNames[doc.id] = data['farmName'] ?? data['name'] ?? 'Unknown Farm';
    }

    // Calculate average rating and total reviews for each farm
    List<Map<String, dynamic>> rankings = [];
    farmReviews.forEach((farmId, reviews) {
      double totalRating = 0;
      for (var review in reviews) {
        totalRating += review.rating;
      }
      double avgRating = totalRating / reviews.length;

      rankings.add({
        'farmId': farmId,
        'farmName': farmNames[farmId] ?? 'Unknown Farm',
        'averageRating': avgRating,
        'totalReviews': reviews.length,
        'score': avgRating * (1 + (reviews.length / 100)), // Weighted score
      });
    });

    // Sort by score and take top 5
    rankings.sort((a, b) => b['score'].compareTo(a['score']));
    return rankings.take(5).toList();
  }

  // Check if a review exists for an order
  Future<FarmReview?> getReviewForOrder(String orderId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('orderId', isEqualTo: orderId)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return FarmReview.fromFirestore(snapshot.docs.first);
  }

  // Search reviews with filters
  Future<List<FarmReview>> searchReviews({
    String? farmOwnerId,
    String? vendorName,
    String? orderId,
    double? minRating,
    String? vendorId,
  }) async {
    Query query = _firestore.collection('reviews');

    // Always filter by farmOwnerId if provided
    if (farmOwnerId != null) {
      query = query.where('farmOwnerId', isEqualTo: farmOwnerId);
    }

    if (vendorId != null) {
      query = query.where('vendorId', isEqualTo: vendorId);
    }

    if (vendorName != null) {
      query = query
          .where('vendorName', isGreaterThanOrEqualTo: vendorName)
          .where('vendorName', isLessThanOrEqualTo: vendorName + '\uf8ff');
    }
    if (orderId != null) {
      query = query.where('orderId', isEqualTo: orderId);
    }
    if (minRating != null) {
      query = query.where('rating', isGreaterThanOrEqualTo: minRating);
    }

    final snapshot = await query.get();

    // Get order details for each review
    List<FarmReview> reviews = [];
    for (var doc in snapshot.docs) {
      final review = FarmReview.fromFirestore(doc);

      // Fetch order details
      try {
        if (review.orderId != null && review.orderId.isNotEmpty) {
          final orderDoc =
              await _firestore.collection('orders').doc(review.orderId).get();
          if (orderDoc.exists && orderDoc.data() != null) {
            final orderData = orderDoc.data()!;
            // You can add order details to the review object if needed
            // For example, you could extend the FarmReview model to include order details
          }
        }
      } catch (e) {
        print('Error fetching order details: $e');
      }

      reviews.add(review);
    }

    // Sort locally to avoid needing a composite index
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return reviews;
  }

  // Get top rated farms
  Future<List<Map<String, dynamic>>> getTopRatedFarms({int limit = 5}) async {
    final rankings = await getFarmRankings();
    return rankings.take(limit).toList();
  }

  // Check if an order has been reviewed
  Future<bool> isOrderReviewed(String orderId) async {
    final review = await getReviewForOrder(orderId);
    return review != null;
  }

  // Get all farm rankings (not limited to top 5)
  Future<List<Map<String, dynamic>>> getAllFarmRankings() async {
    final snapshot = await _firestore.collection('reviews').get();

    // Group reviews by farm
    Map<String, List<FarmReview>> farmReviews = {};
    for (var doc in snapshot.docs) {
      final review = FarmReview.fromFirestore(doc);
      farmReviews[review.farmOwnerId] = [
        ...(farmReviews[review.farmOwnerId] ?? []),
        review
      ];
    }

    // Get all farm documents to fetch farm names
    final usersSnapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'Farm Owner')
        .get();
    final Map<String, String> farmNames = {};
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      farmNames[doc.id] = data['farmName'] ?? data['name'] ?? 'Unknown Farm';
    }

    // Calculate average rating and total reviews for each farm
    List<Map<String, dynamic>> rankings = [];
    farmReviews.forEach((farmId, reviews) {
      double totalRating = 0;
      for (var review in reviews) {
        totalRating += review.rating;
      }
      double avgRating = totalRating / reviews.length;

      rankings.add({
        'farmId': farmId,
        'farmName': farmNames[farmId] ?? 'Unknown Farm',
        'averageRating': avgRating,
        'totalReviews': reviews.length,
        'score': avgRating * (1 + (reviews.length / 100)), // Weighted score
      });
    });

    // Sort by score
    rankings.sort((a, b) => b['score'].compareTo(a['score']));
    return rankings;
  }

  // Add a new review (alias for createReview for backward compatibility)
  Future<void> addReview(FarmReview review) async {
    await createReview(review);
  }

  Future<void> submitReview({
    required String orderId,
    required String farmOwnerId,
    required String vendorId,
    required double rating,
    required String reviewText,
    required Map<String, double> categoryRatings,
    String? vendorPhone,
    String? farmName,
    String? vendorName,
  }) async {
    try {
      // Create the review document
      final reviewRef = _firestore.collection('reviews').doc();
      await reviewRef.set({
        'id': reviewRef.id,
        'orderId': orderId,
        'farmOwnerId': farmOwnerId,
        'vendorId': vendorId,
        'rating': rating,
        'reviewText': reviewText,
        'categoryRatings': categoryRatings,
        'vendorPhone': vendorPhone ?? '',
        'farmName': farmName ?? '',
        'vendorName': vendorName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update farm's average rating
      await _updateFarmRating(farmOwnerId);
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  Future<void> _updateFarmRating(String farmOwnerId) async {
    try {
      // Get all reviews for this farm
      final reviewsSnapshot = await _firestore
          .collection('reviews')
          .where('farmOwnerId', isEqualTo: farmOwnerId)
          .get();

      if (reviewsSnapshot.docs.isEmpty) return;

      // Calculate average rating
      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        totalRating += doc.data()['rating'] as double;
      }
      double averageRating = totalRating / reviewsSnapshot.docs.length;

      // Update farm document with new average rating
      await _firestore.collection('farms').doc(farmOwnerId).update({
        'averageRating': averageRating,
        'totalReviews': reviewsSnapshot.docs.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update farm rating: $e');
    }
  }

  // Get all reviews for a farm as a stream
  Stream<QuerySnapshot> getFarmReviewsStream(String farmOwnerId) {
    return _firestore
        .collection('reviews')
        .where('farmOwnerId', isEqualTo: farmOwnerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get all reviews for a vendor as a stream
  Stream<QuerySnapshot> getVendorReviewsStream(String vendorId) {
    return _firestore
        .collection('reviews')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
