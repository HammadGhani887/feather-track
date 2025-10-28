import 'package:flutter/material.dart';
import '../../../models/user_profile.dart';
import '../../../models/farm_inventory.dart';
import '../../../models/farm_review.dart';
import '../../../services/user_service.dart';
import '../../../services/inventory_service.dart';
import '../../../services/review_service.dart';
import '../../../services/order_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmDetailsScreen extends StatefulWidget {
  final String farmOwnerId;

  const FarmDetailsScreen({Key? key, required this.farmOwnerId})
      : super(key: key);

  @override
  _FarmDetailsScreenState createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  final UserService _userService = UserService();
  final InventoryService _inventoryService = InventoryService();
  final ReviewService _reviewService = ReviewService();

  UserProfile? _farmOwnerProfile;
  List<FarmInventory> _products = [];
  List<FarmReview> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFarmData();
  }

  Future<void> _loadAllFarmData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getUserProfileById(widget.farmOwnerId);
      if (profile != null) {
        final products =
            await _inventoryService.getFarmInventory(widget.farmOwnerId);
        final reviews = await _reviewService.getFarmReviews(widget.farmOwnerId);
        setState(() {
          _farmOwnerProfile = profile;
          _products = products;
          _reviews = reviews;
        });
      }
    } catch (e) {
      print('Error loading farm details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading details: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _placeOrder(FarmInventory product) async {
    final currentUser = await _userService.getCurrentUserProfile();
    if (currentUser == null || currentUser['role'] != 'Vendor') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Only vendors are allowed to place orders.')),
      );
      return;
    }

    String vendorName =
        currentUser['shopName'] ?? currentUser['name'] ?? 'Unknown Vendor';
    String vendorPhone =
        currentUser['contactNumber'] ?? currentUser['phone'] ?? '';
    int quantity = 1;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${product.itemName}'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Quantity'),
          keyboardType: TextInputType.number,
          onChanged: (value) => quantity = int.tryParse(value) ?? 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, quantity),
            child: const Text('Order'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await OrderService().createVendorOrder(
        vendorId: currentUser['id'],
        vendorName: vendorName,
        vendorPhone: vendorPhone,
        farmId: widget.farmOwnerId,
        farmName: _farmOwnerProfile?.farmName ?? 'Unknown Farm',
        productId: product.id,
        productName: product.itemName,
        quantity: result,
        unit: product.unit,
        price: product.price,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully')),
      );
    }
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 16);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_farmOwnerProfile?.farmName ?? 'Farm Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _farmOwnerProfile == null
              ? const Center(child: Text('Farm not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Farm Info Card
                      Card(
                        color: Colors.white.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _farmOwnerProfile!.farmName ?? 'Unnamed Farm',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.white70, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _farmOwnerProfile!.location ?? 'N/A',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone,
                                      color: Colors.white70, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    _farmOwnerProfile!.contactNumber ?? 'N/A',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Products Section
                      _buildSectionTitle('Products'),
                      _products.isEmpty
                          ? _buildEmptyState('No products listed yet.')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return Card(
                                  color: Colors.white.withOpacity(0.05),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    title: Text(product.itemName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      '${product.quantity} ${product.unit} - \$${product.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    trailing: FutureBuilder<dynamic>(
                                      future:
                                          _userService.getCurrentUserProfile(),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.done) {
                                          final currentUser = snapshot.data;
                                          if (currentUser != null &&
                                              currentUser['role'] == 'Vendor') {
                                            return ElevatedButton(
                                              onPressed: () =>
                                                  _placeOrder(product),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Order'),
                                            );
                                          }
                                        }
                                        return const SizedBox
                                            .shrink(); // Return empty space if not a vendor or while loading
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 24),

                      // Reviews Section
                      _buildSectionTitle('Reviews'),
                      _reviews.isEmpty
                          ? _buildEmptyState('No reviews yet.')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _reviews.length,
                              itemBuilder: (context, index) {
                                final review = _reviews[index];
                                return Card(
                                  color: Colors.white.withOpacity(0.05),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Vendor: ${review.vendorName}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                            _buildStarRating(review.rating),
                                          ],
                                        ),
                                        Text(
                                          'Order ID: ${review.orderId}',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          review.reviewText,
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Reviewed on ${review.createdAt.toDate().toString().split(' ')[0]}',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
}
