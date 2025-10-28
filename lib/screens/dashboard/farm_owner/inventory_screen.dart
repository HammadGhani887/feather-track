import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/farm_inventory.dart';
import '../../../models/user_profile.dart';
import '../../../services/inventory_service.dart';
import '../../../services/user_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final InventoryService _inventoryService = InventoryService();
  final UserService _userService = UserService();
  late Future<List<FarmInventory>> _inventoryFuture;
  String? _selectedCategory;
  final List<String> _categories = ['All', 'Bird', 'Egg', 'Feed', 'Other'];
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final userMap = await _userService.getCurrentUserProfile();
      if (userMap != null && userMap['role'] == 'Farm Owner') {
        final userProfile = UserProfile.fromMap(userMap);
        setState(() {
          _currentUser = userProfile;
        });
        _loadInventory();
      } else {
        throw Exception(
            'Unauthorized access: Only farm owners can view this page');
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

  Future<void> _loadInventory() async {
    try {
      if (_currentUser == null) {
        throw Exception('No user found');
      }

      setState(() {
        if (_selectedCategory == null || _selectedCategory == 'All') {
          _inventoryFuture = _inventoryService.getInventory(
            _currentUser!.uid,
            InventoryOwnerType.farmOwner,
          );
        } else {
          _inventoryFuture = _inventoryService.getInventoryByCategory(
            _currentUser!.uid,
            InventoryOwnerType.farmOwner,
            _selectedCategory!,
          );
        }
      });

      // Debug print to check the loaded inventory
      _inventoryFuture.then((inventory) {
        print('Loaded inventory items: ${inventory.length}');
        inventory.forEach((item) {
          print(
              'Item: ${item.itemName}, Category: ${item.category}, Owner: ${item.ownerId}');
        });
      }).catchError((error) {
        print('Error loading inventory: $error');
      });
    } catch (e) {
      print('Error loading inventory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading inventory: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addOrEditInventoryItem(BuildContext context,
      {FarmInventory? existingItem}) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a farm owner')),
      );
      return;
    }

    if (_currentUser!.role != 'Farm Owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only farm owners can manage inventory')),
      );
      return;
    }

    String itemName = existingItem?.itemName ?? '';
    String category = existingItem?.category ?? 'Egg';
    int quantity = existingItem?.quantity ?? 0;
    String unit = existingItem?.unit ?? 'dozens';
    double price = existingItem?.price ?? 0.0;
    String description = existingItem?.description ?? '';
    bool isAvailable = existingItem?.isAvailable ?? true;

    final nameController = TextEditingController(text: itemName);
    final quantityController = TextEditingController(text: quantity.toString());
    final priceController = TextEditingController(text: price.toString());
    final descriptionController = TextEditingController(text: description);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F38),
          title: Text(
            existingItem == null ? 'Add Inventory Item' : 'Edit Inventory Item',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, 'Item Name'),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Category',
                  category,
                  ['Bird', 'Egg', 'Feed', 'Other'],
                  (value) => setState(() => category = value!),
                ),
                const SizedBox(height: 16),
                _buildTextField(quantityController, 'Quantity'),
                const SizedBox(height: 16),
                _buildDropdown(
                  'Unit',
                  unit,
                  ['birds', 'dozens', 'kg', 'items'],
                  (value) => setState(() => unit = value!),
                ),
                const SizedBox(height: 16),
                _buildTextField(priceController, 'Price'),
                const SizedBox(height: 16),
                _buildTextField(descriptionController, 'Description'),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text(
                    'Available',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: isAvailable,
                  onChanged: (value) => setState(() => isAvailable = value),
                  activeColor: Colors.blue,
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
                try {
                  if (nameController.text.isEmpty) {
                    throw Exception('Item name is required');
                  }

                  if (int.tryParse(quantityController.text) == null) {
                    throw Exception('Invalid quantity');
                  }

                  if (double.tryParse(priceController.text) == null) {
                    throw Exception('Invalid price');
                  }

                  final item = existingItem != null
                      ? existingItem.copyWith(
                          itemName: nameController.text,
                          category: category,
                          quantity: int.tryParse(quantityController.text) ?? 0,
                          unit: unit,
                          price: double.tryParse(priceController.text) ?? 0.0,
                          description: descriptionController.text,
                          isAvailable: isAvailable,
                        )
                      : FarmInventory(
                          id: '',
                          ownerId: _currentUser!.uid,
                          ownerType: InventoryOwnerType.farmOwner,
                          itemName: nameController.text,
                          category: category,
                          quantity: int.tryParse(quantityController.text) ?? 0,
                          unit: unit,
                          price: double.tryParse(priceController.text) ?? 0.0,
                          description: descriptionController.text,
                          imageUrl: null,
                          createdAt: Timestamp.now(),
                          updatedAt: Timestamp.now(),
                          isAvailable: isAvailable,
                        );

                  if (existingItem != null) {
                    final success = await _inventoryService.updateInventoryItem(
                        item, _currentUser!);
                    if (!success) throw Exception('Failed to update item');
                  } else {
                    final newItem = await _inventoryService.addInventoryItem(
                        item, _currentUser!);
                    if (newItem == null) throw Exception('Failed to add item');
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    _loadInventory(); // Reload the inventory after adding/updating
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          existingItem == null
                              ? 'Item added successfully'
                              : 'Item updated successfully',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: Text(
                existingItem == null ? 'Add' : 'Update',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteInventoryItem(String itemId) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as a farm owner')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F38),
        title: const Text(
          'Delete Item',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this item?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success =
            await _inventoryService.deleteInventoryItem(itemId, _currentUser!);
        if (success && mounted) {
          _loadInventory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete item')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      style: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF1A1F38),
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Inventory Management'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Inventory Management',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadInventory,
          ),
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
                            setState(() {
                              _selectedCategory = _categories[index] == 'All'
                                  ? null
                                  : _categories[index];
                            });
                            Navigator.pop(context);
                            _loadInventory();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0E21),
              const Color(0xFF0A0E21).withOpacity(0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category: ${_selectedCategory ?? 'All'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<FarmInventory>>(
                  future: _inventoryFuture,
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadInventory,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final inventory = snapshot.data ?? [];

                    if (inventory.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'No inventory items found',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _addOrEditInventoryItem(context),
                              child: const Text('Add New Item'),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadInventory,
                      child: ListView.builder(
                        itemCount: inventory.length,
                        itemBuilder: (context, index) {
                          final item = inventory[index];
                          return Card(
                            color: Colors.white.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                item.itemName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Category: ${item.category}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    'Quantity: ${item.quantity} ${item.unit}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    'Price: \$${item.price.toStringAsFixed(2)}',
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  Row(
                                    children: [
                                      const Text(
                                        'Available: ',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      Icon(
                                        item.isAvailable
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: item.isAvailable
                                            ? Colors.green
                                            : Colors.red,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _addOrEditInventoryItem(
                                      context,
                                      existingItem: item,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _deleteInventoryItem(item.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
        onPressed: () => _addOrEditInventoryItem(context),
      ),
    );
  }
}
