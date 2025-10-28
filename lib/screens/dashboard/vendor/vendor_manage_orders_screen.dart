import 'package:flutter/material.dart';
// TODO: Import your order model and service

class VendorManageOrdersScreen extends StatefulWidget {
  const VendorManageOrdersScreen({Key? key}) : super(key: key);

  @override
  State<VendorManageOrdersScreen> createState() =>
      _VendorManageOrdersScreenState();
}

class _VendorManageOrdersScreenState extends State<VendorManageOrdersScreen> {
  // TODO: Replace with your order fetching logic
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    // TODO: Fetch orders for this vendor from Firestore
    setState(() {
      _orders = [];
      _isLoading = false;
    });
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order['orderId']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${order['customerName']}'),
              Text('Contact: ${order['customerContact']}'),
              Text('Address: ${order['customerAddress']}'),
              Text('Products: ${order['products']}'),
              Text('Quantity: ${order['quantity']}'),
              Text('Total Price: ${order['totalPrice']}'),
              Text('Status: ${order['status']}'),
              Text('Order Date: ${order['orderDate']}'),
              Text('Payment: ${order['paymentSummary']}'),
              Text('Notes: ${order['notes'] ?? ''}'),
              // TODO: Status timeline, invoice PDF download
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          ElevatedButton(
              onPressed: () {/* TODO: Download invoice */},
              child: const Text('Invoice PDF')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Orders')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, i) {
                final order = _orders[i];
                return Card(
                  child: ListTile(
                    title: Text('Order ${order['orderId']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Product(s): ${order['products']}'),
                        Text('Quantity: ${order['quantity']}'),
                        Text('Customer: ${order['customerName']}'),
                        Text('Contact: ${order['customerContact']}'),
                        Text('Status: ${order['status']}'),
                        Text('Order Date: ${order['orderDate']}'),
                        Text('Total: ${order['totalPrice']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check),
                          tooltip: 'Mark as Delivered',
                          onPressed: () {/* TODO: Mark as delivered */},
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel),
                          tooltip: 'Cancel Order',
                          onPressed: () {/* TODO: Cancel order */},
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf),
                          tooltip: 'View Invoice',
                          onPressed: () => _showOrderDetail(order),
                        ),
                      ],
                    ),
                    onTap: () => _showOrderDetail(order),
                  ),
                );
              },
            ),
    );
  }
}
