import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/farm_inventory.dart';
import '../models/user_profile.dart';

class InventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get inventory items for an owner (farm owner or vendor)
  Future<List<FarmInventory>> getInventory(
      String ownerId, InventoryOwnerType ownerType) async {
    try {
      // Simplified query - removed sorting to avoid needing a composite index
      final querySnapshot = await _firestore
          .collection('inventory')
          .where('ownerId', isEqualTo: ownerId)
          .where('ownerType',
              isEqualTo: ownerType == InventoryOwnerType.vendor
                  ? 'vendor'
                  : 'farmOwner')
          .get();

      // Sort in-memory instead of in the query
      final results = querySnapshot.docs
          .map((doc) => FarmInventory.fromFirestore(doc))
          .toList();

      // Sort by createdAt in descending order (newest first)
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return results;
    } catch (e) {
      print('Error getting inventory: $e');
      return [];
    }
  }

  // Add new inventory item with owner verification
  Future<FarmInventory?> addInventoryItem(
      FarmInventory item, UserProfile currentUser) async {
    try {
      // Verify that the owner matches the current user
      if (item.ownerId != currentUser.uid) {
        throw Exception('Unauthorized: Cannot add inventory for another user');
      }

      // Verify owner type matches user role
      bool isValidOwner = (currentUser.role == 'Farm Owner' &&
              item.ownerType == InventoryOwnerType.farmOwner) ||
          (currentUser.role == 'Vendor' &&
              item.ownerType == InventoryOwnerType.vendor);

      if (!isValidOwner) {
        throw Exception('Unauthorized: Invalid owner type for user role');
      }

      final docRef = await _firestore.collection('inventory').add(item.toMap());
      final doc = await docRef.get();
      return FarmInventory.fromFirestore(doc);
    } catch (e) {
      print('Error adding inventory item: $e');
      return null;
    }
  }

  // Update inventory item with owner verification
  Future<bool> updateInventoryItem(
      FarmInventory item, UserProfile currentUser) async {
    try {
      // First get the existing item to verify ownership
      final existingDoc =
          await _firestore.collection('inventory').doc(item.id).get();
      if (!existingDoc.exists) {
        throw Exception('Item not found');
      }

      final existingItem = FarmInventory.fromFirestore(existingDoc);

      // Verify ownership
      if (existingItem.ownerId != currentUser.uid) {
        throw Exception(
            'Unauthorized: Cannot update inventory item owned by another user');
      }

      // Verify owner type matches user role
      bool isValidOwner = (currentUser.role == 'Farm Owner' &&
              existingItem.ownerType == InventoryOwnerType.farmOwner) ||
          (currentUser.role == 'Vendor' &&
              existingItem.ownerType == InventoryOwnerType.vendor);

      if (!isValidOwner) {
        throw Exception('Unauthorized: Invalid owner type for user role');
      }

      await _firestore
          .collection('inventory')
          .doc(item.id)
          .update(item.toMap());
      return true;
    } catch (e) {
      print('Error updating inventory item: $e');
      return false;
    }
  }

  // Delete inventory item with owner verification
  Future<bool> deleteInventoryItem(
      String itemId, UserProfile currentUser) async {
    try {
      // First get the item to verify ownership
      final doc = await _firestore.collection('inventory').doc(itemId).get();
      if (!doc.exists) {
        throw Exception('Item not found');
      }

      final item = FarmInventory.fromFirestore(doc);

      // Verify ownership
      if (item.ownerId != currentUser.uid) {
        throw Exception(
            'Unauthorized: Cannot delete inventory item owned by another user');
      }

      // Verify owner type matches user role
      bool isValidOwner = (currentUser.role == 'Farm Owner' &&
              item.ownerType == InventoryOwnerType.farmOwner) ||
          (currentUser.role == 'Vendor' &&
              item.ownerType == InventoryOwnerType.vendor);

      if (!isValidOwner) {
        throw Exception('Unauthorized: Invalid owner type for user role');
      }

      await _firestore.collection('inventory').doc(itemId).delete();
      return true;
    } catch (e) {
      print('Error deleting inventory item: $e');
      return false;
    }
  }

  // Get inventory by category for an owner
  Future<List<FarmInventory>> getInventoryByCategory(
      String ownerId, InventoryOwnerType ownerType, String category) async {
    try {
      // Simplified query - removed sorting to avoid needing a composite index
      final querySnapshot = await _firestore
          .collection('inventory')
          .where('ownerId', isEqualTo: ownerId)
          .where('ownerType',
              isEqualTo: ownerType == InventoryOwnerType.vendor
                  ? 'vendor'
                  : 'farmOwner')
          .where('category', isEqualTo: category)
          .get();

      // Sort in-memory instead of in the query
      final results = querySnapshot.docs
          .map((doc) => FarmInventory.fromFirestore(doc))
          .toList();

      // Sort by createdAt in descending order (newest first)
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return results;
    } catch (e) {
      print('Error getting inventory by category: $e');
      return [];
    }
  }

  // Get all available products (for customers to view)
  Future<List<FarmInventory>> getAllAvailableProducts() async {
    try {
      // Only show farm owner products
      final querySnapshot = await _firestore
          .collection('inventory')
          .where('isAvailable', isEqualTo: true)
          .where('ownerType', isEqualTo: 'farmOwner')
          .get();

      // Sort in-memory instead of in the query
      final results = querySnapshot.docs
          .map((doc) => FarmInventory.fromFirestore(doc))
          .toList();

      // Sort by createdAt in descending order (newest first)
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return results;
    } catch (e) {
      print('Error getting available products: $e');
      return [];
    }
  }

  // Get single inventory item with owner verification
  Future<FarmInventory?> getInventoryItem(
      String itemId, UserProfile currentUser) async {
    try {
      final doc = await _firestore.collection('inventory').doc(itemId).get();
      if (!doc.exists) return null;

      final item = FarmInventory.fromFirestore(doc);

      // Verify ownership
      if (item.ownerId != currentUser.uid) {
        throw Exception(
            'Unauthorized: Cannot access inventory item owned by another user');
      }

      // Verify owner type matches user role
      bool isValidOwner = (currentUser.role == 'Farm Owner' &&
              item.ownerType == InventoryOwnerType.farmOwner) ||
          (currentUser.role == 'Vendor' &&
              item.ownerType == InventoryOwnerType.vendor);

      if (!isValidOwner) {
        throw Exception('Unauthorized: Invalid owner type for user role');
      }

      return item;
    } catch (e) {
      print('Error getting inventory item: $e');
      return null;
    }
  }

  // Get inventory items for a specific farm
  Future<List<FarmInventory>> getFarmInventory(String farmId) async {
    final snapshot = await _firestore
        .collection('inventory')
        .where('ownerId', isEqualTo: farmId)
        .where('ownerType', isEqualTo: 'farmOwner')
        .where('isAvailable', isEqualTo: true)
        .get();

    final inventory =
        snapshot.docs.map((doc) => FarmInventory.fromFirestore(doc)).toList();

    // Sort locally to avoid composite index
    inventory.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return inventory;
  }
}
