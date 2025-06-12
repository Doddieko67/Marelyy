import 'package:firebase_auth/firebase_auth.dart';

class PermissionChecker {
  /// Verifica si un usuario es propietario de la comunidad
  static bool isOwner(String userId, Map<String, dynamic> communityData) {
    final List<String> ownerIds = List<String>.from(
      communityData['owners'] ?? [communityData['ownerId']]
    );
    return ownerIds.contains(userId);
  }
  
  /// Verifica si un usuario es administrador de la comunidad (incluye propietarios)
  static bool isAdmin(String userId, Map<String, dynamic> communityData) {
    if (isOwner(userId, communityData)) return true;
    
    final List<String> adminIds = List<String>.from(
      communityData['admins'] ?? []
    );
    return adminIds.contains(userId);
  }
  
  /// Verifica si el usuario actual es propietario
  static bool isCurrentUserOwner(Map<String, dynamic> communityData) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return isOwner(user.uid, communityData);
  }
  
  /// Verifica si el usuario actual es administrador (incluye propietarios)
  static bool isCurrentUserAdmin(Map<String, dynamic> communityData) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return isAdmin(user.uid, communityData);
  }
  
  /// Obtiene el rol de un usuario específico
  static String getUserRole(String userId, Map<String, dynamic> communityData) {
    if (isOwner(userId, communityData)) return 'owner';
    
    final List<String> adminIds = List<String>.from(
      communityData['admins'] ?? []
    );
    if (adminIds.contains(userId)) return 'admin';
    
    return 'member';
  }
  
  /// Obtiene el rol del usuario actual
  static String getCurrentUserRole(Map<String, dynamic> communityData) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'member';
    return getUserRole(user.uid, communityData);
  }
  
  /// Obtiene las listas de IDs por rol
  static Map<String, List<String>> getRoleLists(Map<String, dynamic> communityData) {
    return {
      'owners': List<String>.from(
        communityData['owners'] ?? [communityData['ownerId']]
      ),
      'admins': List<String>.from(communityData['admins'] ?? []),
      'members': List<String>.from(communityData['members'] ?? []),
    };
  }
}