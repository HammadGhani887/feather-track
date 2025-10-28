import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/farm_inventory.dart';
import '../../../models/user_profile.dart';
import '../../../services/inventory_service.dart';
import '../../../services/user_service.dart';
import '../../../widgets/review_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:fl_chart/fl_chart.dart';
import '../../../models/farm_review.dart';
import '../../../services/review_service.dart';
import 'package:pdf/pdf.dart'; // Add this import

class FarmOrderManagementScreen extends StatefulWidget {
  const FarmOrderManagementScreen({Key? key}) : super(key: key);

  @override
  _FarmOrderManagementScreenState createState() =>
      _FarmOrderManagementScreenState();
}

class _FarmOrderManagementScreenState extends State<FarmOrderManagementScreen> {
  final InventoryService _inventoryService = InventoryService();
  final UserService _userService = UserService();
  UserProfile? _currentUser;
  late Future<List<FarmInventory>> _productsFuture;
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  late Future<List<Map<String, dynamic>>> _orderHistoryFuture;

  final List<String> _tabs = [
    'Products',
    'Orders',
    'Vendors',
    'Sales',
    'Invoices',
    'Order History',
    // Add Reviews tab
  ];
  String _selectedTab = 'Products'; // Default to Products as per the image

  // Add these variables at the start of the class
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedDateFilter = 'All Time';
  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Ready to Go',
    'Shipped',
    'Delivered'
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
    try {
      final userMap = await _userService.getCurrentUserProfile();
      if (userMap != null && userMap['role'] == 'Farm Owner') {
        final userProfile = UserProfile.fromMap(userMap);
        setState(() {
          _currentUser = userProfile;
        });
        _loadProducts();
        _loadOrders();
      } else {
        throw Exception('Unauthorized access or user not found.');
      }
    } catch (e) {
      print('Error initializing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: ${e.toString()}')),
        );
        // Optionally navigate back or show an error screen
      }
    }
  }

  Future<void> _loadProducts() async {
    if (_currentUser == null) return;
    setState(() {
      _productsFuture = _inventoryService.getInventory(
        _currentUser!.uid,
        InventoryOwnerType.farmOwner,
      );
    });
  }

  Future<void> _loadOrders() async {
    if (_currentUser == null) return;
    print('Current user UID: ${_currentUser!.uid}'); // Debug print
    setState(() {
      // Load all orders for the farm owner (both as vendor and customer)
      _ordersFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: _currentUser!.uid)
          .where('status', whereIn: [
            'pending',
            'processing',
            'shipped'
          ]) // Add this line to filter active orders
          .orderBy('createdAt', descending: true)
          .get()
          .then((snapshot) async {
            print('Found ${snapshot.docs.length} orders'); // Debug print
            final orders = await Future.wait(snapshot.docs.map((doc) async {
              final data = doc.data() as Map<String, dynamic>;
              data['docId'] = doc.id;

              // Fetch customer details for each order
              if (data['customerId'] != null) {
                final customerDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['customerId'])
                    .get();
                if (customerDoc.exists) {
                  final customerData =
                      customerDoc.data() as Map<String, dynamic>;
                  data['customerName'] =
                      customerData['name'] ?? 'Unknown Customer';
                  data['customerPhone'] = customerData['phoneNumber'] ?? 'N/A';
                  data['customerLocation'] = customerData['location'] ?? 'N/A';
                }
              }

              print('Order data: $data'); // Debug print
              return data;
            }));
            return orders;
          });

      // Load order history (delivered orders)
      _orderHistoryFuture = FirebaseFirestore.instance
          .collection('orders')
          .where('vendorId', isEqualTo: _currentUser!.uid)
          .where('status', isEqualTo: 'delivered')
          .orderBy('createdAt', descending: true)
          .get()
          .then((snapshot) async {
        final orders = await Future.wait(snapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id;

          // Fetch customer details for each order
          if (data['customerId'] != null) {
            final customerDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(data['customerId'])
                .get();
            if (customerDoc.exists) {
              final customerData = customerDoc.data() as Map<String, dynamic>;
              data['customerName'] = customerData['name'] ?? 'Unknown Customer';
              data['customerPhone'] = customerData['phoneNumber'] ?? 'N/A';
              data['customerLocation'] = customerData['location'] ?? 'N/A';
            }
          }
          return data;
        }));
        return orders;
      });
    });
  }

  Widget _buildTab(String title) {
    final bool isSelected = title == _selectedTab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  Widget _buildContent() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_selectedTab) {
      case 'Products':
        return _buildProductsContent();
      case 'Orders':
        return _buildOrdersContent();
      case 'Order History':
        return _buildOrderHistoryContent();
      case 'Vendors':
        return _buildVendorsContent();
      case 'Sales':
        return _buildSalesContent();
      case 'Invoices':
        return _buildInvoicesContent();
      case 'Reviews':
        return _buildReviewsContent();
      default:
        return const Center(
            child: Text('Select a tab', style: TextStyle(color: Colors.white)));
    }
  }

  // ----------- Products Tab Content -----------
  Widget _buildProductsContent() {
    return Container(
      color: const Color(0xFF181B23), // Dark background for Products tab
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextButton.icon(
                icon: const Icon(Icons.add, color: Colors.blue),
                label: const Text('Add Product',
                    style: TextStyle(color: Colors.blue)),
                onPressed: () =>
                    _addOrEditInventoryItem(context), // Use the same dialog
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FarmInventory>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading products: \\${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      'No products found. Add some!',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: DataTable(
                      headingRowColor:
                          MaterialStateProperty.all(Color(0xFF23263B)),
                      dataRowColor:
                          MaterialStateProperty.all(Color(0xFF181B23)),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                            label: Text('Product',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                        DataColumn(
                            label: Text('Quantity',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            numeric: true),
                        DataColumn(
                            label: Text('Description',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                        DataColumn(
                            label: Text('Actions',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white))),
                      ],
                      rows: products
                          .map((item) => DataRow(
                                color: MaterialStateProperty.all(
                                    Color(0xFF181B23)),
                                cells: [
                                  DataCell(Text(item.itemName,
                                      style: TextStyle(color: Colors.white))),
                                  DataCell(Text('${item.quantity} ${item.unit}',
                                      style: TextStyle(color: Colors.white70))),
                                  DataCell(Text(
                                      item.description.isNotEmpty
                                          ? item.description
                                          : '-',
                                      style: TextStyle(color: Colors.white70))),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                        ),
                                        onPressed: () =>
                                            _showProductDetailsDialog(item),
                                        child: const Text('View'),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue, size: 20),
                                        onPressed: () =>
                                            _addOrEditInventoryItem(context,
                                                existingItem: item),
                                        tooltip: 'Edit',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        onPressed: () =>
                                            _deleteInventoryItem(item.id),
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showProductDetailsDialog(FarmInventory product) async {
    // Fetch all orders for this product
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('productId', isEqualTo: product.id)
        .where('farmOwnerId', isEqualTo: _currentUser!.uid)
        .get();
    final orders = ordersSnapshot.docs.map((doc) => doc.data()).toList();
    int totalOrders = orders.length;
    int totalQuantity = 0;
    double totalRevenue = 0;
    for (var order in orders) {
      final qty = (order['quantity'] ?? 0) as int;
      final price = (order['productPrice'] ?? 0).toDouble();
      totalQuantity += qty;
      totalRevenue += qty * price;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23263A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Product Details',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: \\${product.itemName}',
                  style: const TextStyle(color: Colors.white)),
              Text('Category: \\${product.category}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Description: \\${product.description}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Unit: \\${product.unit}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Price: Rs. \\${product.price}',
                  style: const TextStyle(color: Colors.white70)),
              Text('Available: \\${product.quantity} \\${product.unit}',
                  style: const TextStyle(color: Colors.white70)),
              const Divider(color: Colors.white24),
              Text('Total Orders: \\${totalOrders}',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold)),
              Text('Total Quantity Ordered: \\${totalQuantity}',
                  style: const TextStyle(color: Colors.blue)),
              Text('Total Revenue: Rs. \\${totalRevenue.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.blue)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Copied/Adapted from InventoryScreen - Needs _buildTextField & _buildDropdown helpers
  Future<void> _addOrEditInventoryItem(BuildContext context,
      {FarmInventory? existingItem}) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add/edit: User not loaded')),
      );
      return;
    }

    String itemName = existingItem?.itemName ?? '';
    String category = existingItem?.category ?? 'Egg';
    int quantity = existingItem?.quantity ?? 0;
    String unit = existingItem?.unit ?? 'dozens';
    double price = existingItem?.price ?? 0.0;
    String description = existingItem?.description ?? '';
    bool isAvailable = existingItem?.isAvailable ?? true;

    final nameController = TextEditingController(text: itemName);
    final quantityController = TextEditingController(text: quantity.toString());
    final priceController = TextEditingController(text: price.toString());
    final descriptionController = TextEditingController(text: description);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateInDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F38), // Dialog background
          title: Text(
            existingItem == null ? 'Add Product' : 'Edit Product',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Product Name', isDark: true),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Category',
                  category,
                  ['Bird', 'Egg', 'Feed', 'Other'],
                  (value) => setStateInDialog(() => category = value!),
                  isDark: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(quantityController, 'Quantity', isDark: true),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Unit',
                  unit,
                  ['birds', 'dozens', 'kg', 'items'],
                  (value) => setStateInDialog(() => unit = value!),
                  isDark: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(priceController, 'Price', isDark: true),
                const SizedBox(height: 16),
                _buildTextField(descriptionController, 'Description',
                    isDark: true),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Available for Sale',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: isAvailable,
                  onChanged: (value) =>
                      setStateInDialog(() => isAvailable = value),
                  activeColor: Colors.blue,
                  tileColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  inactiveTrackColor: Colors.white30,
                  inactiveThumbColor: Colors.white70,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (nameController.text.isEmpty) {
                    throw Exception('Product name is required');
                  }
                  final qty = int.tryParse(quantityController.text);
                  if (qty == null || qty < 0) {
                    throw Exception('Invalid quantity');
                  }
                  final prc = double.tryParse(priceController.text);
                  if (prc == null || prc < 0) {
                    throw Exception('Invalid price');
                  }

                  final item = existingItem != null
                      ? existingItem.copyWith(
                          itemName: nameController.text,
                          category: category,
                          quantity: qty,
                          unit: unit,
                          price: prc,
                          description: descriptionController.text,
                          isAvailable: isAvailable,
                        )
                      : FarmInventory(
                          id: '', // Firestore generates ID
                          ownerId: _currentUser!.uid,
                          ownerType: InventoryOwnerType.farmOwner,
                          itemName: nameController.text,
                          category: category,
                          quantity: qty,
                          unit: unit,
                          price: prc,
                          description: descriptionController.text,
                          imageUrl: null,
                          createdAt: Timestamp.now(),
                          updatedAt: Timestamp.now(),
                          isAvailable: isAvailable,
                        );

                  if (existingItem != null) {
                    final success = await _inventoryService.updateInventoryItem(
                        item, _currentUser!);
                    if (!success) throw Exception('Failed to update product');
                  } else {
                    final newItem = await _inventoryService.addInventoryItem(
                        item, _currentUser!);
                    if (newItem == null)
                      throw Exception('Failed to add product');
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    _loadProducts(); // Reload the products list
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          existingItem == null
                              ? 'Product added successfully'
                              : 'Product updated successfully',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: Text(
                existingItem == null ? 'Add' : 'Update',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteInventoryItem(String itemId) async {
    if (_currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text(
          'Delete Product',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this product?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await _inventoryService.deleteInventoryItem(itemId, _currentUser!);
        if (success && mounted) {
          _loadProducts(); // Reload the products list
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete product')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  // Helper widgets for the dialog (copied from InventoryScreen)
  Widget _buildTextField(TextEditingController controller, String label,
      {bool isDark = false}) {
    final style = TextStyle(color: isDark ? Colors.white : Colors.black);
    final labelStyle =
        TextStyle(color: isDark ? Colors.white70 : Colors.black54);
    final border = OutlineInputBorder(
      borderSide: BorderSide(
          color: isDark ? Colors.blue.withOpacity(0.5) : Colors.grey),
      borderRadius: BorderRadius.circular(8),
    );
    final focusedBorder = OutlineInputBorder(
      borderSide: BorderSide(
          color:
              isDark ? Colors.blue : Colors.blueGrey), // Adjusted focus color
      borderRadius: BorderRadius.circular(8),
    );

    return TextField(
      controller: controller,
      style: style,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: labelStyle,
        enabledBorder: border,
        focusedBorder: focusedBorder,
        filled: !isDark, // Fill background if not dark
        fillColor: !isDark ? Colors.white : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged,
      {bool isDark = false}) {
    final style = TextStyle(color: isDark ? Colors.white : Colors.black);
    final labelStyle =
        TextStyle(color: isDark ? Colors.white70 : Colors.black54);
    final border = OutlineInputBorder(
      borderSide: BorderSide(
          color: isDark ? Colors.blue.withOpacity(0.5) : Colors.grey),
      borderRadius: BorderRadius.circular(8),
    );
    final focusedBorder = OutlineInputBorder(
      borderSide: BorderSide(color: isDark ? Colors.blue : Colors.blueGrey),
      borderRadius: BorderRadius.circular(8),
    );

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: labelStyle,
        enabledBorder: border,
        focusedBorder: focusedBorder,
        filled: !isDark,
        fillColor: !isDark ? Colors.white : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      ),
      style: style,
      dropdownColor: isDark
          ? const Color(0xFF1A1F38)
          : Colors.white, // Dropdown background
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value,
              style: style), // Ensure dropdown item text color matches
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
  // ----------- End Products Tab Content -----------

  Widget _buildOrdersContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final allOrders = snapshot.data ?? [];
        final filteredOrders = _filterOrders(
          allOrders,
          _searchQuery,
          _selectedStatus,
          _selectedDateFilter,
        );

        return Container(
          color: const Color(0xFF181B23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchAndFilterBar(
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onStatusChanged: (value) =>
                    setState(() => _selectedStatus = value ?? 'All'),
                onDateFilterChanged: (value) =>
                    setState(() => _selectedDateFilter = value ?? 'All Time'),
                selectedStatus: _selectedStatus,
                selectedDateFilter: _selectedDateFilter,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders (${filteredOrders.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (filteredOrders.isEmpty)
                        const Center(
                          child: Text(
                            'No orders found.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredOrders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return Card(
                              color: Colors.white.withOpacity(0.04),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                title: Text(
                                  order['productName'] ?? '-',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Customer: ${order['customerName'] ?? '-'}',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    Text(
                                        'Phone: ${order['customerPhone'] ?? '-'}',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    Text(
                                        'Location: ${order['customerLocation'] ?? '-'}',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    Text(
                                        'Quantity: ${order['quantity']} ${order['productUnit']}',
                                        style: const TextStyle(
                                            color: Colors.white70)),
                                    Text(
                                        'Status: ${order['status'] ?? 'pending'}',
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
                                            borderRadius:
                                                BorderRadius.circular(8)),
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
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                        child: const Text('Update Status'),
                                        onPressed: () =>
                                            _showStatusUpdateDialog(order),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // New method for showing status update dialog, similar to vendor_order_management_screen.dart
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
                  setState(() {
                    // Use setState to update selectedStatus within the dialog
                    selectedStatus = newValue;
                  });
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
                final docId = order['docId'];
                if (docId != null) {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(docId)
                      .update({
                    'status': selectedStatus,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  print(
                      'Successfully updated order $docId to status $selectedStatus');

                  if (selectedStatus == 'delivered') {
                    // Deduct from inventory
                    final productId = order['productId'];
                    final orderQty = order['quantity'] ?? 0;
                    if (productId != null && orderQty > 0) {
                      final invRef = FirebaseFirestore.instance
                          .collection('inventory')
                          .doc(productId);
                      await FirebaseFirestore.instance
                          .runTransaction((transaction) async {
                        final invDoc = await transaction.get(invRef);
                        if (invDoc.exists) {
                          final currentQty = invDoc.data()?['quantity'] ?? 0;
                          final newQty = currentQty - orderQty;
                          transaction.update(invRef, {
                            'quantity': newQty,
                            'isAvailable': newQty > 0,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        }
                      });
                    }
                    // Generate PDF invoice - now calls the dedicated function
                    await _generateInvoice(order);
                  }

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Order status updated to $selectedStatus'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }

                  // Close both dialogs
                  Navigator.pop(context); // Close status update dialog
                  // No need to pop Order Details dialog if it's not a separate dialog

                  // Refresh the orders list
                  _loadOrders();
                } else {
                  print('Error: docId is null for order: $order');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: Order ID not found.')),
                  );
                }
              } on FirebaseException catch (e) {
                print(
                    'Firebase Error updating order status: ${e.code} - ${e.message}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Firebase Error: ${e.message}')),
                  );
                }
              } catch (e) {
                print('Generic Error updating order status: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Failed to update order status: ${e.toString()}')),
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

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(order['farmOwnerId'] ?? _currentUser!.uid)
            .get(),
        builder: (context, snapshot) {
          // Use farm owner doc if available, else fallback to _currentUser
          final farmData = (snapshot.data?.data() as Map<String, dynamic>?) ??
              (_currentUser as Map<String, dynamic>? ?? {});
          final farmNameValue = farmData['farmName'] ??
              farmData['shopName'] ??
              farmData['name'] ??
              '-';
          final farmAddressValue = farmData['location'] ??
              farmData['shopAddress'] ??
              farmData['address'] ??
              '-';
          final farmPhoneValue = farmData['phoneNumber'] ??
              farmData['contactNumber'] ??
              farmData['phone'] ??
              '-';
          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              backgroundColor: const Color(0xFF23263A),
              title: const Text('Order Details',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _orderDetailRow('Order ID', order['docId'] ?? '-'),
                    _orderDetailRow(
                        'Date',
                        order['createdAt'] != null &&
                                order['createdAt'] is Timestamp
                            ? (order['createdAt'] as Timestamp)
                                .toDate()
                                .toString()
                            : '-'),
                    const Divider(color: Colors.white24),
                    _orderDetailRow('Product', order['productName'] ?? '-'),
                    _orderDetailRow(
                        'Category', order['productCategory'] ?? '-'),
                    _orderDetailRow('Quantity',
                        '${order['quantity']} ${order['productUnit']}'),
                    _orderDetailRow(
                        'Unit Price', 'Rs. ${order['productPrice']}'),
                    _orderDetailRow(
                        'Total Price', 'Rs. ${order['totalPrice']}'),
                    const Divider(color: Colors.white24),
                    const Text('Farm Info:',
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                    _orderDetailRow('Farm Name', farmNameValue),
                    _orderDetailRow('Farm Address', farmAddressValue),
                    _orderDetailRow('Farm Phone', farmPhoneValue),
                    const Divider(color: Colors.white24),
                    const Text('Vendor Info:',
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(order['customerId'])
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _orderDetailRow(
                                  'Vendor Name', order['customerName'] ?? '-'),
                              _orderDetailRow(
                                  'Vendor Address',
                                  order['customerLocation'] ??
                                      order['address'] ??
                                      '-'),
                              _orderDetailRow('Vendor Phone',
                                  order['customerPhone'] ?? '-'),
                            ],
                          );
                        }
                        final vendorData =
                            snapshot.data!.data() as Map<String, dynamic>? ??
                                {};
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _orderDetailRow(
                                'Vendor Name',
                                vendorData['name'] ??
                                    order['customerName'] ??
                                    '-'),
                            _orderDetailRow(
                                'Vendor Address',
                                vendorData['address'] ??
                                    vendorData['location'] ??
                                    order['customerLocation'] ??
                                    order['address'] ??
                                    '-'),
                            _orderDetailRow(
                                'Vendor Phone',
                                vendorData['phoneNumber'] ??
                                    vendorData['contactNumber'] ??
                                    order['customerPhone'] ??
                                    '-'),
                          ],
                        );
                      },
                    ),
                    const Divider(color: Colors.white24),
                    _orderDetailRow(
                        'Status', order['status']?.toUpperCase() ?? '-'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white)),
                ),
                // Add Download Invoice button
                TextButton.icon(
                  icon: const Icon(Icons.download, color: Colors.blue),
                  label: const Text('Download Invoice',
                      style: TextStyle(color: Colors.blue)),
                  onPressed: () => _generateInvoice(
                      order), // Call the new invoice generation function
                ),
              ],
            ),
          );
        },
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
        (order['docId']
                ?.toString()
                .toLowerCase()
                .contains(searchLower) ??
            false) ||
        (order['vendorName']?.toString().toLowerCase().contains(searchLower) ??
            false) ||
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
      final matchesStatus =
          statusFilter == 'All' || order['status'] == statusFilter;
      final matchesDate = _matchesDateFilter(order, dateFilter);
      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  Widget _buildOrderHistoryContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _orderHistoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading order history: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final allOrders = snapshot.data ?? [];
        final filteredOrders = _filterOrders(
          allOrders,
          _searchQuery,
          _selectedStatus,
          _selectedDateFilter,
        );

        return Container(
          color: const Color(0xFF181B23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchAndFilterBar(
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onStatusChanged: (value) =>
                    setState(() => _selectedStatus = value ?? 'All'),
                onDateFilterChanged: (value) =>
                    setState(() => _selectedDateFilter = value ?? 'All Time'),
                selectedStatus: _selectedStatus,
                selectedDateFilter: _selectedDateFilter,
              ),
              Expanded(
                child: filteredOrders.isEmpty
                    ? const Center(
                        child: Text(
                          'No completed orders found.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 24),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final order = filteredOrders[i];
                          return Card(
                            color: Colors.white.withOpacity(0.04),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                order['productName'] ?? '-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      // Show farm owner details dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor:
                                              const Color(0xFF23263A),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          title: Text(
                                            'Farm Owner Details',
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Name: ${order['farmOwnerName'] ?? '-'}',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Farm: ${order['farmName'] ?? '-'}',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Contact: ${order['farmOwnerPhone'] ?? '-'}',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Location: ${order['farmLocation'] ?? '-'}',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text(
                                                'Close',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Farm Owner: ${order['farmOwnerName'] ?? '-'}',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Customer: ${order['vendorName'] ?? '-'}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    'Phone: ${order['vendorPhone'] ?? '-'}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    'Location: ${order['vendorLocation'] ?? '-'}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    'Quantity: ${order['quantity']} ${order['productUnit']}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    'Status: ${order['status'] ?? 'Delivered'}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.picture_as_pdf,
                                    color: Colors.blue),
                                tooltip: 'Download Invoice',
                                onPressed: () async {
                                  // Reuse existing PDF generation logic
                                  final pdf = pw.Document();
                                  final farmOwnerDoc = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(FirebaseAuth
                                          .instance.currentUser!.uid)
                                      .get();
                                  final farmOwnerData = farmOwnerDoc.data()
                                      as Map<String, dynamic>;
                                  final farmName = farmOwnerData['farmName'] ??
                                      'Farm Name Not Set';

                                  pdf.addPage(
                                    pw.Page(
                                      build: (pw.Context context) => pw.Column(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text('Invoice',
                                              style: pw.TextStyle(
                                                  fontSize: 28,
                                                  fontWeight:
                                                      pw.FontWeight.bold)),
                                          pw.SizedBox(height: 16),
                                          pw.Text(farmName,
                                              style: pw.TextStyle(
                                                  fontSize: 20,
                                                  fontWeight:
                                                      pw.FontWeight.bold)),
                                          pw.SizedBox(height: 16),
                                          pw.Text(
                                              'Order ID: ${order['orderId'] ?? order['docId'] ?? '-'}'),
                                          pw.Text(
                                              'Date: ${order['createdAt'] != null && order['createdAt'] is Timestamp ? (order['createdAt'] as Timestamp).toDate().toString() : '-'}'),
                                          pw.SizedBox(height: 12),
                                          pw.Text('Customer Details:',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold)),
                                          pw.Text(
                                              'Name: ${order['vendorName'] ?? '-'}'),
                                          pw.Text(
                                              'Contact: ${order['vendorPhone'] ?? '-'}'),
                                          pw.Text('Location: ' +
                                              (order['vendorLocation'] ?? '-')),
                                          pw.SizedBox(height: 12),
                                          pw.Text('Order Details:',
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold)),
                                          pw.Text(
                                              'Product: ${order['productName'] ?? '-'}'),
                                          pw.Text('Quantity: ' +
                                              (order['quantity'] ?? '-')),
                                          pw.Text('Unit Price: Rs. ' +
                                              (order['productPrice'] ?? '-')),
                                          pw.Text(
                                              'Total Price: Rs. ' +
                                                  (order['totalPrice'] ?? '-'),
                                              style: pw.TextStyle(
                                                  fontWeight:
                                                      pw.FontWeight.bold)),
                                          pw.SizedBox(height: 16),
                                          pw.Text(
                                              'Status: ${order['status'] ?? '-'}'),
                                        ],
                                      ),
                                    ),
                                  );
                                  final Uint8List pdfBytes = await pdf.save();
                                  final blob =
                                      html.Blob([pdfBytes], 'application/pdf');
                                  final url =
                                      html.Url.createObjectUrlFromBlob(blob);
                                  final anchor = html.AnchorElement(href: url)
                                    ..setAttribute('download', 'invoice.pdf')
                                    ..click();
                                  html.Url.revokeObjectUrl(url);
                                },
                              ),
                              onTap: () => _showOrderDetails(order),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportAllInvoices(List<Map<String, dynamic>> orders) async {
    final pdf = pw.Document();

    // Get farm owner details once for all invoices
    final farmOwnerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    final farmOwnerData = farmOwnerDoc.data() as Map<String, dynamic>;
    final farmName = farmOwnerData['farmName'] ?? 'Farm Name Not Set';

    // Add a cover page
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Invoice Report',
              style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              farmName,
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Generated on: ${DateTime.now().toString().split('.')[0]}',
              style: pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Total Invoices: ${orders.length}',
              style: pw.TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );

    // Add each order as a separate page
    for (var order in orders) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Invoice',
                  style: pw.TextStyle(
                      fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(farmName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Order ID: ${order['orderId'] ?? order['docId'] ?? '-'}'),
              pw.Text(
                  'Date: ${order['createdAt'] != null && order['createdAt'] is Timestamp ? (order['createdAt'] as Timestamp).toDate().toString() : '-'}'),
              pw.SizedBox(height: 12),
              pw.Text('Customer Details:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Name: ${order['vendorName'] ?? '-'}'),
              pw.Text('Contact: ${order['vendorPhone'] ?? '-'}'),
              pw.Text('Delivery Location: ${order['vendorLocation'] ?? '-'}'),
              pw.SizedBox(height: 12),
              pw.Text('Order Details:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Product: ${order['productName'] ?? '-'}'),
              pw.Text('Quantity: ${order['quantity']} ${order['productUnit']}'),
              pw.Text('Unit Price: Rs. ${order['productPrice'] ?? '-'}'),
              pw.Text('Total Price: Rs. ${order['totalPrice'] ?? '-'}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.Text('Status: ${order['status'] ?? '-'}'),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                  'Page ${orders.indexOf(order) + 2} of ${orders.length + 1}',
                  style: pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );
    }

    // Save and download the combined PDF
    final Uint8List pdfBytes = await pdf.save();
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'all_invoices.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _buildInvoicesContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final allOrders = snapshot.data ?? [];
        final filteredOrders = _filterOrders(
          allOrders,
          _searchQuery,
          _selectedStatus,
          _selectedDateFilter,
        );

        return Container(
          color: const Color(0xFF181B23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchAndFilterBar(
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onStatusChanged: (value) =>
                    setState(() => _selectedStatus = value ?? 'All'),
                onDateFilterChanged: (value) =>
                    setState(() => _selectedDateFilter = value ?? 'All Time'),
                selectedStatus: _selectedStatus,
                selectedDateFilter: _selectedDateFilter,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Invoices (${filteredOrders.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          if (filteredOrders.isNotEmpty)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download),
                              label: const Text('Export All'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _exportAllInvoices(filteredOrders),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildInvoiceTable(filteredOrders),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _orderHistoryFuture, // Use only delivered orders
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: {snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final orders = snapshot.data ?? [];
        // Aggregate data for summary cards and charts
        final now = DateTime.now();
        double weekSales = 0, monthSales = 0, yearSales = 0, totalSales = 0;
        int weekOrders = 0,
            monthOrders = 0,
            yearOrders = 0,
            totalOrders = orders.length;
        Map<String, double> productSales = {};
        Map<String, double> vendorSales = {};

        for (var order in orders) {
          final ts = order['createdAt'];
          final date = ts is Timestamp
              ? ts.toDate()
              : DateTime.tryParse(ts?.toString() ?? '') ?? now;
          final total = (order['totalPrice'] ?? 0).toDouble();
          final product = order['productName'] ?? '-';
          final vendor = order['vendorName'] ?? '-';
          totalSales += total;
          if (date.year == now.year) {
            yearSales += total;
            yearOrders++;
            if (date.month == now.month) {
              monthSales += total;
              monthOrders++;
              if (date.difference(now).inDays.abs() < 7) {
                weekSales += total;
                weekOrders++;
              }
            }
          }
          productSales[product] = (productSales[product] ?? 0) + total;
          vendorSales[vendor] =
              ((vendorSales[vendor] ?? 0.0) as double) + total;
        }
        final avgOrder = totalOrders > 0 ? totalSales / totalOrders : 0;

        return Container(
          color: const Color(0xFF181B23),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _summaryCard('This Week', weekSales, weekOrders),
                    _summaryCard('This Month', monthSales, monthOrders),
                    _summaryCard('This Year', yearSales, yearOrders),
                    _summaryCard('Avg Order', avgOrder.toDouble(), totalOrders,
                        isAvg: true),
                  ],
                ),
                const SizedBox(height: 24),
                // Sales Chart
                Text('Sales by Month',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      backgroundColor: const Color(0xFF23263B),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 40),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final month = value.toInt();
                              const months = [
                                'J',
                                'F',
                                'M',
                                'A',
                                'M',
                                'J',
                                'J',
                                'A',
                                'S',
                                'O',
                                'N',
                                'D'
                              ];
                              return Text(months[month],
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12));
                            },
                            interval: 1,
                          ),
                        ),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: List.generate(
                          vendorSales.length,
                          (i) => BarChartGroupData(x: i, barRods: [
                                BarChartRodData(
                                    toY: (vendorSales.values.toList()[i] as num)
                                        .toDouble(),
                                    color: Colors.green)
                              ])),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Top Products Chart
                Text('Top Products',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      sections: productSales.entries
                          .map((e) => PieChartSectionData(
                                value: e.value,
                                title: e.key,
                                color: Colors.primaries[
                                    productSales.keys.toList().indexOf(e.key) %
                                        Colors.primaries.length],
                                titleStyle: TextStyle(
                                    color: Colors.white, fontSize: 12),
                                radius: 50,
                              ))
                          .toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Sales by Vendor
                Text('Sales by Vendor',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      backgroundColor: const Color(0xFF23263B),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 40),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              final vendor = vendorSales.keys.toList();
                              if (idx < 0 || idx >= vendor.length)
                                return Text('',
                                    style: TextStyle(color: Colors.white70));
                              return Text(vendor[idx],
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1);
                            },
                            interval: 1,
                          ),
                        ),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: List.generate(
                          vendorSales.length,
                          (i) => BarChartGroupData(x: i, barRods: [
                                BarChartRodData(
                                    toY: (vendorSales.values.toList()[i] as num)
                                        .toDouble(),
                                    color: Colors.green)
                              ])),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, double value, int count,
      {bool isAvg = false}) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF23263B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
              isAvg
                  ? 'Rs. \\${value.toStringAsFixed(0)}'
                  : 'Rs. \\${value.toStringAsFixed(0)}',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          if (!isAvg)
            Text('Orders: \\${count}',
                style: TextStyle(color: Colors.blue, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInvoiceTable(List<Map<String, dynamic>> orders) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF23263B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Color(0xFF181B23)),
          dataRowColor: MaterialStateProperty.all(Color(0xFF23263B)),
          columns: const [
            DataColumn(
                label: Text('Order ID',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Date',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Customer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Product',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Qty',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Total',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Status',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
            DataColumn(
                label: Text('Invoice',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))),
          ],
          rows: orders.map((order) {
            final orderId = order['orderId'] ?? order['docId'] ?? '-';
            final date = order['createdAt'] is Timestamp
                ? (order['createdAt'] as Timestamp)
                    .toDate()
                    .toString()
                    .split(' ')[0]
                : order['createdAt']?.toString().split(' ')[0] ?? '-';
            return DataRow(cells: [
              DataCell(Text(orderId, style: TextStyle(color: Colors.white70))),
              DataCell(Text(date, style: TextStyle(color: Colors.white70))),
              DataCell(Text(order['vendorName'] ?? '-',
                  style: TextStyle(color: Colors.white70))),
              DataCell(Text(order['productName'] ?? '-',
                  style: TextStyle(color: Colors.white70))),
              DataCell(Text(order['quantity']?.toString() ?? '-',
                  style: TextStyle(color: Colors.white70))),
              DataCell(Text(
                  'Rs. \\${order['totalPrice']?.toStringAsFixed(0) ?? '-'}',
                  style: TextStyle(color: Colors.white70))),
              DataCell(Text(order['status'] ?? '-',
                  style: TextStyle(color: Colors.blue))),
              DataCell(IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                tooltip: 'Download Invoice',
                onPressed: () async {
                  final pdf = pw.Document();

                  // Get farm owner details
                  final farmOwnerDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .get();
                  final farmOwnerData =
                      farmOwnerDoc.data() as Map<String, dynamic>;
                  final farmName =
                      farmOwnerData['farmName'] ?? 'Farm Name Not Set';

                  pdf.addPage(
                    pw.Page(
                      build: (pw.Context context) => pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Invoice',
                              style: pw.TextStyle(
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 8),
                          pw.Text(farmName,
                              style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 16),
                          pw.Text(
                              'Order ID: ${order['orderId'] ?? order['docId'] ?? '-'}'),
                          pw.Text(
                              'Date: ${order['createdAt'] != null && order['createdAt'] is Timestamp ? (order['createdAt'] as Timestamp).toDate().toString() : '-'}'),
                          pw.SizedBox(height: 12),
                          pw.Text('Customer Details:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Name: ${order['vendorName'] ?? '-'}'),
                          pw.Text('Contact: ${order['vendorPhone'] ?? '-'}'),
                          pw.Text(
                              'Delivery Location: ${order['vendorLocation'] ?? '-'}'),
                          pw.SizedBox(height: 12),
                          pw.Text('Order Details:',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Product: ${order['productName'] ?? '-'}'),
                          pw.Text('Quantity: ${order['quantity'] ?? '-'}'),
                          pw.Text(
                              'Unit Price: Rs. ${order['productPrice'] ?? '-'}'),
                          pw.Text(
                              'Total Price: Rs. ${order['totalPrice'] ?? '-'}',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 16),
                          pw.Text('Status: ${order['status'] ?? '-'}'),
                        ],
                      ),
                    ),
                  );
                  final Uint8List pdfBytes = await pdf.save();
                  final blob = html.Blob([pdfBytes], 'application/pdf');
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  final anchor = html.AnchorElement(href: url)
                    ..setAttribute('download', 'invoice.pdf')
                    ..click();
                  html.Url.revokeObjectUrl(url);
                },
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVendorsContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search vendors by name, shop, or contact',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF23263B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => setState(() => _vendorSearchQuery = value),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getVendorsWithOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error loading vendors: snapshot.error}',
                        style: TextStyle(color: Colors.red)));
              }
              final vendors = snapshot.data ?? [];
              final filtered =
                  _vendorSearchQuery == null || _vendorSearchQuery!.isEmpty
                      ? vendors
                      : vendors.where((vendor) {
                          final query = _vendorSearchQuery!.toLowerCase();
                          return (vendor['vendorName'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(query) ||
                              (vendor['shopName'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(query) ||
                              (vendor['contactNumber'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(query);
                        }).toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No vendors found.',
                      style: TextStyle(color: Colors.white70)),
                );
              }
              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final vendor = filtered[i];
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF23263B),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(vendor['vendorName'] ?? '-',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shop: ${vendor['shopName'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Contact: ${vendor['contactNumber'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Address: ${vendor['address'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text('Location: ${vendor['location'] ?? '-'}',
                              style: const TextStyle(color: Colors.white70)),
                          Text(
                              'Last Ordered Item: ${vendor['lastOrderedItem'] ?? '-'}',
                              style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _showVendorOrdersDialog(vendor),
                        child: const Text('View'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String? _vendorSearchQuery;

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<List<Map<String, dynamic>>> _getVendorsWithOrders() async {
    // Fetch all orders where the current farm owner is the vendor
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('vendorId', isEqualTo: _currentUser!.uid)
        .get();
    final orders = ordersSnapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).toList();
    // Group orders by customerId (the vendor who placed the order)
    final vendorMap = <String, Map<String, dynamic>>{};
    for (var order in orders) {
      final vendorId = order['customerId'] ?? '';
      if (!vendorMap.containsKey(vendorId)) {
        // Fetch vendor profile
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(vendorId)
            .get();
        final userData = userDoc.data() ?? {};
        vendorMap[vendorId] = {
          'vendorId': vendorId,
          'vendorName': userData['name'] ?? '-',
          'shopName': userData['shopName'] ?? userData['businessName'] ?? '-',
          'contactNumber':
              userData['contactNumber'] ?? userData['phoneNumber'] ?? '-',
          'address': userData['address'] ?? '-',
          'location': userData['location'] ?? '-',
          'lastOrderedItem': order['productName'] ?? '-',
          'lastOrderId': order['orderId'] ?? '-',
          'orders': [order],
        };
      } else {
        final ordersList = vendorMap[vendorId]?['orders'] as List<dynamic>?;
        if (ordersList != null) {
          ordersList.add(order);
          if ((order['createdAt'] ?? Timestamp(0, 0)) is Timestamp &&
              (ordersList.isNotEmpty &&
                  (ordersList.last['createdAt'] ?? Timestamp(0, 0))
                      is Timestamp) &&
              (order['createdAt'] as Timestamp)
                      .compareTo(ordersList.last['createdAt']) >
                  0) {
            vendorMap[vendorId]?['lastOrderedItem'] =
                order['productName'] ?? '-';
            vendorMap[vendorId]?['lastOrderId'] = order['orderId'] ?? '-';
          }
        }
      }
    }
    return vendorMap.values.toList();
  }

  void _showVendorOrdersDialog(Map<String, dynamic> vendor) {
    final orders = vendor['orders'] as List<dynamic>? ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF23263A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Orders from ${vendor['vendorName']}',
            style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: orders
                  .map((order) => Card(
                        color: Colors.white.withOpacity(0.04),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(order['productName'] ?? '-',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Order ID: ${order['orderId'] ?? order['docId'] ?? '-'}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              Text(
                                  'Quantity: ${order['quantity']} ${order['productUnit']}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              Text('Price: Rs. ${order['productPrice']}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              Text('Total: Rs. ${order['totalPrice']}',
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              Text('Status: ${order['status'] ?? '-'}',
                                  style: const TextStyle(color: Colors.blue)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.picture_as_pdf,
                                color: Colors.blue),
                            tooltip: 'Download Invoice',
                            onPressed: () async {
                              final pdf = pw.Document();
                              pdf.addPage(
                                pw.Page(
                                  build: (pw.Context context) => pw.Column(
                                    crossAxisAlignment:
                                        pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Invoice',
                                          style: pw.TextStyle(
                                              fontSize: 28,
                                              fontWeight: pw.FontWeight.bold)),
                                      pw.SizedBox(height: 8),
                                      pw.Text(
                                          'Order ID: ${order['orderId'] ?? order['docId'] ?? '-'}'),
                                      pw.Text(
                                          'Date: ${order['createdAt'] != null && order['createdAt'] is Timestamp ? (order['createdAt'] as Timestamp).toDate().toString() : '-'}'),
                                      pw.SizedBox(height: 12),
                                      pw.Text('Customer Details:',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold)),
                                      pw.Text(
                                          'Name: ${order['vendorName'] ?? '-'}'),
                                      pw.Text(
                                          'Contact: ${order['vendorPhone'] ?? '-'}'),
                                      pw.Text(
                                          'Delivery Location: ${order['vendorLocation'] ?? '-'}'),
                                      pw.SizedBox(height: 12),
                                      pw.Text('Order Details:',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold)),
                                      pw.Text(
                                          'Product: ${order['productName'] ?? '-'}'),
                                      pw.Text(
                                          'Quantity: ${order['quantity'] ?? '-'}'),
                                      pw.Text(
                                          'Unit Price: Rs. ${order['productPrice'] ?? '-'}'),
                                      pw.Text(
                                          'Total Price: Rs. ${order['totalPrice'] ?? '-'}',
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold)),
                                      pw.SizedBox(height: 16),
                                      pw.Text(
                                          'Status: ${order['status'] ?? '-'}'),
                                    ],
                                  ),
                                ),
                              );
                              final Uint8List pdfBytes = await pdf.save();
                              final blob =
                                  html.Blob([pdfBytes], 'application/pdf');
                              final url =
                                  html.Url.createObjectUrlFromBlob(blob);
                              final anchor = html.AnchorElement(href: url)
                                ..setAttribute('download', 'invoice.pdf')
                                ..click();
                              html.Url.revokeObjectUrl(url);
                            },
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsContent() {
    return FutureBuilder<List<FarmReview>>(
      future: ReviewService().getFarmReviews(_currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading reviews: \\${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }
        final reviews = snapshot.data ?? [];
        double avgRating = 0;
        int totalReviews = reviews.length;
        Map<String, double> categorySums = {
          'quality': 0,
          'packaging': 0,
          'communication': 0,
          'delivery': 0
        };
        for (var review in reviews) {
          avgRating += review.rating;
          review.categoryRatings.forEach((k, v) {
            if (categorySums.containsKey(k))
              categorySums[k] = categorySums[k]! + v;
          });
        }
        avgRating = totalReviews > 0 ? avgRating / totalReviews : 0;
        Map<String, double> categoryAverages = {
          for (var k in categorySums.keys)
            k: totalReviews > 0 ? categorySums[k]! / totalReviews : 0
        };
        // Badge logic: Gold for 4.5+, Silver for 4.0+, Bronze for 3.5+
        String badge = '';
        if (avgRating >= 4.5)
          badge = 'Gold';
        else if (avgRating >= 4.0)
          badge = 'Silver';
        else if (avgRating >= 3.5) badge = 'Bronze';
        return Container(
          color: const Color(0xFF181B23),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Average Rating: ',
                          style: TextStyle(color: Colors.white, fontSize: 20)),
                      ...List.generate(
                          5,
                          (i) => Icon(
                              i < avgRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber)),
                      SizedBox(width: 12),
                      Text(avgRating.toStringAsFixed(2),
                          style: TextStyle(color: Colors.white, fontSize: 20)),
                      if (badge.isNotEmpty) ...[
                        SizedBox(width: 16),
                        Chip(
                            label: Text('$badge Badge'),
                            backgroundColor: badge == 'Gold'
                                ? Colors.amber
                                : badge == 'Silver'
                                    ? Colors.grey
                                    : Colors.brown,
                            labelStyle: TextStyle(color: Colors.black)),
                      ]
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh Reviews',
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text('Total Reviews: $totalReviews',
                  style: TextStyle(color: Colors.white70)),
              SizedBox(height: 16),
              Text('Category Averages:',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Row(
                children: categoryAverages.entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            children: [
                              Text(
                                  '${e.key[0].toUpperCase()}${e.key.substring(1)}',
                                  style: TextStyle(color: Colors.white70)),
                              Row(
                                  children: List.generate(
                                      5,
                                      (i) => Icon(
                                          i < e.value.round()
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 18))),
                              Text(e.value.toStringAsFixed(2),
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              SizedBox(height: 24),
              // Leaderboard
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ReviewService().getTopRatedFarms(limit: 10),
                builder: (context, leaderboardSnapshot) {
                  if (leaderboardSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (leaderboardSnapshot.hasError) {
                    return Center(
                        child: Text('Error loading leaderboard',
                            style: TextStyle(color: Colors.red)));
                  }
                  final topFarms = leaderboardSnapshot.data ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Top Rated Farms:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                      SizedBox(height: 8),
                      ...topFarms.asMap().entries.map((entry) {
                        final i = entry.key;
                        final farm = entry.value;
                        final isCurrent = farm['id'] == _currentUser!.uid;
                        return Container(
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: EdgeInsets.symmetric(vertical: 2),
                          child: ListTile(
                            leading: Text('#${i + 1}',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold)),
                            title: Text((farm['name'] ?? '').toString(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.normal)),
                            subtitle: Text(
                                'Rating: ${(farm['averageRating'] ?? 0).toStringAsFixed(2)} | Reviews: ${(farm['totalReviews'] ?? 0).toString()}',
                                style: TextStyle(color: Colors.white70)),
                            trailing: isCurrent
                                ? Icon(Icons.emoji_events, color: Colors.amber)
                                : null,
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
              SizedBox(height: 24),
              Text('All Reviews:',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              SizedBox(height: 8),
              Expanded(
                child: reviews.isEmpty
                    ? Center(
                        child: Text('No reviews yet.',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.separated(
                        itemCount: reviews.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: Colors.white24),
                        itemBuilder: (context, i) {
                          final r = reviews[i];
                          return ListTile(
                            title: Row(
                              children: [
                                ...List.generate(
                                    5,
                                    (j) => Icon(
                                        j < (r.rating ?? 0).round()
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 18)),
                                SizedBox(width: 8),
                                Text(r.vendorName ?? '',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                Text(
                                    'on \\${r.createdAt != null ? r.createdAt.toDate().toString().split(" ")[0] : ''}',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((r.reviewText ?? '').isNotEmpty)
                                  Text(r.reviewText ?? '',
                                      style: TextStyle(color: Colors.white70)),
                                SizedBox(height: 4),
                                Row(
                                  children: (r.categoryRatings ?? {})
                                      .entries
                                      .map((e) => Padding(
                                            padding:
                                                const EdgeInsets.only(right: 8),
                                            child: Row(
                                              children: [
                                                Text(
                                                    '${e.key[0].toUpperCase()}${e.key.substring(1)}:',
                                                    style: TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12)),
                                                SizedBox(width: 2),
                                                ...List.generate(
                                                    5,
                                                    (j) => Icon(
                                                        j <
                                                                (e.value ?? 0)
                                                                    .round()
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        color: Colors.amber,
                                                        size: 14)),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generateInvoice(Map<String, dynamic> order) async {
    print('Generating invoice for order: ${order.toString()}');
    print('Current user data: ${_currentUser.toString()}');

    // Get farm owner details (current user)
    final farmOwnerDetails = {
      'name': _currentUser!.displayName.isNotEmpty
          ? _currentUser!.displayName
          : _currentUser!.name,
      'farmName': _currentUser!.farmName ?? 'N/A',
      'phone':
          _currentUser!.phoneNumber ?? _currentUser!.contactNumber ?? 'N/A',
      'address': _currentUser!.location ?? _currentUser!.address ?? 'N/A',
    };

    print('Farm Owner details for invoice: $farmOwnerDetails'); // Debug print

    // Get vendor details (who placed the order to the farm owner)
    Map<String, dynamic> vendorDetails = {};
    try {
      final vendorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(order['customerId'])
          .get();
      if (vendorDoc.exists) {
        final vendorData = vendorDoc.data() as Map<String, dynamic>;
        vendorDetails = {
          'name': vendorData['shopName'] ?? vendorData['name'] ?? 'N/A',
          'phone': vendorData['phoneNumber'] ??
              vendorData['contactNumber'] ??
              vendorData['phone'] ??
              vendorData['mobileNumber'] ??
              vendorData['mobile'] ??
              'N/A',
          'address': vendorData['location'] ??
              vendorData['shopAddress'] ??
              vendorData['address'] ??
              'N/A',
        };
      }
    } catch (e) {
      print('Error fetching vendor details for invoice: $e');
    }

    final Map<String, dynamic> invoiceDetails = {
      'farmOwner': farmOwnerDetails,
      'vendor': vendorDetails,
      'order': {
        'id': order['docId'] ?? 'N/A',
        'date': order['createdAt'] is Timestamp
            ? (order['createdAt'] as Timestamp)
                .toDate()
                .toString()
                .split(' ')[0]
            : (order['createdAt']?.toString().split(' ')[0] ?? '-'),
        'status': order['status']?.toString().toUpperCase() ?? 'PENDING',
        'productName': order['productName'] ?? 'N/A',
        'productCategory': order['productCategory'] ?? 'N/A',
        'quantity': order['quantity'] ?? 0,
        'unit': order['productUnit'] ?? 'N/A',
        'price': order['productPrice'] ?? 0.0,
        'total': (order['totalPrice'] ?? 0.0),
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
              pw.Text('Farm Owner Details:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Name: ${invoiceDetails['farmOwner']['name']}'),
              pw.Text('Farm Name: ${invoiceDetails['farmOwner']['farmName']}'),
              pw.Text('Phone: ${invoiceDetails['farmOwner']['phone']}'),
              pw.Text('Address: ${invoiceDetails['farmOwner']['address']}'),
              pw.SizedBox(height: 15),
              pw.Text('Vendor Details:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Name: ${invoiceDetails['vendor']['name']}'),
              pw.Text('Phone: ${invoiceDetails['vendor']['phone']}'),
              pw.Text('Address: ${invoiceDetails['vendor']['address']}'),
              pw.SizedBox(height: 15),
              pw.Text('Order Information:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Order ID: ${invoiceDetails['order']['id']}'),
              pw.Text('Order Date: ${invoiceDetails['order']['date']}'),
              pw.Text('Status: ${invoiceDetails['order']['status']}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              pw.Text('Product Details:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Product: ${invoiceDetails['order']['productName']}'),
              pw.Text(
                  'Category: ${invoiceDetails['order']['productCategory']}'),
              pw.Text('Quantity: ${invoiceDetails['order']['quantity']}'),
              pw.Text('Unit: ${invoiceDetails['order']['unit']}'),
              pw.Text(
                  'Price Per Unit: Rs. ${invoiceDetails['order']['price']}'),
              pw.Text('Total Price: Rs. ${invoiceDetails['order']['total']}'),
            ],
          );
        },
      ),
    );

    try {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'invoice_' + (order['docId'] ?? 'order') + '.pdf',
      );
    } catch (e) {
      print('Error sharing PDF invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to generate or share invoice: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Keep AppBar consistent
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Logout',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
        title: Text(
          'Manage $_selectedTab', // Title updates based on selected tab
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              // TODO: Implement profile navigation or action
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scrollable Tab Bar
          Container(
            color: const Color(0xFF1A1F38), // Tab bar background
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tabs.map((title) => _buildTab(title)).toList(),
              ),
            ),
          ),
          // Content Area
          Expanded(
            child:
                _buildContent(), // Dynamically builds content based on _selectedTab
          ),
        ],
      ),
    );
  }
}
