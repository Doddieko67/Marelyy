import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? displayName;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final List<String> communities;
  final Map<String, dynamic> preferences;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.displayName,
    this.profileImageUrl,
    this.createdAt,
    this.lastLoginAt,
    this.communities = const [],
    this.preferences = const {},
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      name: data['name'] ?? data['displayName'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'],
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      communities: List<String>.from(data['communities'] ?? []),
      preferences: Map<String, dynamic>.from(data['preferences'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'displayName': displayName,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : FieldValue.serverTimestamp(),
      'communities': communities,
      'preferences': preferences,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? displayName,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? communities,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      communities: communities ?? this.communities,
      preferences: preferences ?? this.preferences,
    );
  }
}

class AdminStats {
  final int totalCommunities;
  final int totalUsers;
  final int totalTasks;
  final int activeTasks;
  final int completedTasks;
  final Map<String, int> communitiesGrowth;
  final Map<String, int> tasksByStatus;

  AdminStats({
    required this.totalCommunities,
    required this.totalUsers,
    required this.totalTasks,
    required this.activeTasks,
    required this.completedTasks,
    this.communitiesGrowth = const {},
    this.tasksByStatus = const {},
  });

  factory AdminStats.empty() {
    return AdminStats(
      totalCommunities: 0,
      totalUsers: 0,
      totalTasks: 0,
      activeTasks: 0,
      completedTasks: 0,
    );
  }

  double get completionRate {
    if (totalTasks == 0) return 0.0;
    return (completedTasks / totalTasks) * 100;
  }

  double get activeRate {
    if (totalTasks == 0) return 0.0;
    return (activeTasks / totalTasks) * 100;
  }
}