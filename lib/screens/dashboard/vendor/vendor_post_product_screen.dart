import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/vendor_product.dart';
import '../../../services/vendor_product_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VendorPostProductScreen extends StatefulWidget {
  const VendorPostProductScreen({Key? key}) : super(key: key);

  @override
  State<VendorPostProductScreen> createState() =>
      _VendorPostProductScreenState();
}

class _VendorPostProductScreenState extends State<VendorPostProductScreen> {
  final VendorProductService _productService = VendorProductService();
  final _auth = FirebaseAuth.instance;
  List<VendorProduct> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final vendorId = _auth.currentUser?.uid;
    if (vendorId == null) return;
    final products = await _productService.getVendorProducts(vendorId);
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _showProductDialog({VendorProduct? existingProduct}) async {
    final result = await showDialog<VendorProduct>(
      context: context,
      builder: (context) => ProductPostDialog(
        existingProduct: existingProduct,
        vendorId: _auth.currentUser?.uid,
      ),
    );
    if (result != null) {
      setState(() => _isLoading = true);
      if (existingProduct == null) {
        await _productService.addVendorProduct(result);
      } else {
        await _productService.updateVendorProduct(
            result, existingProduct.quantity);
      }
      await _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(existingProduct == null
                ? 'Product posted!'
                : 'Product updated!')),
      );
    }
  }

  Future<void> _deleteProduct(VendorProduct product) async {
    setState(() => _isLoading = true);
    await _productService.deleteVendorProduct(product);
    await _loadProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post & Manage Products')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                      onPressed: () => _showProductDialog(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Your Posted Products:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._products.map((p) => Card(
                        child: ListTile(
                          title: Text(p.title),
                          subtitle: Text(
                              '${p.type} | ${p.pricePerUnit} ${p.unit} | Qty: ${p.quantity}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _showProductDialog(existingProduct: p),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteProduct(p),
                              ),
                            ],
                          ),
                          leading: p.imageUrl != null
                              ? Image.network(p.imageUrl!,
                                  width: 40, height: 40, fit: BoxFit.cover)
                              : const Icon(Icons.image),
                          isThreeLine: true,
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}

class ProductPostDialog extends StatefulWidget {
  final VendorProduct? existingProduct;
  final String? vendorId;
  const ProductPostDialog({Key? key, this.existingProduct, this.vendorId})
      : super(key: key);

  @override
  State<ProductPostDialog> createState() => _ProductPostDialogState();
}

class _ProductPostDialogState extends State<ProductPostDialog> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _type = 'Live Chicken';
  double _pricePerUnit = 0.0;
  int _quantity = 0;
  String _unit = 'per kg';
  String _description = '';
  String _shippingEstimate = '';
  String? _deliveryArea;
  bool _isVisible = true;

  final List<String> _types = [
    'Live Chicken',
    'Halal Chicken',
    'Eggs',
    'Feed',
    'Accessories',
  ];
  final List<String> _units = [
    'per kg',
    'per dozen',
    'per item',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    if (p != null) {
      _title = p.title;
      _type = p.type;
      _pricePerUnit = p.pricePerUnit;
      _quantity = p.quantity;
      _unit = p.unit;
      _description = p.description;
      _shippingEstimate = p.shippingEstimate;
      _deliveryArea = p.deliveryArea;
      _isVisible = p.isVisible;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F38),
      title: Text(
          widget.existingProduct == null ? 'Add Product' : 'Edit Product',
          style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Product Title'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => _title = v ?? '',
              ),
              DropdownButtonFormField<String>(
                value: _type,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
                decoration: const InputDecoration(labelText: 'Product Type'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue:
                          _pricePerUnit == 0.0 ? '' : _pricePerUnit.toString(),
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || double.tryParse(v) == null
                          ? 'Enter a valid price'
                          : null,
                      onSaved: (v) =>
                          _pricePerUnit = double.tryParse(v ?? '') ?? 0.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      items: _units
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              TextFormField(
                initialValue: _quantity == 0 ? '' : _quantity.toString(),
                decoration:
                    const InputDecoration(labelText: 'Quantity in Stock'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null
                    ? 'Enter a valid quantity'
                    : null,
                onSaved: (v) => _quantity = int.tryParse(v ?? '') ?? 0,
              ),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                onSaved: (v) => _description = v ?? '',
              ),
              TextFormField(
                initialValue: _shippingEstimate,
                decoration:
                    const InputDecoration(labelText: 'Shipping Time Estimate'),
                onSaved: (v) => _shippingEstimate = v ?? '',
              ),
              TextFormField(
                initialValue: _deliveryArea,
                decoration: const InputDecoration(
                    labelText: 'Delivery Area/Region (optional)'),
                onSaved: (v) => _deliveryArea = v,
              ),
              SwitchListTile(
                value: _isVisible,
                onChanged: (v) => setState(() => _isVisible = v),
                title: const Text('Visible to Customers',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final now = DateTime.now();
              final product = VendorProduct(
                id: widget.existingProduct?.id ?? '',
                vendorId: widget.vendorId ?? '',
                title: _title,
                type: _type,
                pricePerUnit: _pricePerUnit,
                quantity: _quantity,
                unit: _unit,
                imageUrl: null,
                description: _description,
                shippingEstimate: _shippingEstimate,
                deliveryArea: _deliveryArea,
                isVisible: _isVisible,
                createdAt: widget.existingProduct?.createdAt ??
                    Timestamp.fromDate(now),
                ownerRole: 'Vendor',
              );
              Navigator.pop(context, product);
            }
          },
          child: Text(widget.existingProduct == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }
}
