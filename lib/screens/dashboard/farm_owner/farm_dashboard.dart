import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../screens/auth/login_screen.dart';
import 'real_time_monitoring_screen.dart';
import 'farm_order_management_screen.dart';
import 'inventory_screen.dart';
import '../../../services/review_service.dart';
import 'farm_ranking_screen.dart';
import 'ai_predictions_screen.dart';
import '../../../services/user_service.dart';

class FarmDashboard extends StatefulWidget {
  const FarmDashboard({super.key});

  @override
  State<FarmDashboard> createState() => _FarmDashboardState();
}

class _FarmDashboardState extends State<FarmDashboard> {
  final ReviewService _reviewService = ReviewService();
  final UserService _userService = UserService();
  String? _farmOwnerId;
  String? _farmName;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  dynamic _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final user = await _userService.getCurrentUserProfile();
      if (mounted) {
        if (user != null && user['role'] == 'Farm Owner') {
          setState(() {
            _currentUser = user;
            _farmOwnerId = user['id'];
            _farmName = user['farmName'] ?? 'Your Farm';
          });
          _loadFarmData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unauthorized access or user not found.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('Error initializing user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadFarmData() async {
    if (!mounted || _farmOwnerId == null) return;

    try {
      final reviews = await _reviewService.getFarmReviews(_farmOwnerId!);
      if (mounted) {
        double total = 0;
        for (var review in reviews) {
          total += review.rating;
        }
        setState(() {
          _totalReviews = reviews.length;
          _averageRating = reviews.isEmpty ? 0 : total / reviews.length;
        });
      }
    } catch (e) {
      print('Error loading farm data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading farm data: ${e.toString()}')),
        );
      }
    }
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF0A0E21), // Same dark background as vendor
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Farm Owner Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${_farmName ?? 'Farm Owner'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    'Manage Inventory',
                    'View',
                    Icons.inventory_2,
                    Colors.green,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InventoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    'Real Time Monitoring',
                    '',
                    Icons.monitor_heart,
                    Colors.teal,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const RealTimeMonitoringScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    'Farm Ranking & Reviews',
                    '',
                    Icons.star,
                    Colors.amber,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FarmRankingScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    'Manage Orders',
                    'View',
                    Icons.shopping_cart,
                    Colors.blue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const FarmOrderManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    'AI Predictions',
                    '',
                    Icons.auto_graph,
                    Colors.deepPurple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AiPredictionsScreen(),
                        ),
                      );
                    },
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Farm Owner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            _buildDrawerItem(
              context,
              icon: Icons.logout,
              title: 'Sign Out',
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
      hoverColor: const Color(0xFF5C8D89).withOpacity(0.1),
    );
  }

  Widget _buildDashboardCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (value.isNotEmpty)
              Text(
                value,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}
