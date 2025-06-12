import 'package:flutter/foundation.dart';
import 'package:classroom_mejorado/features/communities/models/community_model.dart';
import 'package:classroom_mejorado/features/communities/services/community_service.dart';

class CommunityProvider extends ChangeNotifier {
  final CommunityService _communityService = CommunityService();

  List<Community> _communities = [];
  Community? _selectedCommunity;
  List<CommunityMember> _members = [];
  CommunityStats _stats = CommunityStats.empty();
  bool _isLoading = false;
  bool _isLoadingStats = false;
  String? _error;

  // Getters
  List<Community> get communities => _communities;
  Community? get selectedCommunity => _selectedCommunity;
  List<CommunityMember> get members => _members;
  CommunityStats get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isLoadingStats => _isLoadingStats;
  String? get error => _error;

  // Cargar comunidades del usuario
  void loadUserCommunities() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _communityService.getUserCommunities().listen(
      (communities) {
        _communities = communities;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // Seleccionar una comunidad
  void selectCommunity(Community community) {
    _selectedCommunity = community;
    notifyListeners();
    loadCommunityMembers(community.id);
    loadCommunityStats(community.id);
  }

  // Cargar miembros de la comunidad seleccionada
  void loadCommunityMembers(String communityId) {
    _communityService.getCommunityMembers(communityId).listen(
      (members) {
        _members = members;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  // Cargar estadísticas de la comunidad
  Future<void> loadCommunityStats(String communityId) async {
    try {
      _isLoadingStats = true;
      notifyListeners();

      _stats = await _communityService.getCommunityStats(communityId);
      _isLoadingStats = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  // Crear nueva comunidad
  Future<String?> createCommunity(Community community) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final communityId = await _communityService.createCommunity(community);
      
      // Recargar comunidades
      loadUserCommunities();
      
      return communityId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Actualizar comunidad
  Future<bool> updateCommunity(String communityId, Map<String, dynamic> updates) async {
    try {
      _error = null;
      await _communityService.updateCommunity(communityId, updates);
      
      // Actualizar la comunidad seleccionada si es la misma
      if (_selectedCommunity?.id == communityId) {
        final updatedCommunity = await _communityService.getCommunity(communityId);
        if (updatedCommunity != null) {
          _selectedCommunity = updatedCommunity;
          notifyListeners();
        }
      }
      
      // Recargar comunidades
      loadUserCommunities();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Eliminar comunidad
  Future<bool> deleteCommunity(String communityId) async {
    try {
      _error = null;
      await _communityService.deleteCommunity(communityId);
      
      // Si era la comunidad seleccionada, limpiar selección
      if (_selectedCommunity?.id == communityId) {
        _selectedCommunity = null;
        _members.clear();
        _stats = CommunityStats.empty();
      }
      
      // Recargar comunidades
      loadUserCommunities();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Unirse a comunidad por código
  Future<bool> joinCommunityByCode(String joinCode) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _communityService.joinCommunityByCode(joinCode);
      
      // Recargar comunidades
      loadUserCommunities();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Salir de comunidad
  Future<bool> leaveCommunity(String communityId) async {
    try {
      _error = null;
      await _communityService.leaveCommunity(communityId);
      
      // Si era la comunidad seleccionada, limpiar selección
      if (_selectedCommunity?.id == communityId) {
        _selectedCommunity = null;
        _members.clear();
        _stats = CommunityStats.empty();
      }
      
      // Recargar comunidades
      loadUserCommunities();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Actualizar rol de miembro
  Future<bool> updateMemberRole(String communityId, String userId, String newRole) async {
    try {
      _error = null;
      await _communityService.updateMemberRole(communityId, userId, newRole);
      
      // Recargar miembros
      if (_selectedCommunity?.id == communityId) {
        loadCommunityMembers(communityId);
      }
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Remover miembro
  Future<bool> removeMember(String communityId, String userId) async {
    try {
      _error = null;
      await _communityService.removeMember(communityId, userId);
      
      // Recargar miembros y estadísticas
      if (_selectedCommunity?.id == communityId) {
        loadCommunityMembers(communityId);
        loadCommunityStats(communityId);
      }
      
      // Recargar comunidades (para actualizar el contador de miembros)
      loadUserCommunities();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Actualizar última visita
  Future<void> updateLastVisit(String communityId) async {
    await _communityService.updateLastVisit(communityId);
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Limpiar selección
  void clearSelection() {
    _selectedCommunity = null;
    _members.clear();
    _stats = CommunityStats.empty();
    notifyListeners();
  }

  // Refrescar datos
  void refresh() {
    loadUserCommunities();
    if (_selectedCommunity != null) {
      loadCommunityMembers(_selectedCommunity!.id);
      loadCommunityStats(_selectedCommunity!.id);
    }
  }
}