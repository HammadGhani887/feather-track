import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/review_service.dart';

class ReviewDialog extends StatefulWidget {
  final String orderId;
  final String farmOwnerId;
  final String vendorId;
  final String farmName;
  final String vendorName;
  final String? vendorPhone;

  const ReviewDialog({
    Key? key,
    required this.orderId,
    required this.farmOwnerId,
    required this.vendorId,
    required this.farmName,
    required this.vendorName,
    this.vendorPhone,
  }) : super(key: key);

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final ReviewService _reviewService = ReviewService();
  final _reviewController = TextEditingController();
  double _rating = 0;
  final Map<String, double> _categoryRatings = {
    'quality': 0,
    'packaging': 0,
    'communication': 0,
    'delivery': 0,
  };

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    try {
      await _reviewService.submitReview(
        orderId: widget.orderId,
        farmOwnerId: widget.farmOwnerId,
        vendorId: widget.vendorId,
        rating: _rating,
        reviewText: _reviewController.text.trim(),
        categoryRatings: _categoryRatings,
        vendorPhone: widget.vendorPhone,
        farmName: widget.farmName,
        vendorName: widget.vendorName,
      );

      // Update order to mark as reviewed
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'isReviewed': true});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStarRating(
      String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < value ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 32,
              ),
              onPressed: () => onChanged(index + 1.0),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1F38),
      title: const Text(
        'Submit Review',
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farm: ${widget.farmName}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'Vendor: ${widget.vendorName}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _buildStarRating('Overall Rating', _rating, (value) {
              setState(() => _rating = value);
            }),
            const SizedBox(height: 16),
            ..._categoryRatings.entries.map((entry) {
              return Column(
                children: [
                  _buildStarRating(
                    '${entry.key[0].toUpperCase()}${entry.key.substring(1)}',
                    entry.value,
                    (value) {
                      setState(() => _categoryRatings[entry.key] = value);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Your Review',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: _submitReview,
          child: const Text('Submit Review'),
        ),
      ],
    );
  }
}
