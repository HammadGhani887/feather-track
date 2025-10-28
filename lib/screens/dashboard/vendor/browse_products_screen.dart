import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/farm_inventory.dart';
import '../../../models/user_profile.dart';
import '../../../services/inventory_service.dart';
import '../../../services/user_service.dart';

class BrowseProductsScreen extends StatefulWidget {
  const BrowseProductsScreen({Key? key}) : super(key: key);

  @override
  _BrowseProductsScreenState createState() => _BrowseProductsScreenState();
}

class _BrowseProductsScreenState extends State<BrowseProductsScreen> {
  final InventoryService _inventoryService = InventoryService();
  final UserService _userService = UserService();
  Future<List<FarmInventory>>? _productsFuture;
  dynamic _currentUser;
  String? _selectedCategory;
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
        setState(() {
          _currentUser = user;
        });
        _loadAvailableProducts();
      } else {
        throw Exception(
            'Unauthorized access: Only vendors can browse products');
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

  Future<void> _loadAvailableProducts() async {
    setState(() {
      _productsFuture = _inventoryService.getAllAvailableProducts();
    });
  }

  void _filterProductsByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      if (category == null || category == 'All') {
        _loadAvailableProducts();
      } else {
        _productsFuture = _inventoryService.getAllAvailableProducts().then(
              (products) => products
                  .where((product) => product.category == category)
                  .toList(),
            );
      }
    });
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

  Widget _buildProductCard(FarmInventory product) {
    return FutureBuilder<String>(
      future: _getFarmName(product.ownerId),
      builder: (context, snapshot) {
        final farmName = snapshot.data ?? 'Loading...';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? Image.network(product.imageUrl!,
                              width: 70, height: 70, fit: BoxFit.cover)
                          : Container(
                              width: 70,
                              height: 70,
                              color: Colors.grey[200],
                              child: Icon(_getCategoryIcon(product.category),
                                  size: 40, color: Colors.grey[500]),
                            ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.itemName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(farmName,
                          style: const TextStyle(
                              color: Colors.blueGrey, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${product.price.toStringAsFixed(0)} per ${product.unit}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.quantity} ${product.unit} Available',
                        style: const TextStyle(
                            color: Colors.blueGrey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8EDF3),
                        foregroundColor: Colors.blueGrey[900],
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                      ),
                      onPressed: () => _showProductDetails(product, farmName),
                      child: const Text('VIEW',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductDetails(FarmInventory product, String farmName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        product.imageUrl != null && product.imageUrl!.isNotEmpty
                            ? Image.network(product.imageUrl!,
                                width: 70, height: 70, fit: BoxFit.cover)
                            : Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey[200],
                                child: Icon(_getCategoryIcon(product.category),
                                    size: 40, color: Colors.grey[500]),
                              ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.itemName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(farmName,
                            style: const TextStyle(
                                color: Colors.blueGrey, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${product.price.toStringAsFixed(0)} per ${product.unit}',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${product.quantity} ${product.unit} Available',
                          style: const TextStyle(
                              color: Colors.blueGrey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (product.description.isNotEmpty)
                Text(product.description, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _placeOrder(product);
                    },
                    child: const Text('Place Order',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C4A7A),
        elevation: 0,
        title: const Text(
          'Browse Products',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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
                            Navigator.pop(context);
                            _filterProductsByCategory(
                                _categories[index] == 'All'
                                    ? null
                                    : _categories[index]);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _productsFuture == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<FarmInventory>>(
              future: _productsFuture,
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
                    child: Text(
                      'Error: \\${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      'No products available',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _buildProductCard(products[index]),
                );
              },
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
      default:
        return Icons.category;
    }
  }

  void _placeOrder(FarmInventory product) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to place an order')),
      );
      return;
    }

    int orderQuantity = 1;
    final nameController =
        TextEditingController(text: _currentUser['name'] ?? '');
    final phoneController =
        TextEditingController(text: _currentUser['contactNumber'] ?? '');
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F38),
          title: Text(
            'Order ${product.itemName}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Name'),
                const SizedBox(height: 12),
                _buildTextField(phoneController, 'Phone (+92 3xx xxxxxxx)'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white),
                      onPressed: () {
                        if (orderQuantity > 1) {
                          setStateDialog(() => orderQuantity--);
                        }
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SizedBox(
                        width: 40,
                        child: TextField(
                          controller: TextEditingController(
                              text: orderQuantity.toString()),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18),
                          onChanged: (val) {
                            final qty = int.tryParse(val);
                            if (qty != null &&
                                qty > 0 &&
                                qty <= product.quantity) {
                              setStateDialog(() => orderQuantity = qty);
                            }
                          },
                          decoration:
                              const InputDecoration(border: InputBorder.none),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () {
                        if (orderQuantity < product.quantity) {
                          setStateDialog(() => orderQuantity++);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Cannot exceed available quantity')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Total Price: Rs. ${(product.price * orderQuantity).toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
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
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final phoneRegex =
                    RegExp(r'^(?:\+92\s?3\d{2}\s?\d{7}|\+923\d{9}|03\d{9})$');
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields.')),
                  );
                  return;
                }
                if (!phoneRegex.hasMatch(phone)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Enter phone in format +92 3xx xxxxxxx, +923xxxxxxxxx, or 03xxxxxxxxx')),
                  );
                  return;
                }
                // Save order to Firestore
                final orderData = {
                  'productId': product.id,
                  'productName': product.itemName,
                  'productCategory': product.category,
                  'productUnit': product.unit,
                  'productPrice': product.price,
                  'quantity': orderQuantity,
                  'totalPrice': product.price * orderQuantity,
                  // Set vendor as customer since they're placing the order
                  'customerId': _currentUser['id'],
                  'customerType': 'vendor',
                  'customerName': name,
                  'customerPhone': phone,
                  // No customerLocation for vendor
                  // Set farm owner as vendor
                  'vendorId': product.ownerId,
                  'vendorType': 'farm_owner',
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                };
                await FirebaseFirestore.instance
                    .collection('orders')
                    .add(orderData);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Order placed successfully!'),
                      backgroundColor: Colors.green),
                );
              },
              child: const Text('Place Order',
                  style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
      ),
    );
  }
}
