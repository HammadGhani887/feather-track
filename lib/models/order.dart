import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  processing,
  shipped,
  delivered,
  cancelled,
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final String unit;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.unit,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0.0).toDouble(),
      unit: map['unit'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'unit': unit,
    };
  }
}

class Order {
  final String id;
  final String customerId;
  final String customerName;
  final String sellerId; // Can be either farmOwnerId or vendorId
  final Timestamp createdAt;
  final String sellerName;
  final String sellerRole; // 'Farm Owner' or 'Vendor'
  final List<OrderItem> items;
  final double totalAmount;
  final String shippingAddress;
  final OrderStatus status;
  final Timestamp updatedAt;
  final String? paymentMethod;
  final bool isPaid;

  Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.sellerId,
    required this.createdAt,
    required this.sellerName,
    required this.sellerRole,
    required this.items,
    required this.totalAmount,
    required this.shippingAddress,
    required this.status,
    required this.updatedAt,
    this.paymentMethod,
    required this.isPaid,
  });

  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final itemsList = (data['items'] as List<dynamic>?)
            ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList() ??
        [];

    return Order(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      sellerId: data['sellerId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      sellerName: data['sellerName'] ?? '',
      sellerRole: data['sellerRole'] ?? '',
      items: itemsList,
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      shippingAddress: data['shippingAddress'] ?? '',
      status: _getOrderStatus(data['status'] ?? 'pending'),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      paymentMethod: data['paymentMethod'],
      isPaid: data['isPaid'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'sellerId': sellerId,
      'createdAt': createdAt,
      'sellerName': sellerName,
      'sellerRole': sellerRole,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'shippingAddress': shippingAddress,
      'status': status.toString().split('.').last,
      'updatedAt': updatedAt,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid,
    };
  }

  Order copyWith({
    List<OrderItem>? items,
    double? totalAmount,
    String? shippingAddress,
    OrderStatus? status,
    String? paymentMethod,
    bool? isPaid,
  }) {
    return Order(
      id: this.id,
      customerId: this.customerId,
      customerName: this.customerName,
      sellerId: this.sellerId,
      sellerName: this.sellerName,
      sellerRole: this.sellerRole,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      status: status ?? this.status,
      createdAt: this.createdAt,
      updatedAt: Timestamp.now(),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  static OrderStatus _getOrderStatus(String status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'processing':
        return OrderStatus.processing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}
