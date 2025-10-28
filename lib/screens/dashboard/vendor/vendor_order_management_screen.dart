import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_profile.dart';
import '../../../services/user_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import '../../../services/review_service.dart';
import '../../../widgets/review_dialog.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:rxdart/rxdart.dart';

class VendorOrderManagementScreen extends StatefulWidget {
  const VendorOrderManagementScreen({Key? key}) : super(key: key);

  @override
  State<VendorOrderManagementScreen> createState() =>
      _VendorOrderManagementScreenState();
}

class _VendorOrderManagementScreenState
    extends State<VendorOrderManagementScreen> {
  final UserService _userService = UserService();
  dynamic _currentUser;
  late Future<List<Map<String, dynamic>>> _activeOrdersFuture =
      Future.value([]);
  late Future<List<Map<String, dynamic>>> _customerOrderHistoryFuture =
      Future.value([]);
  late Future<List<Map<String, dynamic>>> _farmOrderHistoryFuture =
      Future.value([]);
  late Future<List<Map<String, dynamic>>> _ordersToFarmOwnerFuture =
      Future.value([]);
  int _selectedTabIndex = 0;
  final List<String> _tabs = [
    'Orders from Customer',
    'Customer Order History',
    'Orders to Farm Owner',
    'Farm Order History',
  ];

  // Add search and filter variables
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedDateFilter = 'All Time';
  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled'
  ];
  final List<String> _dateFilters = [
    'All Time',
    'Today',
    'This Week',
    'This Month',
    'This Year'
  ];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final user = await _userService.getCurrentUserProfile();
    if (user != null && user['role'] == 'Vendor') {
      setState(() {
        _currentUser = user;
      });
      _loadOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unauthorized: Only vendors can view orders.')),
      );
      Navigator.pop(context);
    }
  }

  void _loadOrders() {
    if (_currentUser == null) return;
    setState(() {
      // 1. Active Orders (received by this vendor)
      _activeOrdersFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: _currentUser['id'])
          .where('status', whereIn: ['pending', 'processing', 'shipped'])
          .orderBy('createdAt', descending: true)
          .get()
          .then((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['docId'] = doc.id;
                return data;
              }).toList());

      // 2. Customer Order History (delivered orders received by this vendor)
      _customerOrderHistoryFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: _currentUser['id'])
          .where('status', isEqualTo: 'delivered')
          .orderBy('createdAt', descending: true)
          .get()
          .then((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['docId'] = doc.id;
                return data;
              }).toList());

      // 3. Farm Order History (delivered orders placed by this vendor to farm owners)
      _farmOrderHistoryFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: _currentUser['id'])
          .where('status', isEqualTo: 'delivered')
          .orderBy('createdAt', descending: true)
          .get()
          .then((snapshot) async {
        final orders = await Future.wait(snapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id;

          // Fetch farm owner details
          if (data['vendorId'] != null) {
            final farmDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['vendorId'])
                .get();
            if (farmDoc.exists) {
              final farmData = farmDoc.data() as Map<String, dynamic>;
              data['vendorName'] = farmData['farmName'] ??
                  farmData['shopName'] ??
                  farmData['name'] ??
                  'Unknown Farm';
              data['vendorPhone'] = farmData['phoneNumber'] ??
                  farmData['contactNumber'] ??
                  farmData['phone'] ??
                  'N/A';
              data['vendorLocation'] = farmData['location'] ??
                  farmData['shopAddress'] ??
                  farmData['address'] ??
                  'N/A';
            }
          }
          return data;
        }));
        return orders;
      });

      // 4. Orders to Farm Owner (active, placed by this vendor)
      _ordersToFarmOwnerFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: _currentUser['id'])
          .where('status', whereIn: ['pending', 'processing', 'shipped'])
          .orderBy('createdAt', descending: true)
          .get()
          .then((snapshot) async {
            final orders = await Future.wait(snapshot.docs.map((doc) async {
              final data = doc.data() as Map<String, dynamic>;
              data['docId'] = doc.id;

              // Fetch farm owner details
              if (data['vendorId'] != null) {
                final farmDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['vendorId'])
                    .get();
                if (farmDoc.exists) {
                  final farmData = farmDoc.data() as Map<String, dynamic>;
                  data['vendorName'] = farmData['farmName'] ??
                      farmData['shopName'] ??
                      farmData['name'] ??
                      'Unknown Farm';
                  data['vendorPhone'] = farmData['phoneNumber'] ??
                      farmData['contactNumber'] ??
                      farmData['phone'] ??
                      'N/A';
                  data['vendorLocation'] = farmData['location'] ??
                      farmData['shopAddress'] ??
                      farmData['address'] ??
                      'N/A';
                }
              }
              return data;
            }));
            return orders;
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Orders', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A1F38),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children:
                  List.generate(_tabs.length, (i) => _buildTab(_tabs[i], i)),
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildOrdersFromCustomerContent()
                : _selectedTabIndex == 1
                    ? _buildCustomerOrderHistoryContent()
                    : _selectedTabIndex == 2
                        ? _buildOrdersToFarmOwnerList(_ordersToFarmOwnerFuture)
                        : _buildFarmOrderHistoryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.green;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<String> _getFarmName(String ownerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return data['farmName'] ?? data['displayName'] ?? 'Unknown Farm';
      }
    } catch (_) {}
    return 'Unknown Farm';
  }

  Widget _buildOrdersFromCustomerContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _activeOrdersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading orders: ${snapshot.error}',
                  style: TextStyle(color: Colors.red)));
        }
        final orders = snapshot.data ?? [];
        final filteredOrders = _filterOrders(orders, _searchQuery,
            _selectedStatus, _selectedDateFilter); // Apply filters
        if (filteredOrders.isEmpty) {
          return const Center(
              child: Text('No active orders from customers.',
                  style: TextStyle(color: Colors.white70)));
        }
        return Column(
          children: [
            _buildSearchAndFilterBar(
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              onStatusChanged: (status) =>
                  setState(() => _selectedStatus = status ?? 'All'),
              onDateFilterChanged: (dateFilter) => setState(
                  () => _selectedDateFilter = dateFilter ?? 'All Time'),
              selectedStatus: _selectedStatus,
              selectedDateFilter: _selectedDateFilter,
            ),
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
                itemCount: filteredOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final order = filteredOrders[i];
                  return Card(
                    color: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(
                        order['productName'] ?? '-',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${order['customerName'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Phone: ${order['customerPhone'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Location: ${order['customerLocation'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text(
                              'Quantity: ${order['quantity']} ${order['productUnit']}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Status: ${order['status'] ?? 'pending'}',
                              style: TextStyle(
                                  color: _getStatusColor(
                                      order['status'] as String?))),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showOrderDetails(order),
                            child: const Text('View'),
                          ),
                          const SizedBox(width: 8),
                          if (order['status'] != 'delivered')
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Update Status'),
                              onPressed: () => _showStatusUpdateDialog(order),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomerOrderHistoryContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _customerOrderHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text(
                  'Error loading customer order history: ${snapshot.error}',
                  style: TextStyle(color: Colors.red)));
        }
        final orders = snapshot.data ?? [];
        final filteredOrders = _filterOrders(orders, _searchQuery,
            _selectedStatus, _selectedDateFilter); // Apply filters
        if (filteredOrders.isEmpty) {
          return const Center(
              child: Text('No customer order history.',
                  style: TextStyle(color: Colors.white70)));
        }
        return Column(
          children: [
            _buildSearchAndFilterBar(
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              onStatusChanged: (status) =>
                  setState(() => _selectedStatus = status ?? 'All'),
              onDateFilterChanged: (dateFilter) => setState(
                  () => _selectedDateFilter = dateFilter ?? 'All Time'),
              selectedStatus: _selectedStatus,
              selectedDateFilter: _selectedDateFilter,
            ),
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
                itemCount: filteredOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final order = filteredOrders[i];
                  return Card(
                    color: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(
                        order['productName'] ?? '-',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${order['customerName'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Phone: ${order['customerPhone'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Location: ${order['customerLocation'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text(
                              'Quantity: ${order['quantity']} ${order['productUnit']}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Status: ${order['status'] ?? 'pending'}',
                              style: TextStyle(
                                  color: _getStatusColor(
                                      order['status'] as String?))),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showOrderDetails(order),
                            child: const Text('View'),
                          ),
                          const SizedBox(width: 8),
                          // No update status button for history
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFarmOrderHistoryContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _farmOrderHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error loading farm order history: ${snapshot.error}',
                  style: TextStyle(color: Colors.red)));
        }
        final orders = snapshot.data ?? [];
        final filteredOrders = _filterOrders(orders, _searchQuery,
            _selectedStatus, _selectedDateFilter); // Apply filters
        if (filteredOrders.isEmpty) {
          return const Center(
              child: Text('No farm order history.',
                  style: TextStyle(color: Colors.white70)));
        }
        return Column(
          children: [
            _buildSearchAndFilterBar(
              onSearchChanged: (query) => setState(() => _searchQuery = query),
              onStatusChanged: (status) =>
                  setState(() => _selectedStatus = status ?? 'All'),
              onDateFilterChanged: (dateFilter) => setState(
                  () => _selectedDateFilter = dateFilter ?? 'All Time'),
              selectedStatus: _selectedStatus,
              selectedDateFilter: _selectedDateFilter,
            ),
            Expanded(
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
                itemCount: filteredOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final order = filteredOrders[i];
                  return Card(
                    color: Colors.white.withOpacity(0.04),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(
                        order['productName'] ?? '-',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Farm: ${order['vendorName'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Phone: ${order['vendorPhone'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Location: ${order['vendorLocation'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text(
                              'Quantity: ${order['quantity']} ${order['productUnit']}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Status: ${order['status'] ?? 'pending'}',
                              style: TextStyle(
                                  color: _getStatusColor(
                                      order['status'] as String?))),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showOrderDetails(order),
                            child: const Text('View'),
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<bool>(
                            future: _isOrderReviewed(order['docId']),
                            builder: (context, reviewSnapshot) {
                              if (reviewSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                );
                              }

                              final isReviewed = reviewSnapshot.data ?? false;

                              if (isReviewed) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: const Text(
                                    'Reviewed',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              } else {
                                return ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _showReviewDialog(order),
                                  child: const Text('Give Review'),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrdersToFarmOwnerList(
      Future<List<Map<String, dynamic>>> ordersToFarmOwnerFuture) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ordersToFarmOwnerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading orders: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const Center(
            child: Text(
              'No orders to farm owner.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white.withOpacity(0.04),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  order['productName'] ?? 'Unknown Product',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text('Farm Owner: ${order['vendorName'] ?? 'Unknown'}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('Farm Phone: ${order['vendorPhone'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.white70)),
                    Text('Farm Location: ${order['vendorLocation'] ?? 'N/A'}',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    const Text('Your Details:',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    FutureBuilder<Map<String, String>>(
                      future: _getVendorDetails(null),
                      builder: (context, snapshot) {
                        final details = snapshot.data ??
                            {
                              'shopName': 'Loading...',
                              'phone': '-',
                              'address': '-'
                            };
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Shop Name: ${details['shopName'] ?? '-'}',
                                style: const TextStyle(color: Colors.white70)),
                            Text('Phone: ${details['phone'] ?? '-'}',
                                style: const TextStyle(color: Colors.white70)),
                            Text('Address: ${details['address'] ?? '-'}',
                                style: const TextStyle(color: Colors.white70)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Quantity: ${order['quantity'] ?? '0'} ${order['productUnit'] ?? 'units'}',
                        style: const TextStyle(color: Colors.white70)),
                    Text(
                        'Status: ${order['status']?.toUpperCase() ?? 'PENDING'}',
                        style:
                            TextStyle(color: _getStatusColor(order['status']))),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.blue),
                      onPressed: () => _generateInvoice(order),
                      tooltip: 'Download Invoice',
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: () => _showOrderDetails(order),
                      tooltip: 'View Details',
                    ),
                  ],
                ),
                onTap: () => _showOrderDetails(order),
              ),
            );
          },
        );
      },
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final customerAddress =
        order['customerLocation'] ?? order['address'] ?? '-';
    final isOrderToFarmOwner = order['vendorName'] != null &&
        order['vendorLocation'] != null &&
        order['customerId'] == _currentUser['id'];
    final yourName = _currentUser['shopName'] ?? _currentUser['name'] ?? '-';
    final yourAddress = _currentUser['shopAddress'] ??
        _currentUser['location'] ??
        _currentUser['address'] ??
        '-';
    if (isOrderToFarmOwner) {
      showDialog(
        context: context,
        builder: (context) => FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(order['vendorId'])
              .get(),
          builder: (context, snapshot) {
            final farmData =
                (snapshot.data?.data() as Map<String, dynamic>?) ?? {};
            final farmName = farmData['farmName'] ??
                farmData['shopName'] ??
                farmData['name'] ??
                '-';
            final farmAddress = farmData['location'] ??
                farmData['shopAddress'] ??
                farmData['address'] ??
                '-';
            final farmPhone = farmData['phoneNumber'] ??
                farmData['contactNumber'] ??
                farmData['phone'] ??
                '-';
            return AlertDialog(
              backgroundColor: const Color(0xFF23263A),
              title: const Text('Order Details',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _orderDetailRow('Product', order['productName']),
                    _orderDetailRow('Category', order['productCategory']),
                    _orderDetailRow('Unit', order['productUnit']),
                    _orderDetailRow('Price', 'Rs. \\${order['productPrice']}'),
                    _orderDetailRow('Quantity', '\\${order['quantity']}'),
                    _orderDetailRow(
                        'Total Price', 'Rs. \\${order['totalPrice']}'),
                    const Divider(color: Colors.white24),
                    const Text('Your Info:',
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                    _orderDetailRow('Your Name', yourName),
                    _orderDetailRow('Your Address', yourAddress),
                    const Divider(color: Colors.white24),
                    const Text('Farm Info:',
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                    _orderDetailRow('Farm Name', farmName),
                    _orderDetailRow('Farm Address', farmAddress),
                    _orderDetailRow('Farm Phone', farmPhone),
                    const Divider(color: Colors.white24),
                    _orderDetailRow('Order Status', order['status']),
                    _orderDetailRow(
                        'Order Date',
                        order['createdAt'] != null &&
                                order['createdAt'] is Timestamp
                            ? (order['createdAt'] as Timestamp)
                                .toDate()
                                .toString()
                            : '-'),
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  label: const Text('Download Invoice',
                      style: TextStyle(color: Colors.blue)),
                  onPressed: () => _generateInvoice(order),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23263A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Order Details', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _orderDetailRow('Product', order['productName']),
              _orderDetailRow('Category', order['productCategory']),
              _orderDetailRow('Unit', order['productUnit']),
              _orderDetailRow('Price', 'Rs. \\${order['productPrice']}'),
              _orderDetailRow('Quantity', '\\${order['quantity']}'),
              _orderDetailRow('Total Price', 'Rs. \\${order['totalPrice']}'),
              const Divider(color: Colors.white24),
              if (order['customerName'] != null &&
                  order['customerName'].toString().isNotEmpty)
                _orderDetailRow('Customer Name', order['customerName'])
              else
                _orderDetailRow('Farm Name', order['farmName']),
              _orderDetailRow('Customer Address', customerAddress),
              _orderDetailRow('Order Status', order['status']),
              _orderDetailRow(
                  'Order Date',
                  order['createdAt'] != null && order['createdAt'] is Timestamp
                      ? (order['createdAt'] as Timestamp).toDate().toString()
                      : '-'),
            ],
          ),
        ),
        actions: [
          if (!isOrderToFarmOwner) ...[
            TextButton.icon(
              icon: const Icon(Icons.update, color: Colors.blue),
              label: const Text('Update Status',
                  style: TextStyle(color: Colors.blue)),
              onPressed: () => _showStatusUpdateDialog(order),
            ),
          ],
          TextButton.icon(
            icon: const Icon(Icons.download, color: Colors.blue),
            label: const Text('Download Invoice',
                style: TextStyle(color: Colors.blue)),
            onPressed: () => _generateInvoice(order),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog(Map<String, dynamic> order) {
    final List<String> statuses = [
      'Pending',
      'Processing',
      'Shipped',
      'Delivered',
      'Cancelled'
    ];
    String selectedStatus =
        order['status']?.toString().toLowerCase() ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23263A),
        title: const Text('Update Order Status',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select new status:',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              dropdownColor: const Color(0xFF23263A),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
              items: statuses.map((String status) {
                return DropdownMenuItem<String>(
                  value: status.toLowerCase(),
                  child: Text(status),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  selectedStatus = newValue;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(order['docId'])
                    .update({
                  'status': selectedStatus,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Show success message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Order status updated to $selectedStatus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                // Close both dialogs
                Navigator.pop(context); // Close status update dialog
                Navigator.pop(context); // Close order details dialog

                // Refresh the orders list
                _loadOrders();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating status: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _orderDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: Colors.blue, fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(value?.toString() ?? '-',
                  style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<Map<String, String>> _getVendorDetails(String? vendorId) async {
    try {
      if (vendorId == null) {
        print('Using current user as vendor');
        print('Current user data: $_currentUser');
        return {
          'shopName': _currentUser['shopName'] ?? 'N/A',
          'phone': _currentUser['phoneNumber'] ??
              _currentUser['phone'] ??
              _currentUser['contactNumber'] ??
              _currentUser['mobileNumber'] ??
              _currentUser['mobile'] ??
              'N/A',
          'address': _currentUser['shopAddress'] ??
              _currentUser['location'] ??
              _currentUser['address'] ??
              'N/A',
        };
      }

      print('Fetching vendor details for ID: $vendorId');
      final vendorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(vendorId)
          .get();
      final vendorData = vendorDoc.data() ?? {};
      print('Vendor data from Firestore: $vendorData');

      // Try to get shop name from multiple possible fields
      final shopName = vendorData['shopName'] ??
          vendorData['shop_name'] ??
          vendorData['name'] ??
          'N/A';

      // Try to get phone from multiple possible fields
      final phone = vendorData['phone'] ??
          vendorData['phoneNumber'] ??
          vendorData['phone_number'] ??
          'N/A';

      // Try to get address from multiple possible fields
      final address = vendorData['address'] ??
          vendorData['location'] ??
          vendorData['shopAddress'] ??
          vendorData['shop_address'] ??
          'N/A';

      return {
        'shopName': shopName,
        'phone': phone,
        'address': address,
      };
    } catch (e) {
      print('Error getting vendor details: $e');
      return {
        'shopName': 'N/A',
        'phone': 'N/A',
        'address': 'N/A',
      };
    }
  }

  Future<void> _generateInvoice(Map<String, dynamic> order) async {
    print('Generating invoice for order: ${order.toString()}');
    print('Current user data: ${_currentUser.toString()}');

    // Determine if this is an order to farm owner
    final isOrderToFarmOwner = order['vendorName'] != null &&
        order['vendorLocation'] != null &&
        order['customerId'] == _currentUser['id'];

    // Get vendor details (current user) with all possible phone number fields
    final vendorDetails = {
      'name': _currentUser['shopName'] ?? _currentUser['name'] ?? 'N/A',
      'phone': _currentUser['phoneNumber'] ??
          _currentUser['phone'] ??
          _currentUser['contactNumber'] ??
          _currentUser['mobileNumber'] ??
          _currentUser['mobile'] ??
          'N/A',
      'address': _currentUser['shopAddress'] ??
          _currentUser['location'] ??
          _currentUser['address'] ??
          'N/A'
    };

    print('Vendor details for invoice: $vendorDetails'); // Debug print

    // Get farm details if this is an order to farm owner
    Map<String, dynamic> farmDetails = {};
    if (isOrderToFarmOwner) {
      try {
        final farmDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(order['vendorId'])
            .get();
        if (farmDoc.exists) {
          final farmData = farmDoc.data() as Map<String, dynamic>;
          farmDetails = {
            'name': farmData['farmName'] ??
                farmData['shopName'] ??
                farmData['name'] ??
                'N/A',
            'phone': farmData['phoneNumber'] ??
                farmData['contactNumber'] ??
                farmData['phone'] ??
                farmData['mobileNumber'] ??
                farmData['mobile'] ??
                'N/A',
            'address': farmData['location'] ??
                farmData['shopAddress'] ??
                farmData['address'] ??
                'N/A'
          };
        }
      } catch (e) {
        print('Error fetching farm details: $e');
      }
    }

    // Get customer details for orders from customers
    final customerDetails = !isOrderToFarmOwner
        ? {
            'name': order['customerName'] ?? 'N/A',
            'phone': order['customerPhone'] ??
                order['customerPhoneNumber'] ??
                order['customerContactNumber'] ??
                'N/A',
            'address': order['customerLocation'] ?? order['address'] ?? 'N/A'
          }
        : {};

    final Map<String, dynamic> invoiceDetails = {
      'vendor': vendorDetails,
      'farm': farmDetails,
      'customer': customerDetails,
      'order': {
        'id': order['docId'] ?? 'N/A',
        'date': order['createdAt'] is Timestamp
            ? (order['createdAt'] as Timestamp)
                .toDate()
                .toString()
                .split(' ')[0]
            : (order['createdAt']?.toString().split(' ')[0] ?? '-'),
        'status': order['status']?.toString().toUpperCase() ?? 'PENDING',
      },
      'product': {
        'name': order['productName'] ?? 'N/A',
        'category': order['productCategory'] ?? 'N/A',
        'unit': order['productUnit'] ?? 'N/A',
        'quantity': order['quantity'] ?? 0,
        'price': order['productPrice'] ?? 0.0,
        'total': (order['productPrice'] ?? 0.0) * (order['quantity'] ?? 0)
      }
    };

    print('Complete invoice details: $invoiceDetails'); // Debug print

    final pdf = pw.Document();

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
              pw.Text('Order Details',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Vendor Details:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Name: ${invoiceDetails['vendor']['name']}'),
                  pw.Text('Phone: ${invoiceDetails['vendor']['phone']}'),
                  pw.Text('Address: ${invoiceDetails['vendor']['address']}'),
                  pw.SizedBox(height: 15),
                  if (isOrderToFarmOwner) ...[
                    pw.Text('Farm Details:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Name: ${invoiceDetails['farm']['name']}'),
                    pw.Text('Phone: ${invoiceDetails['farm']['phone']}'),
                    pw.Text('Address: ${invoiceDetails['farm']['address']}'),
                    pw.SizedBox(height: 15),
                  ] else ...[
                    pw.Text('Customer Details:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Name: ${invoiceDetails['customer']['name']}'),
                    pw.Text('Phone: ${invoiceDetails['customer']['phone']}'),
                    pw.Text(
                        'Address: ${invoiceDetails['customer']['address']}'),
                    pw.SizedBox(height: 15),
                  ],
                  pw.Text('Order Information:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Order ID: ${invoiceDetails['order']['id']}'),
                  pw.Text('Order Date: ${invoiceDetails['order']['date']}'),
                  pw.Text('Status: ${invoiceDetails['order']['status']}',
                      style: pw.TextStyle(
                          color: PdfColors.orange,
                          fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 15),
                  pw.Text('Product Details:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Name: ${invoiceDetails['product']['name']}'),
                  pw.Text('Category: ${invoiceDetails['product']['category']}'),
                  pw.Text('Unit: ${invoiceDetails['product']['unit']}'),
                  pw.Text('Quantity: ${invoiceDetails['product']['quantity']}'),
                  pw.Text(
                      'Price per Unit: Rs. ${invoiceDetails['product']['price'].toStringAsFixed(2)}'),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 0.5),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      'Total Amount: Rs. ${invoiceDetails['product']['total'].toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
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
      ..setAttribute('download', 'order_${order['docId']}_invoice.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _showReviewDialogIfNeeded(Map<String, dynamic> order) async {
    if (order['status'] == 'delivered' && !(order['isReviewed'] ?? false)) {
      final reviewService = ReviewService();
      final isReviewed = await reviewService
          .isOrderReviewed(order['docId'] ?? order['orderId']);
      if (!isReviewed) {
        showDialog(
          context: context,
          builder: (context) => ReviewDialog(
            orderId: (order['docId'] ?? '').toString(),
            farmOwnerId: (order['farmOwnerId'] ?? '').toString(),
            vendorId: (order['vendorId'] ?? '').toString(),
            farmName: (order['farmOwnerName'] ?? '').toString(),
            vendorName: (order['vendorName'] ?? '').toString(),
          ),
        );
      }
    }
  }

  Widget _buildSearchAndFilterBar({
    required void Function(String) onSearchChanged,
    required void Function(String?) onStatusChanged,
    required void Function(String?) onDateFilterChanged,
    required String selectedStatus,
    required String selectedDateFilter,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: [
          // Search Field
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by Order ID, Customer, or Product',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF23263B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          // Status Filter
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: DropdownButtonFormField<String>(
              value: selectedStatus,
              dropdownColor: const Color(0xFF23263B),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Status',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF23263B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _statusFilters.map((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: onStatusChanged,
            ),
          ),
          // Date Filter
          Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: DropdownButtonFormField<String>(
              value: selectedDateFilter,
              dropdownColor: const Color(0xFF23263B),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Date Range',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF23263B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _dateFilters.map((String filter) {
                return DropdownMenuItem<String>(
                  value: filter,
                  child: Text(filter),
                );
              }).toList(),
              onChanged: onDateFilterChanged,
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearchQuery(Map<String, dynamic> order, String query) {
    final searchLower = query.toLowerCase();
    return (order['orderId']?.toString().toLowerCase().contains(searchLower) ??
            false) ||
        (order['docId']?.toString().toLowerCase().contains(searchLower) ??
            false) ||
        (order['customerName']
                ?.toString()
                .toLowerCase()
                .contains(searchLower) ??
            false) || // For customer orders
        (order['vendorName']?.toString().toLowerCase().contains(searchLower) ??
            false) || // For farm orders
        (order['productName']?.toString().toLowerCase().contains(searchLower) ??
            false);
  }

  bool _matchesDateFilter(Map<String, dynamic> order, String dateFilter) {
    final now = DateTime.now();
    final orderDate = (order['createdAt'] as Timestamp).toDate();

    switch (dateFilter) {
      case 'Today':
        return orderDate.year == now.year &&
            orderDate.month == now.month &&
            orderDate.day == now.day;
      case 'This Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return orderDate.isAfter(weekAgo);
      case 'This Month':
        return orderDate.year == now.year && orderDate.month == now.month;
      case 'This Year':
        return orderDate.year == now.year;
      default: // 'All Time'
        return true;
    }
  }

  List<Map<String, dynamic>> _filterOrders(
    List<Map<String, dynamic>> orders,
    String searchQuery,
    String statusFilter,
    String dateFilter,
  ) {
    return orders.where((order) {
      final matchesSearch =
          searchQuery.isEmpty || _matchesSearchQuery(order, searchQuery);
      final matchesStatus = statusFilter == 'All' ||
          order['status'] ==
              statusFilter.toLowerCase(); // Compare lowercase status
      final matchesDate = _matchesDateFilter(order, dateFilter);
      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  Future<bool> _isOrderReviewed(String orderId) async {
    final reviewService = ReviewService();
    return await reviewService.isOrderReviewed(orderId);
  }

  void _showReviewDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        orderId: order['docId'] ?? order['orderId'],
        farmOwnerId: order['vendorId'] ?? '',
        vendorId: order['customerId'] ?? '',
        farmName: order['vendorName'] ?? '',
        vendorName: _currentUser?['shopName'] ??
            _currentUser?['name'] ??
            'Unknown Vendor',
        vendorPhone: _currentUser?['phoneNumber'] ??
            _currentUser?['phone'] ??
            _currentUser?['contactNumber'] ??
            '',
      ),
    ).then((_) {
      // Refresh the farm order history after review submission
      if (_selectedTabIndex == 3) {
        // Farm Order History tab
        setState(() {
          _loadOrders();
        });
      }
    });
  }
}
