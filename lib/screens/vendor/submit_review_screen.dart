import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import '../../models/farm_review.dart';
import '../../models/order.dart';
import '../../services/review_service.dart';

class SubmitReviewScreen extends StatefulWidget {
  final Order order;
  final FarmReview? existingReview;

  const SubmitReviewScreen({
    Key? key,
    required this.order,
    this.existingReview,
  }) : super(key: key);

  @override
  _SubmitReviewScreenState createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  final ReviewService _reviewService = ReviewService();
  final _formKey = GlobalKey<FormState>();

  double _rating = 0;
  String _reviewText = '';
  final Map<String, double> _categoryRatings = {
    'Product Quality': 0,
    'Packaging': 0,
    'Delivery': 0,
    'Communication': 0,
  };
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating;
      _reviewText = widget.existingReview!.reviewText;
      _categoryRatings.addAll(widget.existingReview!.categoryRatings);
    }
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final review = FarmReview(
        id: widget.existingReview?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        farmOwnerId: widget.order.sellerId,
        vendorId: widget.order.customerId,
        vendorName: widget.order.customerName,
        vendorPhone: '', // TODO: Add vendor phone to order model
        orderId: widget.order.id,
        rating: _rating,
        reviewText: _reviewText,
        categoryRatings: _categoryRatings,
        createdAt: widget.existingReview?.createdAt ?? cf.Timestamp.now(),
        updatedAt: cf.Timestamp.now(),
        isEdited: widget.existingReview != null,
      );

      if (widget.existingReview != null) {
        await _reviewService.updateReview(review);
      } else {
        await _reviewService.createReview(review);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingReview != null
                ? 'Review updated successfully'
                : 'Review submitted successfully'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.existingReview != null ? 'Update Review' : 'Submit Review'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Rating
              const Text(
                'Overall Rating',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() => _rating = index + 1);
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Category Ratings
              const Text(
                'Category Ratings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._categoryRatings.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < entry.value
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _categoryRatings[entry.key] = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 24),

              // Review Text
              TextFormField(
                initialValue: _reviewText,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Write your review',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your review';
                  }
                  return null;
                },
                onChanged: (value) => _reviewText = value,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : Text(widget.existingReview != null
                          ? 'Update Review'
                          : 'Submit Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
