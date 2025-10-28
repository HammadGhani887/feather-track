import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vendor_product.dart';

class VendorProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new vendor product and deduct from inventory
  Future<void> addVendorProduct(VendorProduct product) async {
    final docRef = _firestore.collection('vendor_products').doc();
    final data = product.toMap();
    data['ownerRole'] = 'Vendor';
    await docRef.set(data);
    // Deduct from inventory
    final invRef = _firestore.collection('inventory').doc(product.id);
    await _firestore.runTransaction((transaction) async {
      final invDoc = await transaction.get(invRef);
      if (invDoc.exists) {
        final currentQty = invDoc.data()?['quantity'] ?? 0;
        final newQty = currentQty - product.quantity;
        transaction.update(invRef, {
          'quantity': newQty,
          'status': 'listed',
        });
      }
    });
  }

  // Update a vendor product and adjust inventory
  Future<void> updateVendorProduct(
      VendorProduct product, int oldQuantity) async {
    final docRef = _firestore.collection('vendor_products').doc(product.id);
    final data = product.toMap();
    data['ownerRole'] = 'Vendor';
    await docRef.update(data);
    // Adjust inventory
    final invRef = _firestore.collection('inventory').doc(product.id);
    await _firestore.runTransaction((transaction) async {
      final invDoc = await transaction.get(invRef);
      if (invDoc.exists) {
        final currentQty = invDoc.data()?['quantity'] ?? 0;
        final newQty = currentQty + oldQuantity - product.quantity;
        transaction.update(invRef, {
          'quantity': newQty,
        });
      }
    });
  }

  // Delete a vendor product and return quantity to inventory
  Future<void> deleteVendorProduct(VendorProduct product) async {
    final docRef = _firestore.collection('vendor_products').doc(product.id);
    await docRef.delete();
    // Return quantity to inventory
    final invRef = _firestore.collection('inventory').doc(product.id);
    await _firestore.runTransaction((transaction) async {
      final invDoc = await transaction.get(invRef);
      if (invDoc.exists) {
        final currentQty = invDoc.data()?['quantity'] ?? 0;
        final newQty = currentQty + product.quantity;
        transaction.update(invRef, {
          'quantity': newQty,
        });
      }
    });
  }

  // Fetch all products for a vendor
  Future<List<VendorProduct>> getVendorProducts(String vendorId) async {
    final query = await _firestore
        .collection('vendor_products')
        .where('vendorId', isEqualTo: vendorId)
        .get();
    return query.docs.map((doc) => VendorProduct.fromFirestore(doc)).toList();
  }

  // Fetch all visible products for customers
  Future<List<VendorProduct>> getVisibleProducts() async {
    final query = await _firestore
        .collection('vendor_products')
        .where('isVisible', isEqualTo: true)
        .get();
    return query.docs.map((doc) => VendorProduct.fromFirestore(doc)).toList();
  }

  Future<List<VendorProduct>> getVisibleVendorProductsForCustomers() async {
    final query = await _firestore
        .collection('vendor_products')
        .where('isVisible', isEqualTo: true)
        .where('ownerRole', isEqualTo: 'Vendor')
        .get();
    return query.docs.map((doc) => VendorProduct.fromFirestore(doc)).toList();
  }
}
