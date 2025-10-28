import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final String role;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  // Optional fields - role-specific
  final String? farmName;
  final String? businessName;
  final String? location;
  final String? cnic;
  final String? contactNumber;
  final String? address;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.farmName,
    this.businessName,
    this.location,
    this.cnic,
    this.contactNumber,
    this.address,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'],
      role: data['role'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      farmName: data['farmName'],
      businessName: data['businessName'],
      location: data['location'],
      cnic: data['cnic'],
      contactNumber: data['contactNumber'],
      address: data['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (farmName != null) 'farmName': farmName,
      if (businessName != null) 'businessName': businessName,
      if (location != null) 'location': location,
      if (cnic != null) 'cnic': cnic,
      if (contactNumber != null) 'contactNumber': contactNumber,
      if (address != null) 'address': address,
    };
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? farmName,
    String? businessName,
    String? location,
    String? cnic,
    String? contactNumber,
    String? address,
  }) {
    return UserProfile(
      uid: this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: this.role,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
      farmName: farmName ?? this.farmName,
      businessName: businessName ?? this.businessName,
      location: location ?? this.location,
      cnic: cnic ?? this.cnic,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['id'] ?? map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      phoneNumber: map['phoneNumber'],
      role: map['role'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      farmName: map['farmName'],
      businessName: map['businessName'],
      location: map['location'],
      cnic: map['cnic'],
      contactNumber: map['contactNumber'],
      address: map['address'],
    );
  }
}

Future<void> createMissingFarmDocsForReviewedFarms() async {
  final firestore = FirebaseFirestore.instance;

  // 1. Get all unique farmOwnerIds from reviews
  final reviewsSnapshot = await firestore.collection('reviews').get();
  final Set<String> farmOwnerIds = {};
  for (var doc in reviewsSnapshot.docs) {
    final data = doc.data();
    if (data['farmOwnerId'] != null &&
        data['farmOwnerId'].toString().isNotEmpty) {
      farmOwnerIds.add(data['farmOwnerId']);
    }
  }

  // 2. Get all existing farm doc IDs
  final farmsSnapshot = await firestore.collection('farms').get();
  final Set<String> existingFarmIds =
      farmsSnapshot.docs.map((doc) => doc.id).toSet();

  // 3. For each farmOwnerId not in farms, create a doc with a placeholder name
  for (final farmId in farmOwnerIds) {
    if (!existingFarmIds.contains(farmId)) {
      await firestore.collection('farms').doc(farmId).set({
        'name': 'Farm $farmId', // Placeholder, you can update later
        'location': '',
        'contactNumber': '',
      });
      print('Created farm doc for $farmId');
    }
  }

  print('Done! All missing farm docs created.');
}
