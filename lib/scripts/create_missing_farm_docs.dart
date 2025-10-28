import 'package:cloud_firestore/cloud_firestore.dart';

class CreateMissingFarmDocs {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createMissingFarmDocs() async {
    try {
      print('Starting to create missing farm documents...');

      // Get all reviews
      final reviewsSnapshot = await _firestore.collection('reviews').get();
      final Set<String> farmOwnerIds = reviewsSnapshot.docs
          .map((doc) => doc.data()['farmOwnerId'] as String)
          .toSet();

      print('Found ${farmOwnerIds.length} unique farms with reviews');

      // Get all existing farm documents
      final farmsSnapshot = await _firestore.collection('farms').get();
      final Set<String> existingFarmIds =
          farmsSnapshot.docs.map((doc) => doc.id).toSet();

      // Find farms that need documents created
      final Set<String> missingFarmIds =
          farmOwnerIds.difference(existingFarmIds);

      print('Found ${missingFarmIds.length} farms missing documents');

      // Create documents for missing farms
      for (final farmId in missingFarmIds) {
        try {
          // Get the first review for this farm to get the farm name
          final farmReviews = reviewsSnapshot.docs
              .where((doc) => doc.data()['farmOwnerId'] == farmId)
              .toList();

          if (farmReviews.isEmpty) continue;

          final firstReview = farmReviews.first.data();
          final farmName = firstReview['farmName'] ?? 'Unknown Farm';

          // Create the farm document
          await _firestore.collection('farms').doc(farmId).set({
            'name': farmName,
            'farmOwnerId': farmId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'averageRating': 0.0,
            'totalReviews': 0,
          });

          print('Created farm document for $farmName (ID: $farmId)');
        } catch (e) {
          print('Error creating farm document for ID $farmId: $e');
        }
      }

      print('Done! All missing farm docs created.');
    } catch (e) {
      print('Error creating missing farm documents: $e');
      rethrow;
    }
  }
}
