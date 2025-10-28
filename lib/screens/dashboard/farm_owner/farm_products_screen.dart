import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/farm_inventory.dart';
import '../../../services/inventory_service.dart';
import '../../../services/order_service.dart';
import '../../../models/user_profile.dart';
import '../../../services/user_service.dart';

class FarmProductsScreen extends StatefulWidget {
  final String farmId;
  final String farmName;

  const FarmProductsScreen({
    Key? key,
    required this.farmId,
    required this.farmName,
  }) : super(key: key);

  @override
  _FarmProductsScreenState createState() => _FarmProductsScreenState();
}

class _FarmProductsScreenState extends State<FarmProductsScreen> {
  final InventoryService _inventoryService = InventoryService();
  final OrderService _orderService = OrderService();
  final UserService _userService = UserService();
  List<FarmInventory> _products = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Bird', 'Egg', 'Feed', 'Other'];

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final user = await _userService.getCurrentUserProfile();
      if (user != null && user['role'] == 'Vendor') {
        setState(() => _currentUser = user);
        _loadProducts();
      } else {
        throw Exception('Unauthorized access: Only vendors can view this page');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);
      final products = await _inventoryService.getFarmInventory(widget.farmId);
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  List<FarmInventory> get _filteredProducts {
    if (_selectedCategory == 'All') {
      return _products;
    }
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  Future<void> _placeOrder(FarmInventory product) async {
    if (_currentUser == null) return;

    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place Order'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Product: ${product.itemName}'),
              Text('Available: ${product.quantity} ${product.unit}'),
              Text('Price: \$${product.price}/${product.unit}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final qty = int.tryParse(value);
                  if (qty == null || qty <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  if (qty > product.quantity) {
                    return 'Quantity exceeds available stock';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final quantity = int.parse(quantityController.text);
                try {
                  await _orderService.createVendorOrder(
                    vendorId: _currentUser!['id'],
                    vendorName: _currentUser!['displayName'],
                    vendorPhone: _currentUser!['phoneNumber'] ?? '',
                    farmId: widget.farmId,
                    farmName: widget.farmName,
                    productId: product.id,
                    productName: product.itemName,
                    quantity: quantity,
                    unit: product.unit,
                    price: product.price,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Order placed successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error placing order: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Place Order'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.farmName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const Center(
                          child: Text('No products available in this category'),
                        )
                      : ListView.builder(
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                title: Text(
                                  product.itemName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text('Category: ${product.category}'),
                                    Text(
                                        'Available: ${product.quantity} ${product.unit}'),
                                    Text(
                                        'Price: \$${product.price}/${product.unit}'),
                                    if (product.description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(product.description),
                                    ],
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: product.isAvailable
                                      ? () => _placeOrder(product)
                                      : null,
                                  child: const Text('Order'),
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
}
