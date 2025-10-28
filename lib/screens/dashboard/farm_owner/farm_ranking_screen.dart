import 'package:flutter/material.dart';
import '../../../models/farm_review.dart';
import '../../../models/user_profile.dart';
import '../../../services/review_service.dart';
import '../../../services/user_service.dart';
import '../../../services/order_service.dart';
import 'farm_details_screen.dart';

class FarmRankingScreen extends StatefulWidget {
  final bool isVendorView;

  const FarmRankingScreen({
    super.key,
    this.isVendorView = false,
  });

  @override
  _FarmRankingScreenState createState() => _FarmRankingScreenState();
}

class _FarmRankingScreenState extends State<FarmRankingScreen> {
  final ReviewService _reviewService = ReviewService();
  final UserService _userService = UserService();
  final OrderService _orderService = OrderService();
  List<FarmReview> _reviews = [];
  double _averageRating = 0.0;
  int _selectedFilter = 0; // 0 = All, 1-5 = star filter
  int _farmRank = 0;
  List<Map<String, dynamic>> _allFarms = [];
  List<FarmReview> _vendorReviews = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedVendor = '';
  String _selectedOrderId = '';
  double? _minRating;
  String? _farmOwnerId;
  String? _farmName;
  dynamic _currentUser;
  String _productName = '';
  int _quantity = 0;
  String _unit = '';
  double _price = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeUserAndLoadData();
  }

  Future<void> _initializeUserAndLoadData() async {
    setState(() => _isLoading = true);
    final userProfile = await _userService.getCurrentUserProfile();
    if (userProfile != null) {
      setState(() {
        _currentUser = userProfile;
        if (userProfile['role'] == 'Farm Owner') {
          _farmOwnerId = userProfile['id'];
          _farmName = userProfile['farmName'] ?? 'Your Farm';
        }
      });
      await _loadReviewsAndFarms();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load user data.')),
      );
    }
  }

  Future<void> _loadReviewsAndFarms() async {
    try {
      setState(() => _isLoading = true);
      // Load reviews with filters (for this farm only if farm owner)
      final reviews = await _reviewService.searchReviews(
        farmOwnerId: widget.isVendorView ? null : _farmOwnerId,
        vendorName: _selectedVendor.isEmpty ? null : _selectedVendor,
        orderId: _selectedOrderId.isEmpty ? null : _selectedOrderId,
        minRating: _minRating,
      );
      // Load farm rankings (all farms)
      final rankings = await _reviewService.getAllFarmRankings();

      if (widget.isVendorView && _currentUser != null) {
        final vendorReviews =
            await _reviewService.searchReviews(vendorId: _currentUser['id']);
        setState(() {
          _vendorReviews = vendorReviews;
        });
      }

      // Calculate average rating for farm owner view
      double totalRating = 0;
      if (!widget.isVendorView && _farmOwnerId != null) {
        final farmReviews =
            reviews.where((r) => r.farmOwnerId == _farmOwnerId).toList();
        for (var review in farmReviews) {
          totalRating += review.rating;
        }
        final avgRating = farmReviews.isEmpty
            ? 0.0
            : (totalRating / farmReviews.length).toDouble();

        // Find farm's rank and name
        int rank = 0;
        String? farmName = _farmName;
        for (var i = 0; i < rankings.length; i++) {
          if (rankings[i]['farmId'] == _farmOwnerId) {
            rank = i + 1;
            farmName = rankings[i]['farmName'] ?? farmName;
            break;
          }
        }

        setState(() {
          _farmRank = rank;
          _farmName = farmName;
          _averageRating = avgRating;
        });
      }

      setState(() {
        _reviews = reviews;
        _allFarms = rankings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _placeOrder(String farmId, String farmName) async {
    if (_currentUser?.role != 'Vendor') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only vendors can place orders')),
      );
      return;
    }

    try {
      // Show a dialog to get order details
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Place Order'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _productName = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _quantity = int.tryParse(value) ?? 0,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Unit (e.g., kg, pieces)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _unit = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Price per Unit',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _price = double.tryParse(value) ?? 0.0,
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
                if (_productName.isNotEmpty &&
                    _quantity > 0 &&
                    _unit.isNotEmpty &&
                    _price > 0) {
                  Navigator.pop(context, {
                    'productName': _productName,
                    'quantity': _quantity,
                    'unit': _unit,
                    'price': _price,
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all fields correctly')),
                  );
                }
              },
              child: const Text('Place Order'),
            ),
          ],
        ),
      );

      if (result != null) {
        await _orderService.createVendorOrder(
          vendorId: _currentUser!.uid,
          vendorName: _currentUser!.displayName ?? 'Unknown Vendor',
          vendorPhone: _currentUser!.contactNumber ?? '',
          farmId: farmId,
          farmName: farmName,
          productId:
              DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
          productName: result['productName'],
          quantity: result['quantity'],
          unit: result['unit'],
          price: result['price'],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
    }
  }

  List<FarmReview> get _filteredReviews {
    var reviews = _reviews;
    if (_selectedFilter > 0) {
      reviews =
          reviews.where((r) => r.rating.round() == _selectedFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      reviews = reviews
          .where((r) =>
              r.vendorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              r.reviewText.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return reviews;
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

  Widget _buildVendorLeaderboard() {
    if (_allFarms.isEmpty) {
      return const Center(
        child: Text(
          'No farms available in the leaderboard yet.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Farm Leaderboard',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._allFarms.asMap().entries.map((entry) {
          final index = entry.key;
          final farm = entry.value;
          final isTopThree = index < 3;
          final isCurrentUserFarm = farm['farmId'] == _farmOwnerId;

          final rankColor = index == 0
              ? Colors.amber
              : index == 1
                  ? Colors.grey[400]
                  : index == 2
                      ? Colors.brown[300]
                      : Colors.grey;

          return Card(
            elevation: isTopThree || isCurrentUserFarm ? 4 : 1,
            color: isCurrentUserFarm
                ? Colors.blue.withOpacity(0.2)
                : isTopThree
                    ? rankColor?.withOpacity(0.1)
                    : null,
            shape: isCurrentUserFarm
                ? RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.blue, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: rankColor,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    farm['farmName'] ?? 'Farm ${index + 1}',
                    style: TextStyle(
                      fontWeight: isTopThree || isCurrentUserFarm
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (isCurrentUserFarm)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Chip(
                        label: const Text('Your Farm'),
                        backgroundColor: Colors.blue,
                        labelStyle: const TextStyle(color: Colors.white),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  if (isTopThree && !isCurrentUserFarm) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.emoji_events,
                      color: rankColor,
                      size: 20,
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStarRating(farm['averageRating']),
                      const SizedBox(width: 8),
                      Text('(${farm['totalReviews']} reviews)'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.shopping_cart,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${farm['totalOrders'] ?? 0} orders',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${farm['averageRating'].toStringAsFixed(1)} ★',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isTopThree ? rankColor : null,
                        ),
                      ),
                      if (farm['trend'] != null) ...[
                        const SizedBox(height: 4),
                        Icon(
                          farm['trend'] > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: farm['trend'] > 0 ? Colors.green : Colors.red,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      if (farm['farmId'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FarmDetailsScreen(farmOwnerId: farm['farmId']),
                          ),
                        );
                      }
                    },
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildReviewDistribution() {
    // Calculate rating distribution
    final distribution = List.filled(5, 0);
    for (var review in _reviews) {
      distribution[review.rating.floor() - 1]++;
    }
    final maxCount = distribution.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rating Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...List.generate(5, (index) {
              final rating = 5 - index;
              final count = distribution[rating - 1];
              final percentage = _reviews.isEmpty
                  ? 0.0
                  : (count / _reviews.length * 100).roundToDouble();

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Row(
                        children: [
                          Text(
                            '$rating',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxCount == 0 ? 0 : count / maxCount,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.amber.withOpacity(0.7),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '$count (${percentage.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Vendor',
                border: OutlineInputBorder(),
              ),
              value: _selectedVendor.isEmpty ? null : _selectedVendor,
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All Vendors'),
                ),
                ..._reviews.map((review) => review.vendorName).toSet().map(
                      (name) => DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      ),
                    ),
              ],
              onChanged: (value) {
                setState(() => _selectedVendor = value ?? '');
                _loadReviewsAndFarms();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Order ID',
                border: OutlineInputBorder(),
              ),
              value: _selectedOrderId.isEmpty ? null : _selectedOrderId,
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All Orders'),
                ),
                ..._reviews.map((review) => review.orderId).toSet().map(
                      (id) => DropdownMenuItem(
                        value: id,
                        child: Text(id),
                      ),
                    ),
              ],
              onChanged: (value) {
                setState(() => _selectedOrderId = value ?? '');
                _loadReviewsAndFarms();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<double>(
              decoration: const InputDecoration(
                labelText: 'Minimum Rating',
                border: OutlineInputBorder(),
              ),
              value: _minRating,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Any Rating'),
                ),
                ...List.generate(5, (index) => index + 1.0).map(
                  (rating) => DropdownMenuItem(
                    value: rating,
                    child: Text('$rating ★ and above'),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _minRating = value);
                _loadReviewsAndFarms();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAllReviewsDialog() async {
    if (_farmOwnerId == null) return;
    final allReviews = await _reviewService.getFarmReviews(_farmOwnerId!);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('All Reviews for ${_farmName ?? 'Your Farm'}'),
        content: SizedBox(
          width: 600,
          child: allReviews.isEmpty
              ? const Text('No reviews found.')
              : ListView(
                  shrinkWrap: true,
                  children: allReviews
                      .map((review) => ListTile(
                            title: Text(review.vendorName),
                            subtitle: Text(
                                'Order: ${review.orderId}\n\n${review.reviewText}'),
                            trailing: _buildStarRating(review.rating),
                          ))
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Ranking & Reviews'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Always show the leaderboard (all farms)
                  _buildVendorLeaderboard(),
                  const SizedBox(height: 24),
                  // All reviews for this farm owner
                  const Text(
                    'Your Reviews',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...(widget.isVendorView ? _vendorReviews : _reviews)
                      .map((review) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: Text(
                                    (review.vendorName.isNotEmpty
                                            ? review.vendorName[0]
                                            : '?')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        review.vendorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Order ID: ${review.orderId}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStarRating(review.rating),
                              ],
                            ),
                            if (review.reviewText.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(review.reviewText),
                            ],
                            if (review.categoryRatings.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    review.categoryRatings.entries.map((e) {
                                  return Chip(
                                    backgroundColor: Colors.blue[50],
                                    label: Text(
                                      '${e.key}: ${e.value}',
                                      style: TextStyle(color: Colors.blue[900]),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Reviewed on ${review.createdAt.toDate().toString().split(' ')[0]}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
