import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_profile.dart';
import '../../../services/user_service.dart';
import '../../../services/review_service.dart';
import '../../../widgets/review_dialog.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import '../../../models/order.dart';

class CustomerOrderManagementScreen extends StatefulWidget {
  const CustomerOrderManagementScreen({Key? key}) : super(key: key);

  @override
  State<CustomerOrderManagementScreen> createState() =>
      _CustomerOrderManagementScreenState();
}

class _CustomerOrderManagementScreenState
    extends State<CustomerOrderManagementScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  late TabController _tabController;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _completedOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    try {
      final userProfile = await _userService.getCurrentUserProfile();
      setState(() {
        _userProfile = userProfile;
      });
      await _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user profile: $e')),
        );
      }
    }
  }

  Future<void> _loadOrders() async {
    if (_userProfile == null) return;

    try {
      setState(() => _isLoading = true);

      // Load active orders
      final activeSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: _userProfile!['id'])
          .where('status', whereIn: ['pending', 'processing', 'shipped'])
          .orderBy('createdAt', descending: true)
          .get();

      // Load completed orders
      final completedSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: _userProfile!['id'])
          .where('status', whereIn: ['delivered', 'cancelled'])
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _activeOrders = activeSnapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _completedOrders = completedSnapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getVendorName(String vendorId) async {
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(vendorId)
          .get();
      return vendorDoc.data()?['name'] ?? 'Unknown Vendor';
    } catch (e) {
      return 'Unknown Vendor';
    }
  }

  Future<Map<String, String>> _getVendorDetails(String vendorId) async {
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(vendorId)
          .get();
      final data = vendorDoc.data() ?? {};
      return {
        'shopName': data['businessName'] ??
            data['shopName'] ??
            data['name'] ??
            'Unknown Shop',
        'phone': data['phoneNumber'] ?? data['contactNumber'] ?? '-',
        'address': data['address'] ??
            data['location'] ??
            data['shopAddress'] ??
            data['businessAddress'] ??
            '-',
      };
    } catch (e) {
      return {'shopName': 'Unknown Shop', 'phone': '-', 'address': '-'};
    }
  }

  Widget _buildTab(String title, List<Map<String, dynamic>> orders) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (title == 'active orders') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: _userProfile!['id'])
            .where('status', whereIn: ['pending', 'processing', 'shipped'])
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No active orders',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }
          final orders = docs
              .map((doc) =>
                  {...doc.data() as Map<String, dynamic>, 'id': doc.id})
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final items = (order['items'] as List<dynamic>? ?? []);
              final totalQuantity = items.isNotEmpty
                  ? items.fold<int>(
                      0, (sum, item) => sum + ((item['quantity'] ?? 0) as int))
                  : (order['quantity'] ?? 0) as int;
              final mainProduct = items.isNotEmpty
                  ? items[0]['name'] ?? items[0]['productName'] ?? '-'
                  : order['productName'] ?? '-';
              final moreCount =
                  items.length > 1 ? ' + \\${items.length - 1} more' : '';
              final orderDate = order['createdAt'] is Timestamp
                  ? (order['createdAt'] as Timestamp)
                      .toDate()
                      .toString()
                      .split(' ')[0]
                  : (order['createdAt']?.toString().split(' ')[0] ?? '-');
              final totalPrice =
                  ((order['totalAmount'] ?? order['totalPrice'] ?? 0)
                          .toDouble())
                      .toStringAsFixed(2);
              final deliveryAddress = order['deliveryAddress'] ?? '-';
              final customerPhone = order['customerPhone'] ?? '-';
              final customerAddress =
                  order['customerLocation'] ?? _userProfile?['address'] ?? '-';
              return Card(
                color: const Color(0xFF2A2F4F),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<Map<String, String>>(
                        future: _getVendorDetails(order['vendorId']),
                        builder: (context, snapshot) {
                          final details = snapshot.data ??
                              {
                                'shopName': 'Loading...',
                                'phone': '-',
                                'address': '-',
                                'location': '-',
                                'shopAddress': '-',
                                'businessAddress': '-'
                              };
                          String vendorAddress = details['address'] ?? '-';
                          if (vendorAddress == '-' || vendorAddress.isEmpty)
                            vendorAddress = details['location'] ?? '-';
                          if (vendorAddress == '-' || vendorAddress.isEmpty)
                            vendorAddress = details['shopAddress'] ?? '-';
                          if (vendorAddress == '-' || vendorAddress.isEmpty)
                            vendorAddress = details['businessAddress'] ?? '-';
                          if (vendorAddress == '-' || vendorAddress.isEmpty)
                            vendorAddress = '-';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vendor: \\${details['shopName']}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              Text('Phone: \\${details['phone']}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              Text('Address: $vendorAddress',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
                      Text('Order ID: \\${order['id']}',
                          style: const TextStyle(color: Colors.white70)),
                      Text('Order Date: $orderDate',
                          style: const TextStyle(color: Colors.white70)),
                      Text(
                          'Status: \\${order['status'].toString().toUpperCase()}',
                          style: TextStyle(
                              color: order['status'] == 'delivered'
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold)),
                      Text('Product: $mainProduct$moreCount',
                          style: const TextStyle(color: Colors.white70)),
                      Text('Total Quantity: $totalQuantity',
                          style: const TextStyle(color: Colors.white70)),
                      Text('Total: Rs. $totalPrice',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Delivery Address:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text(deliveryAddress,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text('Your Address: $customerAddress',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      const Text('Vendor Details:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon:
                              const Icon(Icons.visibility, color: Colors.blue),
                          onPressed: () => _showOrderDetails(order),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No $title',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final items = (order['items'] as List<dynamic>? ?? []);
        final totalQuantity = items.isNotEmpty
            ? items.fold<int>(
                0, (sum, item) => sum + ((item['quantity'] ?? 0) as int))
            : (order['quantity'] ?? 0) as int;
        final mainProduct = items.isNotEmpty
            ? items[0]['name'] ?? items[0]['productName'] ?? '-'
            : order['productName'] ?? '-';
        final moreCount =
            items.length > 1 ? ' + \\${items.length - 1} more' : '';
        final orderDate = order['createdAt'] is Timestamp
            ? (order['createdAt'] as Timestamp)
                .toDate()
                .toString()
                .split(' ')[0]
            : (order['createdAt']?.toString().split(' ')[0] ?? '-');
        final totalPrice =
            ((order['totalAmount'] ?? order['totalPrice'] ?? 0).toDouble())
                .toStringAsFixed(2);
        final deliveryAddress = order['deliveryAddress'] ?? '-';
        final customerPhone = order['customerPhone'] ?? '-';
        final customerAddress =
            order['customerLocation'] ?? _userProfile?['address'] ?? '-';
        return Card(
          color: const Color(0xFF2A2F4F),
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, String>>(
                  future: _getVendorDetails(order['vendorId']),
                  builder: (context, snapshot) {
                    final details = snapshot.data ??
                        {
                          'shopName': 'Loading...',
                          'phone': '-',
                          'address': '-',
                          'location': '-',
                          'shopAddress': '-',
                          'businessAddress': '-'
                        };
                    String vendorAddress = details['address'] ?? '-';
                    if (vendorAddress == '-' || vendorAddress.isEmpty)
                      vendorAddress = details['location'] ?? '-';
                    if (vendorAddress == '-' || vendorAddress.isEmpty)
                      vendorAddress = details['shopAddress'] ?? '-';
                    if (vendorAddress == '-' || vendorAddress.isEmpty)
                      vendorAddress = details['businessAddress'] ?? '-';
                    if (vendorAddress == '-' || vendorAddress.isEmpty)
                      vendorAddress = '-';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vendor: \\${details['shopName']}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Text('Phone: \\${details['phone']}',
                            style: const TextStyle(color: Colors.white70)),
                        Text('Address: $vendorAddress',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
                Text('Order ID: \\${order['id']}',
                    style: const TextStyle(color: Colors.white70)),
                Text('Order Date: $orderDate',
                    style: const TextStyle(color: Colors.white70)),
                Text('Status: \\${order['status'].toString().toUpperCase()}',
                    style: TextStyle(
                        color: order['status'] == 'delivered'
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold)),
                Text('Product: $mainProduct$moreCount',
                    style: const TextStyle(color: Colors.white70)),
                Text('Total Quantity: $totalQuantity',
                    style: const TextStyle(color: Colors.white70)),
                Text('Total: Rs. $totalPrice',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Delivery Address:',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text(deliveryAddress,
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Your Address: $customerAddress',
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('Vendor Details:',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () => _showOrderDetails(order),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final items = (order['items'] as List<dynamic>? ?? []);
    int totalQuantity = items.fold<int>(
        0, (sum, item) => sum + ((item['quantity'] ?? 0) as int));
    if (totalQuantity == 0) {
      totalQuantity = (order['quantity'] ?? 0) as int;
    }
    final orderDate = order['createdAt'] is Timestamp
        ? (order['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
        : (order['createdAt']?.toString().split(' ')[0] ?? '-');
    final totalPrice =
        ((order['totalAmount'] ?? order['totalPrice'] ?? 0).toDouble())
            .toStringAsFixed(2);
    final customerName = order['customerName'] ?? _userProfile?['name'] ?? '-';
    final customerPhone = order['customerPhone'] ??
        _userProfile?['phoneNumber'] ??
        _userProfile?['contactNumber'] ??
        '-';
    final customerAddress =
        order['customerLocation'] ?? _userProfile?['address'] ?? '-';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text(
          'Order Details',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<Map<String, String>>(
                future: _getVendorDetails(order['vendorId']),
                builder: (context, snapshot) {
                  final details = snapshot.data ??
                      {
                        'shopName': 'Loading...',
                        'phone': '-',
                        'address': '-',
                        'location': '-',
                        'shopAddress': '-',
                        'businessAddress': '-'
                      };
                  String vendorAddress = details['address'] ?? '-';
                  if (vendorAddress == '-' || vendorAddress.isEmpty)
                    vendorAddress = details['location'] ?? '-';
                  if (vendorAddress == '-' || vendorAddress.isEmpty)
                    vendorAddress = details['shopAddress'] ?? '-';
                  if (vendorAddress == '-' || vendorAddress.isEmpty)
                    vendorAddress = details['businessAddress'] ?? '-';
                  if (vendorAddress == '-' || vendorAddress.isEmpty)
                    vendorAddress = '-';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vendor: ${details['shopName']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      Text('Phone: ${details['phone']}',
                          style: const TextStyle(color: Colors.white70)),
                      Text('Address: $vendorAddress',
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                    ],
                  );
                },
              ),
              Text('Order ID: ${order['id']}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Order Date: $orderDate',
                  style: const TextStyle(color: Colors.white70)),
              Text('Status: ${order['status'].toString().toUpperCase()}',
                  style: TextStyle(
                      color: order['status'] == 'delivered'
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold)),
              Text('Delivery Address: ${order['deliveryAddress'] ?? '-'}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Your Address: $customerAddress',
                  style: const TextStyle(color: Colors.white70)),
              Text('Customer Name: $customerName',
                  style: const TextStyle(color: Colors.white70)),
              Text('Customer Phone: $customerPhone',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text('Products:',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (items.isNotEmpty)
                ...items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(
                                item['name'] ?? item['productName'] ?? '-',
                                style: const TextStyle(color: Colors.white70))),
                        Text('x${item['quantity']}',
                            style: const TextStyle(color: Colors.white70)),
                        Text(
                            'Rs. ${((item['price'] ?? 0) * (item['quantity'] ?? 0)).toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                })
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(order['productName'] ?? '-',
                              style: const TextStyle(color: Colors.white70))),
                      Text('x${order['quantity'] ?? '-'}',
                          style: const TextStyle(color: Colors.white70)),
                      Text(
                          'Rs. ${((order['productPrice'] ?? 0) * (order['quantity'] ?? 0)).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              const Divider(color: Colors.white24),
              Text('Total Quantity: $totalQuantity',
                  style: const TextStyle(color: Colors.white)),
              Text('Total Price: Rs. $totalPrice',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
          if (order['status'] == 'delivered' && !(order['isReviewed'] ?? false))
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _showReviewDialog(order);
              },
              child: const Text('Leave Review'),
            ),
        ],
      ),
    );
  }

  Future<void> _generateInvoice(Map<String, dynamic> order) async {
    final pdf = pw.Document();

    final items = (order['items'] as List<dynamic>? ?? []);
    final orderDate = order['createdAt'] is Timestamp
        ? (order['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
        : (order['createdAt']?.toString().split(' ')[0] ?? '-');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Invoice',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Order ID: ${order['id']}'),
                      pw.Text('Date: $orderDate'),
                      pw.Text(
                          'Status: ${order['status']?.toString().toUpperCase() ?? 'N/A'}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Customer Details:'),
                      pw.Text('Name: ${order['customerName'] ?? 'N/A'}'),
                      pw.Text('Phone: ${order['customerPhone'] ?? 'N/A'}'),
                      pw.Text('Address: ${order['deliveryAddress'] ?? 'N/A'}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Product',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Quantity',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Unit Price',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...items.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item['productName'] ?? 'N/A'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${item['quantity'] ?? 0}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                                'Rs. ${item['price']?.toStringAsFixed(2) ?? '0.00'}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                                'Rs. ${((item['price'] ?? 0.0) * (item['quantity'] ?? 0)).toStringAsFixed(2)}'),
                          ),
                        ],
                      )),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Amount: Rs. ${order['totalAmount']?.toStringAsFixed(2) ?? '0.00'}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final Uint8List pdfBytes = await pdf.save();
    final blob = html.Blob([pdfBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'order_${order['id']}_invoice.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _showReviewDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        orderId: order['id'],
        farmOwnerId: order['farmOwnerId'],
        vendorId: order['vendorId'],
        farmName: order['farmName'] ?? 'Unknown Farm',
        vendorName: order['vendorName'] ?? 'Unknown Vendor',
      ),
    ).then((_) => _loadOrders()); // Reload orders after review submission
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text('My Orders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Orders'),
            Tab(text: 'Order History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab('active orders', _activeOrders),
          _buildTab('completed orders', _completedOrders),
        ],
      ),
    );
  }
}
