import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return {
        'id': user.uid,
        ...doc.data()!,
      };
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      await _firestore.collection('users').doc(user.uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Get user profile by ID
  Future<UserProfile?> getUserProfileById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      return UserProfile.fromFirestore(doc);
    } catch (e) {
      print('Error getting user profile by ID: $e');
      return null;
    }
  }

  // Get users by role
  Future<List<UserProfile>> getUsersByRole(String role) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting users by role: $e');
      return [];
    }
  }

  // Delete user account (admin function)
  Future<bool> deleteUserAccount(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      return true;
    } catch (e) {
      print('Error deleting user account: $e');
      return false;
    }
  }

  /// Utility: Create missing farm docs for all reviewed farms (run once for admin setup)
  static Future<void> createMissingFarmDocsForReviewedFarms() async {
    final firestore = FirebaseFirestore.instance;

    // 1. Get all unique farmOwnerIds from reviews
    final reviewsSnapshot = await firestore.collection('reviews').get();
    final Set<String> farmOwnerIds = {};
    for (var doc in reviewsSnapshot.docs) {
      final data = doc.data();
      if (data['farmOwnerId'] != null &&
          data['farmOwnerId'].toString().isNotEmpty) {
        farmOwnerIds.add(data['farmOwnerId']);
      }
    }

    // 2. Get all existing farm doc IDs
    final farmsSnapshot = await firestore.collection('farms').get();
    final Set<String> existingFarmIds =
        farmsSnapshot.docs.map((doc) => doc.id).toSet();

    // 3. For each farmOwnerId not in farms, create a doc with a placeholder name
    for (final farmId in farmOwnerIds) {
      if (!existingFarmIds.contains(farmId)) {
        await firestore.collection('farms').doc(farmId).set({
          'name': 'Farm $farmId', // Placeholder, you can update later
          'location': '',
          'contactNumber': '',
        });
        print('Created farm doc for $farmId');
      }
    }

    print('Done! All missing farm docs created.');
  }

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String name,
    required String role,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'name': name,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }
}
