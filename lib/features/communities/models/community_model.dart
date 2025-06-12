import 'package:cloud_firestore/cloud_firestore.dart';

class Community {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String ownerId; // Mantener por compatibilidad - será el primer propietario
  final String createdByName;
  final DateTime? createdAt;
  final List<String> members;
  final List<String> admins; // Lista de IDs de usuarios admin
  final List<String> owners; // Lista de IDs de propietarios (múltiples)
  final int memberCount;
  final String? joinCode;
  final String privacy;

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.ownerId,
    required this.createdByName,
    this.createdAt,
    required this.members,
    required this.admins,
    required this.owners,
    required this.memberCount,
    this.joinCode,
    this.privacy = 'public',
  });

  factory Community.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String ownerId = data['ownerId'] ?? '';
    
    // Migrar del sistema antiguo al nuevo: si no hay lista de owners, usar ownerId
    List<String> owners = List<String>.from(data['owners'] ?? []);
    if (owners.isEmpty && ownerId.isNotEmpty) {
      owners = [ownerId];
    }
    
    return Community(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      ownerId: ownerId, // Mantener por compatibilidad
      createdByName: data['createdByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      members: List<String>.from(data['members'] ?? []),
      admins: List<String>.from(data['admins'] ?? []),
      owners: owners,
      memberCount: (data['members'] as List<dynamic>?)?.length ?? 0,
      joinCode: data['joinCode'],
      privacy: data['privacy'] ?? 'public',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'ownerId': ownerId, // Mantener por compatibilidad
      'createdByName': createdByName,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'members': members,
      'admins': admins,
      'owners': owners, // Nueva lista de propietarios
      'memberCount': memberCount,
      'joinCode': joinCode,
      'privacy': privacy,
    };
  }

  Community copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? ownerId,
    String? createdByName,
    DateTime? createdAt,
    List<String>? members,
    List<String>? admins,
    List<String>? owners,
    int? memberCount,
    String? joinCode,
    String? privacy,
  }) {
    return Community(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      owners: owners ?? this.owners,
      memberCount: memberCount ?? this.memberCount,
      joinCode: joinCode ?? this.joinCode,
      privacy: privacy ?? this.privacy,
    );
  }
  
  // Métodos de utilidad para verificar roles
  bool isOwner(String userId) => owners.contains(userId);
  
  bool isAdmin(String userId) => admins.contains(userId) || isOwner(userId);
  
  bool isMember(String userId) => members.contains(userId);
  
  // Obtener todos los IDs de administradores (incluyendo owners)
  List<String> getAllAdminIds() {
    Set<String> allAdmins = {...admins, ...owners};
    return allAdmins.toList();
  }
  
  // Métodos específicos para múltiples propietarios
  bool hasMultipleOwners() => owners.length > 1;
  
  bool canPromoteToOwner(String userId) => !isOwner(userId) && isMember(userId);
  
  bool canDemoteFromOwner(String userId) => isOwner(userId) && owners.length > 1;
}

class CommunityMember {
  final String userId;
  final String name;
  final String email;
  final String role; // 'owner', 'admin', 'member'
  final DateTime? joinedAt;
  final String? profileImageUrl;
  
  // Métodos de utilidad para roles
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin' || isOwner;
  bool get isMember => role == 'member';

  CommunityMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.joinedAt,
    this.profileImageUrl,
  });

  factory CommunityMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CommunityMember(
      userId: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'member',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
      profileImageUrl: data['profileImageUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'role': role,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
      'profileImageUrl': profileImageUrl,
    };
  }

  CommunityMember copyWith({
    String? userId,
    String? name,
    String? email,
    String? role,
    DateTime? joinedAt,
    String? profileImageUrl,
  }) {
    return CommunityMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}

class CommunityStats {
  final int totalMembers;
  final int totalTasks;
  final int completedTasks;
  final int activeTasks;
  final int messagesCount;
  final Map<String, int> tasksByStatus;

  CommunityStats({
    required this.totalMembers,
    required this.totalTasks,
    required this.completedTasks,
    required this.activeTasks,
    required this.messagesCount,
    required this.tasksByStatus,
  });

  factory CommunityStats.empty() {
    return CommunityStats(
      totalMembers: 0,
      totalTasks: 0,
      completedTasks: 0,
      activeTasks: 0,
      messagesCount: 0,
      tasksByStatus: {},
    );
  }

  double get completionPercentage {
    if (totalTasks == 0) return 0.0;
    return (completedTasks / totalTasks) * 100;
  }
}