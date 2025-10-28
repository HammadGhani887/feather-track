import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import '../models/order.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new order
  Future<Order?> createOrder(Order order) async {
    try {
      final docRef = await _firestore.collection('orders').add(order.toMap());
      final doc = await docRef.get();
      return Order.fromFirestore(doc);
    } catch (e) {
      print('Error creating order: $e');
      return null;
    }
  }

  // Get all orders for a customer
  Future<List<Order>> getCustomerOrders(String customerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting customer orders: $e');
      return [];
    }
  }

  // Get all orders for a seller (farm owner or vendor)
  Future<List<Order>> getSellerOrders(String sellerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting seller orders: $e');
      return [];
    }
  }

  // Get order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;

      return Order.fromFirestore(doc);
    } catch (e) {
      print('Error getting order by ID: $e');
      return null;
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status.toString().split('.').last,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  // Mark order as paid
  Future<bool> markOrderAsPaid(String orderId, String paymentMethod) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'isPaid': true,
        'paymentMethod': paymentMethod,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error marking order as paid: $e');
      return false;
    }
  }

  // Delete order
  Future<bool> deleteOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).delete();
      return true;
    } catch (e) {
      print('Error deleting order: $e');
      return false;
    }
  }

  // Get orders by status
  Future<List<Order>> getOrdersByStatus(
      String sellerId, OrderStatus status) async {
    try {
      final statusStr = status.toString().split('.').last;
      final querySnapshot = await _firestore
          .collection('orders')
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: statusStr)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) => Order.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting orders by status: $e');
      return [];
    }
  }

  Future<void> createVendorOrder({
    required String vendorId,
    required String vendorName,
    required String vendorPhone,
    required String farmId,
    required String farmName,
    required String productId,
    required String productName,
    required int quantity,
    required String unit,
    required double price,
  }) async {
    final order = {
      'customerId': vendorId,
      'customerName': vendorName,
      'customerPhone': vendorPhone,
      'vendorId': farmId,
      'vendorName': farmName,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'totalPrice': quantity * price,
      'status': 'Pending',
      'isPaid': false,
      'paymentMethod': '',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

    await _firestore.collection('orders').add(order);

    // This part seems incorrect for placing an order from the ranking screen
    // as we don't have the product's document ID from the inventory.
    // I am commenting it out to prevent potential errors. A better approach
    // would be to handle inventory updates via a cloud function after an order is fulfilled.
    /*
    // Update inventory quantity
    final inventoryRef = _firestore.collection('inventory').doc(productId);
    await _firestore.runTransaction((transaction) async {
      final inventoryDoc = await transaction.get(inventoryRef);
      if (inventoryDoc.exists) {
        final currentQuantity = inventoryDoc.data()?['quantity'] ?? 0;
        final newQuantity = currentQuantity - quantity;
        final isAvailable = newQuantity > 0;

        transaction.update(inventoryRef, {
          'quantity': newQuantity,
          'isAvailable': isAvailable,
          'updatedAt': Timestamp.now(),
        });
      }
    });
    */
  }

  // Get all delivered orders for a vendor that have not been acknowledged
  Future<List<Map<String, dynamic>>> getUnacknowledgedOrders(
      String vendorId) async {
    try {
      final querySnapshot = await _firestore
          .collection('orders')
          .where('customerId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'delivered')
          .where('isVendorAcknowledged', isEqualTo: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting unacknowledged orders: $e');
      return [];
    }
  }

  // Mark an order as acknowledged by the vendor
  Future<void> acknowledgeOrder(String orderId) async {
    try {
      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({'isVendorAcknowledged': true});
    } catch (e) {
      print('Error acknowledging order: $e');
    }
  }
}
