import 'package:flutter/material.dart';
import '../../../models/vendor_product.dart';
import '../../../services/vendor_product_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerProductListScreen extends StatefulWidget {
  const CustomerProductListScreen({Key? key}) : super(key: key);

  @override
  State<CustomerProductListScreen> createState() =>
      _CustomerProductListScreenState();
}

class _CustomerProductListScreenState extends State<CustomerProductListScreen> {
  final VendorProductService _productService = VendorProductService();
  final _auth = FirebaseAuth.instance;
  List<VendorProduct> _products = [];
  bool _isLoading = true;
  String _selectedType = 'All';
  String _selectedUnit = 'All';
  double _minPrice = 0;
  double _maxPrice = double.infinity;

  final List<String> _types = [
    'All',
    'Live Chicken',
    'Halal Chicken',
    'Eggs',
    'Feed',
    'Accessories',
  ];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products =
        await _productService.getVisibleVendorProductsForCustomers();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  List<VendorProduct> get _filteredProducts {
    return _products.where((product) {
      if (_selectedType != 'All' && product.type != _selectedType) return false;
      if (_selectedUnit != 'All' && product.unit != _selectedUnit) return false;
      if (product.pricePerUnit < _minPrice || product.pricePerUnit > _maxPrice)
        return false;
      return true;
    }).toList();
  }

  void _showOrderDialog(VendorProduct product) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => OrderDialog(product: product),
    );

    if (result != null) {
      // Fetch customer name and phone number
      String customerName = '';
      String customerPhone = '';
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .get();
        final data = userDoc.data();
        if (data != null) {
          customerName = data['name'] ?? data['displayName'] ?? '';
          customerPhone = data['phoneNumber'] ?? data['contactNumber'] ?? '';
        }
      } catch (_) {}
      // Create order in Firestore
      final order = {
        // Customer details
        'customerId': _auth.currentUser?.uid,
        'customerType': 'customer',
        'customerName': customerName,
        'customerPhone': result['phone'] ?? customerPhone,
        'customerLocation': result['address'],
        // Vendor details
        'vendorId': product.vendorId,
        'vendorType': 'vendor',
        // Product details
        'productId': product.id,
        'productName': product.title,
        'productCategory': product.type,
        'productUnit': product.unit,
        'productPrice': product.pricePerUnit,
        'quantity': result['quantity'],
        'totalPrice': product.pricePerUnit * result['quantity'],
        // Order details
        'paymentMethod': result['paymentMethod'],
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance.collection('orders').add(order);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e')),
        );
      }
    }
  }

  Future<String> _getVendorShopName(String vendorId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(vendorId)
        .get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      return data['businessName'] ??
          data['shopName'] ??
          data['name'] ??
          'Unknown Shop';
    }
    return 'Unknown Shop';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_selectedType != 'All')
                        Chip(
                          label: Text('Type: $_selectedType'),
                          onDeleted: () =>
                              setState(() => _selectedType = 'All'),
                        ),
                      if (_selectedUnit != 'All')
                        Chip(
                          label: Text('Unit: $_selectedUnit'),
                          onDeleted: () =>
                              setState(() => _selectedUnit = 'All'),
                        ),
                      if (_minPrice > 0 || _maxPrice < double.infinity)
                        Chip(
                          label: Text(
                              'Price: \$${_minPrice.toStringAsFixed(2)} - \$${_maxPrice == double.infinity ? "∞" : _maxPrice.toStringAsFixed(2)}'),
                          onDeleted: () {
                            setState(() {
                              _minPrice = 0;
                              _maxPrice = double.infinity;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(product.title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<String>(
                                future: _getVendorShopName(product.vendorId),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? 'Loading shop...',
                                    style: const TextStyle(
                                        color: Colors.blueGrey, fontSize: 15),
                                  );
                                },
                              ),
                              Text(
                                  '${product.type} | ${product.pricePerUnit} ${product.unit}'),
                              Text('Available: ${product.quantity}'),
                              Text('Shipping: ${product.shippingEstimate}'),
                              if (product.deliveryArea != null)
                                Text('Delivery Area: ${product.deliveryArea}'),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showOrderDialog(product),
                            child: const Text('Order'),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Products'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: _types
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedType = value!),
              decoration: const InputDecoration(labelText: 'Product Type'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _minPrice.toString(),
                    decoration: const InputDecoration(labelText: 'Min Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        setState(() => _minPrice = double.tryParse(value) ?? 0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _maxPrice == double.infinity
                        ? ''
                        : _maxPrice.toString(),
                    decoration: const InputDecoration(labelText: 'Max Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() =>
                        _maxPrice = double.tryParse(value) ?? double.infinity),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class OrderDialog extends StatefulWidget {
  final VendorProduct product;

  const OrderDialog({Key? key, required this.product}) : super(key: key);

  @override
  State<OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<OrderDialog> {
  final _formKey = GlobalKey<FormState>();
  int _quantity = 1;
  String _address = '';
  String _paymentMethod = 'Cash on Delivery';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  void _loadPhone() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = userDoc.data();
        if (data != null) {
          setState(() {
            _phone = data['phoneNumber'] ?? data['contactNumber'] ?? '';
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Place Order'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${widget.product.title} - ${widget.product.pricePerUnit} ${widget.product.unit}'),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _quantity.toString(),
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null)
                  return 'Enter a valid quantity';
                final qty = int.parse(value);
                if (qty <= 0) return 'Quantity must be greater than 0';
                if (qty > widget.product.quantity) return 'Not enough stock';
                return null;
              },
              onChanged: (value) {
                setState(() {
                  _quantity = int.tryParse(value) ?? 1;
                });
              },
              onSaved: (value) => _quantity = int.parse(value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _phone,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Required' : null,
              onChanged: (value) => _phone = value,
              onSaved: (value) => _phone = value ?? '',
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Delivery Address'),
              maxLines: 2,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              onSaved: (value) => _address = value!,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              items: ['Cash on Delivery']
                  .map((method) => DropdownMenuItem(
                        value: method,
                        child: Text(method),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _paymentMethod = value!),
              decoration: const InputDecoration(labelText: 'Payment Method'),
            ),
            const SizedBox(height: 16),
            Text(
              'Total: \$${(widget.product.pricePerUnit * _quantity).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.pop(context, {
                'quantity': _quantity,
                'address': _address,
                'paymentMethod': _paymentMethod,
                'phone': _phone,
              });
            }
          },
          child: const Text('Place Order'),
        ),
      ],
    );
  }
}
