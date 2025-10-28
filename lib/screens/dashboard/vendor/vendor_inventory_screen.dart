import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/farm_inventory.dart';
import '../../../models/user_profile.dart';
import '../../../models/vendor_product.dart';
import '../../../services/inventory_service.dart';
import '../../../services/user_service.dart';
import '../../../services/vendor_product_service.dart';
import '../../../services/order_service.dart';
import 'vendor_post_product_screen.dart';

class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen({Key? key}) : super(key: key);

  @override
  _VendorInventoryScreenState createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen>
    with SingleTickerProviderStateMixin {
  final InventoryService _inventoryService = InventoryService();
  final UserService _userService = UserService();
  final VendorProductService _vendorProductService = VendorProductService();
  final OrderService _orderService = OrderService();
  late Future<List<FarmInventory>> _inventoryFuture;
  late Future<List<VendorProduct>> _postedProductsFuture;
  List<Map<String, dynamic>> _unacknowledgedOrders = [];
  String? _selectedCategory;
  final List<String> _categories = ['All', 'Bird', 'Egg', 'Feed', 'Other'];
  dynamic _currentUser;
  late TabController _tabController;

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
      final user = await _userService.getCurrentUserProfile();
      if (user != null && user['role'] == 'Vendor') {
        setState(() {
          _currentUser = user;
        });
        _loadInventory();
      } else {
        throw Exception('Unauthorized access: Only vendors can view this page');
      }
    } catch (e) {
      print('Error initializing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadInventory() async {
    try {
      if (_currentUser == null) {
        throw Exception('No user found');
      }

      // Fetch unacknowledged orders
      final unacknowledged =
          await _orderService.getUnacknowledgedOrders(_currentUser['id']);
      setState(() {
        _unacknowledgedOrders = unacknowledged;

        if (_selectedCategory == null || _selectedCategory == 'All') {
          _inventoryFuture = _inventoryService.getInventory(
              _currentUser['id'], InventoryOwnerType.vendor);
          _postedProductsFuture =
              _vendorProductService.getVendorProducts(_currentUser['id']);
        } else {
          _inventoryFuture = _inventoryService.getInventoryByCategory(
              _currentUser['id'],
              InventoryOwnerType.vendor,
              _selectedCategory!);
          _postedProductsFuture =
              _vendorProductService.getVendorProducts(_currentUser['id']);
        }
      });

      // Debug print to check the loaded inventory
      _inventoryFuture.then((inventory) {
        print('Loaded vendor inventory items: ${inventory.length}');
        inventory.forEach((item) {
          print(
              'Item: ${item.itemName}, Category: ${item.category}, Owner: ${item.ownerId}');
        });
      }).catchError((error) {
        print('Error loading vendor inventory: $error');
      });
    } catch (e) {
      print('Error loading inventory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addOrEditInventoryItem(BuildContext context,
      {FarmInventory? existingItem, VoidCallback? onSave}) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a vendor')),
      );
      return;
    }

    if (_currentUser['role'] != 'Vendor') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only vendors can manage inventory')),
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
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F38),
          title: Text(
            existingItem == null ? 'Add Inventory Item' : 'Edit Inventory Item',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Item Name'),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Category',
                  category,
                  ['Bird', 'Egg', 'Feed', 'Other'],
                  (value) => setState(() => category = value!),
                ),
                const SizedBox(height: 16),
                _buildTextField(quantityController, 'Quantity'),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Unit',
                  unit,
                  ['birds', 'dozens', 'kg', 'items'],
                  (value) => setState(() => unit = value!),
                ),
                const SizedBox(height: 16),
                _buildTextField(priceController, 'Price'),
                const SizedBox(height: 16),
                _buildTextField(descriptionController, 'Description'),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Available',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: isAvailable,
                  onChanged: (value) => setState(() => isAvailable = value),
                  activeColor: Colors.blue,
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
                    throw Exception('Item name is required');
                  }

                  if (int.tryParse(quantityController.text) == null) {
                    throw Exception('Invalid quantity');
                  }

                  if (double.tryParse(priceController.text) == null) {
                    throw Exception('Invalid price');
                  }

                  final item = existingItem != null
                      ? existingItem.copyWith(
                          itemName: nameController.text,
                          category: category,
                          quantity: int.tryParse(quantityController.text) ?? 0,
                          unit: unit,
                          price: double.tryParse(priceController.text) ?? 0.0,
                          description: descriptionController.text,
                          isAvailable: isAvailable,
                        )
                      : FarmInventory(
                          id: '',
                          ownerId: _currentUser['id'],
                          ownerType: InventoryOwnerType.vendor,
                          itemName: nameController.text,
                          category: category,
                          quantity: int.tryParse(quantityController.text) ?? 0,
                          unit: unit,
                          price: double.tryParse(priceController.text) ?? 0.0,
                          description: descriptionController.text,
                          imageUrl: null,
                          createdAt: Timestamp.now(),
                          updatedAt: Timestamp.now(),
                          isAvailable: isAvailable,
                        );

                  if (existingItem != null) {
                    final success = await _inventoryService.updateInventoryItem(
                        item, UserProfile.fromMap(_currentUser));
                    if (!success) throw Exception('Failed to update item');
                  } else {
                    final newItem = await _inventoryService.addInventoryItem(
                        item, UserProfile.fromMap(_currentUser));
                    if (newItem == null) throw Exception('Failed to add item');
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    onSave?.call();
                    _loadInventory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          existingItem == null
                              ? 'Item added successfully'
                              : 'Item updated successfully',
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
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a vendor')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text(
          'Delete Item',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this item?',
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
        final success = await _inventoryService.deleteInventoryItem(
            itemId, UserProfile.fromMap(_currentUser));
        if (success && mounted) {
          _loadInventory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete item')),
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

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      style: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF1A1F38),
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Vendor Inventory Management'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Vendor Inventory Management',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInventory,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1F38),
                  title: const Text(
                    'Filter by Category',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            _categories[index],
                            style: const TextStyle(color: Colors.white),
                          ),
                          selected: _selectedCategory == _categories[index] ||
                              (_selectedCategory == null &&
                                  _categories[index] == 'All'),
                          selectedTileColor: Colors.blue.withOpacity(0.2),
                          onTap: () {
                            setState(() {
                              _selectedCategory = _categories[index] == 'All'
                                  ? null
                                  : _categories[index];
                            });
                            Navigator.pop(context);
                            _loadInventory();
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            onPressed: () => _addOrEditInventoryItem(context),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Inventory Items'),
            Tab(text: 'Posted Products'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_unacknowledgedOrders.isNotEmpty) _buildNotificationArea(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Inventory Items Tab
                _buildInventoryTab(),
                // Posted Products Tab
                _buildPostedProductsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationArea() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.blue.withOpacity(0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivered Orders',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _unacknowledgedOrders.length,
            itemBuilder: (context, index) {
              final order = _unacknowledgedOrders[index];
              return Card(
                color: Colors.white.withOpacity(0.08),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    'Order from ${order['vendorName'] ?? 'Unknown Farm'} received: ${order['productName']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Quantity: ${order['quantity']}. Add to inventory?',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          final farmInventoryItem = FarmInventory(
                            id: '', // This will be generated by Firestore
                            ownerId: _currentUser['id'],
                            ownerType: InventoryOwnerType.vendor,
                            itemName: order['productName'] ?? '',
                            category: order['productCategory'] ?? 'Other',
                            quantity: order['quantity'] ?? 0,
                            unit: order['productUnit'] ?? 'units',
                            price: 0, // Vendor sets their own price
                            description:
                                'Received from ${order['vendorName'] ?? 'a farm'}',
                            createdAt: Timestamp.now(),
                            updatedAt: Timestamp.now(),
                            isAvailable: true,
                          );
                          _addOrEditInventoryItem(context,
                              existingItem: farmInventoryItem,
                              onSave: () async {
                            await OrderService()
                                .acknowledgeOrder(order['docId']);
                            _loadInventory(); // Refresh notifications and inventory
                          });
                        },
                        child: const Text('Yes'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await OrderService().acknowledgeOrder(order['docId']);
                          _loadInventory(); // Refresh list
                        },
                        child: const Text('No',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E21),
            const Color(0xFF0A0E21).withOpacity(0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category: ${_selectedCategory ?? 'All'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<FarmInventory>>(
                future: _inventoryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInventory,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final inventory = snapshot.data ?? [];

                  if (inventory.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'No inventory items found',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Go to "Post Products & Manage" to add new products',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadInventory,
                    child: ListView.builder(
                      itemCount: inventory.length,
                      itemBuilder: (context, index) {
                        final item = inventory[index];
                        return Card(
                          color: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Image
                                    if (item.imageUrl != null &&
                                        item.imageUrl!.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          item.imageUrl!,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getCategoryIcon(item.category),
                                          size: 40,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    const SizedBox(width: 16),
                                    // Product Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.itemName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Category: ${item.category}',
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                          Text(
                                            'Quantity: ${item.quantity} ${item.unit}',
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                          Text(
                                            'Price: \$${item.price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                color: Colors.white70),
                                          ),
                                          Row(
                                            children: [
                                              const Text(
                                                'Available: ',
                                                style: TextStyle(
                                                    color: Colors.white70),
                                              ),
                                              Icon(
                                                item.isAvailable
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: item.isAvailable
                                                    ? Colors.green
                                                    : Colors.red,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Action Buttons
                                    Column(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit,
                                              color: Colors.blue),
                                          onPressed: () =>
                                              _addOrEditInventoryItem(context,
                                                  existingItem: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteInventoryItem(item.id),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (item.description.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(color: Colors.white24),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Description:',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostedProductsTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A0E21),
            const Color(0xFF0A0E21).withOpacity(0.8),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<VendorProduct>>(
          future: _postedProductsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.blue,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadInventory,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final products = snapshot.data ?? [];

            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'No posted products found',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const VendorPostProductScreen(),
                          ),
                        );
                      },
                      child: const Text('Post New Product'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _loadInventory,
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    color: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image
                              if (product.imageUrl != null &&
                                  product.imageUrl!.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    product.imageUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(product.type),
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              const SizedBox(width: 16),
                              // Product Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Type: ${product.type}',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    Text(
                                      'Quantity: ${product.quantity} ${product.unit}',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    Text(
                                      'Price: \$${product.pricePerUnit.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    Row(
                                      children: [
                                        const Text(
                                          'Visible: ',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                        Icon(
                                          product.isVisible
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                          color: product.isVisible
                                              ? Colors.green
                                              : Colors.red,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Action Buttons
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const VendorPostProductScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor:
                                              const Color(0xFF1A1F38),
                                          title: const Text(
                                            'Delete Product',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          content: const Text(
                                            'Are you sure you want to delete this product?',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancel',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        try {
                                          await _vendorProductService
                                              .deleteVendorProduct(product);
                                          _loadInventory();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Product deleted successfully')),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Error: ${e.toString()}')),
                                            );
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (product.description.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 8),
                            Text(
                              'Description:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.description,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                          if (product.deliveryArea != null &&
                              product.deliveryArea!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Delivery Area: ${product.deliveryArea}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                          if (product.shippingEstimate.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Shipping: ${product.shippingEstimate}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bird':
        return Icons.pets;
      case 'egg':
        return Icons.egg_alt;
      case 'feed':
        return Icons.grass;
      case 'live chicken':
        return Icons.pets;
      case 'halal chicken':
        return Icons.restaurant;
      case 'accessories':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }
}
